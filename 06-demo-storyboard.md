# Echo — Customer Demo Storyboard

A 7-minute demo that lands the value of building agentic systems on the Microsoft stack. Aimed at customers evaluating Copilot Studio + Foundry for production use cases.

## The narrative arc

**Setup (1 min):** Everyone has the "too much to read" problem. Most knowledge workers have 30+ open tabs they intend to read and never will. Today I'll show you how I turned that problem into an agent system in a week.

**Demo (4 min):** Live walk-through of Echo doing its thing, end to end, on stage.

**The teardown (1.5 min):** Open the hood. Show that this is four agents, two custom connectors, one PWA, and a Function — all on standard MS building blocks.

**The takeaway (30s):** The reusable pattern. "You can build this kind of thing for any text-to-output workflow — research summaries, customer call recaps, internal newsletters — using exactly the same scaffolding."

---

## The room setup

| What | Where |
|------|-------|
| Laptop with Teams open, Echo agent pinned to the sidebar | Primary screen |
| Phone (iOS) with the Echo PWA on the home screen and the "Send to Echo" shortcut in Safari's share menu | Camera-mirrored to screen via QuickTime |
| Azure portal tab with `rg-echo-demo` resource group open | Backup tab |
| Copilot Studio with Echo agent designer open | Backup tab |
| Foundry portal with the Researcher and Scriptwriter agents | Backup tab |

Have one **fresh, never-demoed article URL** ready. Memorize it. The Microsoft Security blog post on MDASH is a great default because it's relevant, has crunchy facts, and lets you nod to MS's own AI work.

---

## The 7-minute script

### Beat 1 (0:00–1:00) — Setup the problem

> "Quick show of hands — who's got more than fifty browser tabs open right now? Yeah. Me too. Some of those are articles I genuinely want to read. None of them will get read.
>
> So a couple of weeks ago I decided to fix it. I wanted something that would let me share an article from my phone — like I'd send it to a friend — and get back a real podcast episode I could listen to on the train. Two hosts. Conversational. Actually engaging, not robot-reading-Wikipedia.
>
> What I'm going to show you is the result. I built it in a week, entirely on the Microsoft stack — Copilot Studio, Azure AI Foundry, Azure AI Speech. The interesting part isn't the podcast. The interesting part is the *pattern* — because the same scaffolding works for any 'read this stack of stuff and tell me what matters' workflow."

### Beat 2 (1:00–2:30) — The mobile share-sheet trigger

> "Here's my phone. I'm reading something — let's say this Microsoft Security blog post about an AI system called MDASH that just topped a vulnerability-discovery benchmark."

**[Open Safari to the article. Pause. Read the headline aloud.]**

> "Twenty minutes of reading. I don't have twenty minutes. So I tap Share."

**[Tap share button.]**

> "I added a shortcut here called 'Send to Echo'. One tap."

**[Tap the shortcut. A notification appears: "Echo is making your episode..."]**

> "That's it. Echo is now off doing its thing in the background. In about 90 seconds I'll get a push notification when it's done. Let me show you what's happening on the Teams side while we wait."

### Beat 3 (2:30–3:30) — The Teams chat trigger (alternate path)

**[Switch to laptop. Teams open. Echo pinned to sidebar.]**

> "I can also just talk to Echo in Teams. Same agent, different channel."

**[Paste a different article URL into Teams chat.]**

> "I'll paste an article URL in — this one's about climate policy."

**[Echo responds with the status messages live: "Reading the article now..." → "Writing the script for Ava and Andrew..." → "Recording the episode..." → "Publishing it to your feed..."]**

> "Notice the agent isn't telling me which APIs it's calling. The orchestrator agent knows it's running the researcher first, then the scriptwriter, then sending the script to Azure Speech, then publishing to my private feed. But the user just sees 'Reading the article...'. That's important — it's an agent, not a workflow.
>
> While that one cooks, let me check the phone."

### Beat 4 (3:30–5:00) — The payoff: listening on the phone

