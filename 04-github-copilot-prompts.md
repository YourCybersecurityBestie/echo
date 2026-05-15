# Echo — GitHub Copilot Vibe-Code Prompts

Paste each prompt into GitHub Copilot Chat (in VS Code) for the corresponding component. Each prompt includes the full context Copilot needs to scaffold the code in one shot. After Copilot generates, iterate with smaller follow-ups.

---

## Prompt 1: Publisher Azure Function (Node.js + TypeScript)

Drop this in a new VS Code workspace called `echo-publisher`.

````
I'm building "Echo" — an AI agent system that turns articles into two-host
podcasts on the Microsoft stack. This component is the Publisher: an Azure
Functions app (Node.js + TypeScript, v4 programming model) that:

1. Synthesizes SSML to MP3 using Azure AI Speech REST API
2. Stores the MP3 in Azure Blob Storage with a per-user container
3. Maintains a per-user RSS feed XML file in the same Blob container
4. Exposes three HTTP endpoints behind function keys

Endpoints I need:

POST /api/synthesize
  Body: { ssml: string, userId: string }
  Behavior:
    - Validate input with zod (ssml ≤ 100KB, userId looks like an email)
    - Strip userId to a safe slug (sha256, first 16 chars)
    - POST the SSML to https://{SPEECH_REGION}.tts.speech.microsoft.com/cognitiveservices/v1
      with Ocp-Apim-Subscription-Key, Content-Type: application/ssml+xml,
      X-Microsoft-OutputFormat: audio-48khz-192kbitrate-mono-mp3
    - Receive MP3 bytes, upload to blob container "echo-audio-{userSlug}"
      with blob name "{uuid}.mp3"
    - Parse MP3 to get durationSeconds using @ffprobe-installer/ffprobe
      (NOT music-metadata — it returns 0 for some HD voice outputs)
    - Return { mp3Url, durationSeconds }

POST /api/episodes
  Body: { mp3Url, title, description, userId, durationSeconds }
  Behavior:
    - Append a new <item> to the user's RSS feed XML in blob "feed.xml"
      of container "echo-audio-{userSlug}". Create the feed if it doesn't exist.
    - Feed should be a valid podcast RSS 2.0 with iTunes namespace.
    - Cover image: pull from blob "cover.jpg" in same container, or use a
      default URL from app setting DEFAULT_COVER_URL.
    - Also append a brief JSON record to blob "catalog.json" in the same
      container (used by the Bedrock catalog Q&A agent and /api/catalog).
      Schema: { episodeId, title, description, publishedAt, durationSeconds,
      sourceUrl, topic, takeaway }
    - Return { episodeId, listenUrl, rssFeedUrl }
    - listenUrl format: https://{STATIC_WEB_APP_URL}/listen/{userSlug}/{episodeId}
    - rssFeedUrl: SAS-tokened blob URL valid for 1 year

GET /api/episodes?userId=...&limit=5
  Behavior:
    - Read user's feed.xml, parse with fast-xml-parser
    - Return last N items as JSON

GET /api/catalog?userId=...&limit=200
  Behavior:
    - Read user's catalog.json, return the most recent N records as JSON
    - This is the endpoint the AWS Bedrock catalog Q&A Lambda calls daily
    - No PII other than the userId hash; safe to expose with function key

GET /api/openapi.json
  Behavior:
    - Return the auto-emitted OpenAPI 3.0 spec for this Function App
    - Used by the M365 Copilot API Plugin manifest
    - Use a small wrapper around zod-to-openapi or hand-author it

GET /api/docs
  Behavior:
    - Render Swagger UI against /api/openapi.json (use the swagger-ui-dist CDN)

Configuration via app settings (all Key Vault references where possible):
  SPEECH_REGION
  SPEECH_KEY (kvref)
  STORAGE_CONNECTION_STRING (kvref) — prefer managed identity instead
  STATIC_WEB_APP_URL
  DEFAULT_COVER_URL

