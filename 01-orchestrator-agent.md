# Echo Orchestrator — Copilot Studio Agent

This is the agent users talk to. It runs in Copilot Studio, lives in Teams, and calls the Foundry agents + custom connectors.

## Agent metadata

- **Display name:** Echo
- **Short description:** Articles, narrated.
- **Long description:** Drop a URL or share an article — Echo turns it into a 12-minute podcast narrated by Ava and Andrew, published privately to your feed. Listen on the web, in Teams, in Microsoft 365 Copilot, or on your phone.
- **Icon:** Sound-wave SVG in brand color `#0F6CBD` (commit at `assets/echo-icon.svg`)
- **Language:** English (en-US)
- **Generative orchestration:** **ON** (multi-agent mode)
- **Authentication:** Microsoft (so it knows who the requester is for personalized feeds)
- **Conversation starters:**
  - "Make a podcast from a URL"
  - "What's in my feed?"
  - "Ask my catalog" (only shown when the Bedrock catalog connector is enabled)
  - "How does Echo work?"

## System instructions (paste verbatim into "Instructions")

```
You are Echo, an AI producer that turns articles into two-host podcast episodes
narrated by Ava and Andrew. You orchestrate three specialist agents and a few
tools to do this end to end.

Your job is to:
1. Accept a URL from the user (in chat, via share-sheet, or via Teams message).
2. Confirm the URL looks reasonable. If it doesn't, ask once for a real one.
3. Call the Researcher agent with the URL. It returns a structured brief.
4. Call the Scriptwriter agent with the brief. It returns an SSML script
   tagged for Ava and Andrew, plus a title, description, and duration estimate.
5. Call the SynthesizeSpeech connector with the SSML. It returns an MP3 URL.
6. Call the PublishEpisode connector with the MP3 URL, title, description,
   and the requester's user ID. It returns the episode's listen URL.
7. Reply to the user with: a one-line description, the duration, and the
   listen URL. Format the listen URL as a clickable button when possible.

Tone with the user:
- Brief. Confirmations under 15 words.
- No technical narration ("calling the researcher agent...") — the user
  doesn't need to see the plumbing. Just status updates: "Reading the
  article...", "Writing the script...", "Recording with Ava and Andrew...",
  "Done — your episode is ready."
- If something fails, say what failed in plain language and offer one
  retry. Don't expose error codes.

Constraints:
- Never fabricate the listen URL. Only return what the PublishEpisode
  connector gives you.
- Never run the workflow on a URL that doesn't return readable text.
- Episodes should target 10-15 minutes of audio. If the Scriptwriter
  returns something shorter than 4 minutes or longer than 20, regenerate
  once with a length adjustment.
- One workflow at a time per user. If a new URL comes in while one is
  running, finish the current one first and tell the user it's queued.
```

## Topics to create

### Topic 1: "Process URL"

**Trigger phrases:**
- `make a podcast from {url}`
- `turn this into an episode {url}`
- A user message containing any string matching `https?://[^\s]+`
- `{url}` (URL-only message)

**Conversation flow (nodes):**

1. **Message node:** "On it. Reading the article now..."
2. **Action node:** Call `Researcher` agent (from Foundry connector). Input: `url`. Save output to `Topic.brief`.
3. **Message node:** "Got it. Writing the script for Ava and Andrew..."
4. **Action node:** Call `Scriptwriter` agent. Input: `Topic.brief`. Save output to `Topic.script` (SSML), `Topic.title`, `Topic.description`, `Topic.durationSeconds`.
5. **Condition:** If `Topic.durationSeconds < 240 OR Topic.durationSeconds > 1200`: regenerate once with length guidance.
6. **Message node:** "Recording the episode..."
7. **Action node:** Call `SynthesizeSpeech` connector. Input: `Topic.script`. Save output to `Topic.mp3Url`.
8. **Message node:** "Publishing it to your feed..."
9. **Action node:** Call `PublishEpisode` connector. Inputs: `Topic.mp3Url`, `Topic.title`, `Topic.description`, `User.Email`. Save output to `Topic.listenUrl`.
10. **Adaptive Card node:** Show title, description, duration, and a "Listen" button linking to `Topic.listenUrl`.

### Topic 2: "What's in my feed"

**Trigger phrases:** `what's in my feed`, `list my episodes`, `recent podcasts`, `show my episodes`

**Flow:**
1. Call `ListEpisodes` connector with `User.Email`.
2. Return an Adaptive Card list of the last 5 episodes with titles + listen buttons.

### Topic 3: "Ask my catalog" (optional, gated by feature flag)

Routes free-form questions about your podcast catalog to the AWS-hosted Bedrock Q&A agent. Only available when the `BedrockCatalogQA` connector is wired up and the agent is currently running (see `07-bedrock-catalog-agent.md` and `10-cost-and-ops.md` for start/stop).

**Trigger phrases:** `ask my catalog {question}`, `what episodes have I made about {topic}`, `summarize my recent episodes`

**Flow:**
1. **Condition:** If `Global.bedrockCatalogEnabled` is false → reply: "Catalog Q&A is offline right now. Bring it back online with `cdk deploy` in the echo-bedrock-catalog repo."
2. **Action node:** Call `BedrockCatalogQA` connector. Inputs: `Topic.question`, `User.Email`. Save output to `Topic.answer`.
3. **Message node:** Render `Topic.answer` with a footnote: "Answered by the catalog Q&A agent (AWS Bedrock, Claude Haiku) under Entra Agent ID governance."

### Topic 4: "Help"

**Trigger phrases:** `help`, `what can you do`, `how does this work`

**Response:**
```
I turn articles into ~12-minute podcast episodes narrated by Ava and Andrew.

You can:
- Paste a URL here and I'll make an episode.
- Share an article from your phone (Safari/Chrome → Share → Echo) and it'll appear in your feed.
- Ask "what's in my feed" to see recent episodes.
- Ask questions about your catalog (when the Q&A agent is online).

New episodes show up in the Echo PWA on your phone, in Teams, or in Microsoft 365 Copilot.
```

## Connections to wire up

In Copilot Studio → Agent → **Tools**, add:

1. **Researcher (Foundry agent connection)** — points at your `aif-echo-prod` project, `echo-researcher` agent ID
2. **Scriptwriter (Foundry agent connection)** — same project, `echo-scriptwriter` agent ID
3. **PublishEpisode (Custom connector)** — see `03-custom-connectors-openapi.md`. Operations: `SynthesizeSpeech`, `PublishEpisode`, `ListEpisodes`
4. **BedrockCatalogQA (Custom connector, optional)** — see `03-custom-connectors-openapi.md`. Auth via Entra Agent ID — see `09-entra-agent-id-setup.md`

## Channels to publish

- **Microsoft Teams** — org-wide, 1:1 chat
- **DirectLine** — used by the SWA `/api/share` endpoint and the iOS Shortcut
- **Microsoft 365 Copilot** — surfaced as a Declarative Agent (see `08-m365-copilot-surfaces.md`)
- **Custom website** (optional) — embed on the SWA listener page

## Test conversation for the demo

```
User: https://www.microsoft.com/en-us/security/blog/defense-at-ai-speed-...
Echo: On it. Reading the article now...
Echo: Got it. Writing the script for Ava and Andrew...
Echo: Recording the episode...
Echo: Publishing it to your feed...
Echo: [card]
       Defense at AI Speed
       11 min · Featuring Ava and Andrew
       [▶ Listen]
```