**[Switch to phone screen mirror. Notification has fired: "Defense at AI Speed is ready."]**

> "Push notification's in. Tap it — that opens the Echo PWA."

**[The PWA opens to the player view.]**

> "This is a Progressive Web App. It's installable like a native app — you tap 'Add to Home Screen' once and it lives on your phone like any other app. Offline support, Web Share API, the works.
>
> Let's play it."

**[Tap play. Ava and Andrew start the cold open. Let it play for 25–30 seconds — long enough to land the surprise of "this actually sounds like two people".]**

> "These are Azure AI Speech HD voices — Ava and Andrew, en-US-Dragon. Both released recently. The script is written by a Foundry agent specifically to play to their strengths — Andrew is the curious one, Ava is the analyst, and the script puts the right kind of line in each one's mouth.
>
> 12 minutes of audio. Whole train ride home."

**[Pause the audio. Pull up the Feed view in the PWA.]**

> "And every episode I generate shows up here in my feed. Private. Per-user. Backed by an RSS feed under the hood, so if someone wanted to subscribe in Apple Podcasts or Spotify, they could."

### Beat 5 (5:00–6:00) — The teardown

**[Switch to Copilot Studio with the Echo agent open.]**

> "Now let me show you what's actually behind this — because the architecture is the whole point.
>
> The user-facing agent — Echo — lives in Copilot Studio. It's an orchestrator. It doesn't know how to read articles, doesn't know how to write scripts, doesn't know how to make audio. It just knows which specialist to call.
>
> When a URL comes in, Echo calls a Researcher agent — that one lives in Azure AI Foundry, runs on GPT-4o, and uses the web browsing tool to actually fetch and structure the article into a clean brief.
>
> Then Echo passes that brief to a Scriptwriter agent — also in Foundry, this one tuned for creative writing — that produces a full SSML script with the two hosts' voices laid out.
>
> Then Echo calls a custom connector that wraps an Azure Function — that Function calls Azure AI Speech to turn the SSML into MP3, drops it in Blob Storage, and updates the user's RSS feed.
>
> Finally Echo replies in chat with a link to the episode.
>
> Three agents, two custom connectors, one Function App, one PWA. That's the whole core system."

**[Switch to Foundry portal briefly to show the Researcher and Scriptwriter agents listed with their descriptions.]**

> "Every one of these is a few hundred lines of configuration. No model training. No infrastructure on my side beyond the standard stuff."

### Beat 5b (6:00–6:30) — The cross-cloud moment (optional, if Bedrock is online)

**[Back to Teams. Type: "ask my catalog — what episodes have I made about AI security?"]**

> "One more thing. Echo can also reach across clouds. This question is going to a Lambda function in AWS, hitting Bedrock with Claude Haiku, against an index of every episode I've published. The interesting bit is the auth — the Lambda only accepts tokens issued by Microsoft Entra Agent ID against an Agent Identity Blueprint registered in our tenant. So even though the workload runs in AWS, governance lives in Entra. One identity surface, two clouds.
>
> When I'm not actively demoing this, I run `cdk destroy` and the whole AWS side goes to zero cost. `cdk deploy` brings it back in three minutes."

### Beat 5c (6:30–6:45) — M365 Copilot surface

**[Switch to M365 Copilot Chat in the browser.]**

> "And finally — same agent, different surface. Echo also lives in Microsoft 365 Copilot as a declarative agent, plus an API plugin so any Copilot conversation can publish an episode without leaving the chat."

### Beat 6 (6:45–7:00) — The takeaway

> "Four things to take home from this.
>
> First — the agent pattern beats the workflow pattern. I didn't draw a flowchart in Power Automate. I gave each agent a job description and let the orchestrator figure out the calls. Faster to build, far easier to change.
>
> Second — Copilot Studio is the connective tissue. Foundry hosts the specialist agents. Speech, Storage, Functions — the usual building blocks. Studio is where they get composed and where they show up to users — in Teams, in M365 Copilot, on the web.
>
> Third — governance scales across clouds. The AWS-hosted Q&A agent isn't a separate identity surface. It's an Agent Identity in Entra, same as the Microsoft-hosted ones.
>
> Fourth — the pattern reuses. Swap 'article' for 'sales call recording', 'support tickets', 'pull requests' — same architecture, different specialists. That's what makes this worth your team's time to understand.
>
> Happy to go deeper on any of it."