Requirements:
- Use @azure/storage-blob with DefaultAzureCredential (managed identity), NOT
  the connection string, in production
- @azure/functions v4, TypeScript strict mode
- Each endpoint in its own file under src/functions/
- Shared utilities in src/lib/
- Include a local.settings.json template
- App Insights instrumentation: log episodeId, userSlug, durationMs as custom
  dimensions on every successful publish
- Hosting plan: **Flex Consumption** (Linux, Node 20). Bicep file lives under
  infra/ in the parent repo — don't duplicate it here.
- Include README with deploy command

Generate the full project structure now. Use latest stable package versions.
Don't add tests in this first pass — I'll add them after.
````

---

## Prompt 2: PWA Listener (Vite + React + TypeScript)

New workspace `echo-listener`.

````
I'm building the listening interface for "Echo" — an AI-generated personal
podcast service. This is a Progressive Web App (PWA) deployed to Azure
Static Web Apps. Users will add it to their phone home screen and use it
to play episodes from their private feed.

Stack:
- Vite + React + TypeScript
- Tailwind CSS for styling
- vite-plugin-pwa for PWA manifest and service worker
- Plyr or Vidstack as the audio player UI (pick whichever has better
  mobile Safari support)
- No backend — fetches the user's RSS feed directly from Blob Storage

Routes:
  /                — Login screen (email-based identification, no password
                     for v1; store userSlug in localStorage)
  /feed             — List of episodes from the user's RSS feed
  /listen/:userSlug/:episodeId  — Player view for a specific episode
                     (deep-linkable from the share button)