---

## Tabs and bookmarks for the live demo

Order them left to right in the browser so you can switch fast:

1. Article URL (in Safari on the phone, plus a backup in laptop browser)
2. Teams desktop app (Echo pinned)
3. Echo PWA on the phone (mirrored screen)
4. Copilot Studio → Echo agent designer
5. Azure AI Foundry → `aif-echo` → Agents
6. Azure portal → `rg-echo-prod` (in case someone asks about cost / SKUs)

---

## Backup talking points (for Q&A)

**"What does this cost to run?"**
> Pennies per episode. Speech is the biggest line item — about 2 cents per 1,000 characters at HD quality. A 12-minute episode is roughly 1,800 words, so under 4 cents in synthesis. The model calls add another cent or two. Storage and Functions are negligible at demo scale.

**"How long did this take you to build?"**
> A week of evenings. The Copilot Studio orchestrator was a couple of hours. The Foundry agents — Researcher and Scriptwriter — were maybe a day, mostly tuning the script prompt to get the two-host dialogue feeling natural. The PWA was the longest part — three or four evenings of vibe-coding with GitHub Copilot.

**"What if the article is paywalled or returns junk?"**
> The Researcher agent returns an error code if it can't get at least 500 readable words. Echo catches that and tells the user the article can't be read. We don't proceed if the brief is empty.

**"Could you swap out the voices?"**
> Yes — any Azure Speech voice works, including custom ones you've trained on your own brand. The voice IDs are in the SSML, so it's a one-line change in the Scriptwriter prompt to swap them.

**"Why not just use NotebookLM?"**
> Two reasons. One, this runs in our tenant on our compute, with our data governance. Two, the architecture is reusable for anything — NotebookLM is a fixed product, this is a pattern you can repurpose.

**"What about WhatsApp as a trigger?"**
> Out of scope for v1 — Azure Communication Services supports it as a channel and adding it is a parallel path to the iOS shortcut. Re-evaluate after the first 50 episodes when we know which triggers people actually use.

**"How does it handle long articles?"**
> The Scriptwriter aims for 12-minute episodes regardless of article length. It's not a transcription — it's a *synthesis*. For very long articles the Researcher still produces a structured brief; the Scriptwriter just picks the most narratively rich material.

**"What happens if multiple users hit it at once?"**
> Each user has their own Blob container, their own RSS feed. The Function App scales horizontally on the consumption plan. The bottleneck would be Foundry model rate limits, which you'd hit at a few dozen concurrent generations and can quota-up.

---

## Rehearsal checklist

- [ ] Generate one episode from each trigger (phone share-sheet + Teams chat) one hour before the demo. If anything's broken, you'll know.
- [ ] Charge the phone to 100%.
- [ ] Confirm screen mirroring works in the room you'll be presenting in.
- [ ] Have the article URLs in a notes file you can paste from — don't type them live.
- [ ] Practice the "while we wait" patter — the 90 seconds where Echo is running is the riskiest moment if it stretches.
- [ ] Have one already-generated episode in your feed as a fallback, in case the live generation fails on stage. If that happens, say "let me play one I made earlier" — totally fine, the agents don't have to perform live for the architecture story to land.

---

## What to *not* do during the demo

- Don't open the Function App logs or App Insights live — too much noise on screen.
- Don't read the Scriptwriter prompt out loud in full — point at it, say "this is the prompt that gives the hosts their personalities", and move on.
- Don't apologize for latency. 90 seconds of generation is fine if you're talking through it.
- Don't promise it works on every URL ever. It works well on news/blog articles. Twitter threads, video transcripts, paywalled content — different conversation.