Design goals:
- Mobile-first. Single column. Big tap targets.
- Dark theme by default. Brand color is a deep teal-blue (#0F6CBD).
- The episode list should feel like a podcast app — large title, source,
  duration, a play button on each row, a swipe-to-archive gesture (optional).
- The player view should have: cover art (square, centered), title,
  source, full transport controls (play/pause, 15s skip back, 30s
  skip forward, scrubber), playback speed (0.8x, 1x, 1.2x, 1.5x),
  download for offline, share button (Web Share API).
- Service worker caches recent episodes for offline playback.
- Installable as a PWA: manifest.json with the right icons, theme_color,
  display: "standalone".

Feed fetching:
- The user's feed URL is computed as: https://{STORAGE_ACCOUNT}.blob.core.windows.net/echo-audio-{userSlug}/feed.xml?{SAS_TOKEN}
- Get STORAGE_ACCOUNT and SAS_TOKEN from VITE_ env vars at build time.
- Parse RSS with fast-xml-parser.
- Cache the parsed feed in IndexedDB for offline access; refresh on app open.

iOS Shortcut integration:
- Add a route POST /api/share that accepts a URL and forwards it to the
  Echo Copilot Studio orchestrator via DirectLine. (Use a tiny Azure
  Static Web Apps API function for this.)

File structure:
  src/
    routes/  (Login.tsx, Feed.tsx, Player.tsx)
    components/  (EpisodeCard.tsx, AudioPlayer.tsx, NavBar.tsx)
    lib/  (feedClient.ts, idb.ts, directLineClient.ts)
    styles/
  public/
    icons/  (192, 256, 384, 512px PNG icons)
    manifest.webmanifest

Include:
- staticwebapp.config.json with route fallbacks for SPA
- A swa-cli.config.json for local dev
- README with deploy command (azure-static-web-apps GitHub Action)

Scaffold the whole project now. Use latest stable versions.
````

### Follow-up prompts

```
The audio element is fighting with the service worker over range requests.
Configure the SW to bypass cache for Range header requests.
```

```
Add a "now playing" mini player at the bottom of the Feed view that
appears once an episode starts and persists across route changes.
Use a Zustand store for player state.
```

```
The PWA install prompt isn't appearing on iOS. Add an "Install Echo" banner
that shows iOS users the manual "Add to Home Screen" instructions instead.
```

---

## Prompt 3: iOS Shortcut (Apple Shortcuts app — describe to user)

Apple Shortcuts can't be generated as code. Build this manually:

1. Open **Shortcuts app** → **+** → **New Shortcut**
2. Name it: **"Send to Echo"**
3. Add actions:
   - **Receive** → URLs from Share Sheet
   - **Get Contents of URL**
     - URL: `https://echo.yourdomain.com/api/share`
     - Method: POST
     - Request Body → JSON: `{ "url": "Shortcut Input", "userId": "vesolomons@microsoft.com" }`
     - Headers: `Content-Type: application/json`, `x-share-key: <your shared secret>`
   - **Show Notification**: "Echo is making your episode..."
4. **Settings → Show in Share Sheet** → ON, accept URLs only
5. Save

Now from Safari/Chrome, tap **Share → Send to Echo** on any article.

### Android equivalent

Use **Tasker** or **HTTP Shortcuts** app:

1. Install **HTTP Shortcuts** (free, open source)
2. New shortcut → POST → `https://echo.yourdomain.com/api/share`
3. JSON body with `{{shared_text}}` as the URL
4. Make it "shareable" so it appears in the system share sheet

---

## Prompt 4: Static Web App API endpoint /api/share (for both shortcuts)

In your `echo-listener` repo, create an SWA managed function.

````
Create an Azure Static Web Apps API function in TypeScript at
api/share/index.ts that:

1. Accepts POST { url: string, userId: string }
2. Validates x-share-key header against env SHARE_KEY
3. Posts a DirectLine message to the Echo Copilot Studio bot:
   - DirectLine secret in env COPILOT_DIRECTLINE_SECRET
   - Start a new conversation, send a message containing the URL,
     wait for the agent's first response that contains "listenUrl",
     return it as JSON
4. Returns { listenUrl, status: "started" } immediately if the agent
   responds within 3s, else { status: "queued" } and the user gets
   the notification when the episode is ready (via a Web Push from
   the Publisher when it finishes)

Use @azure/functions v4 model. Include the staticwebapp.config.json
update needed to expose this route.
````

---

## Prompt 5: Teams trigger (Copilot Studio handles this natively)

Teams is wired up entirely through Copilot Studio — no code needed:

1. In Copilot Studio → your Echo agent → **Channels** → **Microsoft Teams** → **Turn on**
2. Click **Availability options** → **Make available to people in my org**
3. Copy the **deep link** — share with your demo audience
4. Users go to Teams → search for "Echo" → start a chat → paste a URL

For the demo, pin Echo to your Teams sidebar so it's one click away.

---

## Prompt 6: Bicep infrastructure

**Don't vibe-code this one.** The Bicep is hand-authored under `infra/` in this repo so the deploy is reproducible. See `infra/main.bicep` and `infra/modules/*.bicep`. Read the inline comments — they explain the Flex Consumption + shared `law-uksouth` choices.

The deploy is one command:

```pwsh
az deployment sub create `
  --location swedencentral `
  --template-file infra/main.bicep `
  --parameters infra/main.parameters.json
```

---

## Working with GitHub Copilot — tips for this build

- **Use Copilot Chat with `@workspace`** to ask cross-file questions ("how does the orchestrator call the Publisher?").
- **Use `/explain` and `/fix`** on Bicep errors — Bicep is the part Copilot makes the most mistakes on, and the explainer catches them.
- **Don't let it import packages that aren't real.** If a `package.json` lists something weird, search npm to confirm it exists.
- **Commit after each prompt** — Copilot generations are large and you'll want to revert often.
- **Use `.github/copilot-instructions.md`** at the repo root to set repo-wide context. Suggested content:
  ```
  This repo is part of Echo, an AI agent system that turns articles into
  two-host podcasts on the Microsoft stack (Copilot Studio + Foundry +
  Azure AI Speech). The project name is Echo. Use British or American
  English consistently. Prefer Azure SDKs over raw REST when possible.
  Keep functions small, named clearly, and typed strictly.
  ```
