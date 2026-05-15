# Echo — SSML Template for Ava + Andrew

This is the canonical SSML pattern the Scriptwriter agent should follow. Use it as the reference when debugging audio output, or paste it into the Scriptwriter prompt as a few-shot example if voice consistency drifts.

---

## Voice IDs

| Host | Voice name (Azure Speech HD) | Style |
|------|------------------------------|-------|
| Andrew | `en-US-Andrew3:DragonHDLatestNeural` | Warm American male, mid-30s, curious explainer |
| Ava | `en-US-Ava3:DragonHDLatestNeural` | Calm American female, mid-30s, precise analyst |

Both are HD voices in the Dragon family — they produce the most natural-sounding two-host audio currently available from Azure. They support neural prosody, mid-sentence emphasis, and natural breathing.

---

## Document skeleton

Every script the Scriptwriter produces must start with this skeleton:

```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
  <!-- Cold open -->
  <voice name="en-US-Andrew3:DragonHDLatestNeural">
    [Andrew's opening line — the surprising hook]
    <break time="350ms"/>
  </voice>
  <voice name="en-US-Ava3:DragonHDLatestNeural">
    [Ava's reaction + tease of what's coming]
    <break time="600ms"/>
  </voice>

  <!-- Why it matters -->
  <voice name="en-US-Ava3:DragonHDLatestNeural">
    [Ava sets up the context]
    <break time="350ms"/>
  </voice>
  ...
</speak>
```

---

## Break timing rules

| Where | Duration | Why |
|-------|----------|-----|
| Between speaker turns | `350ms` | Natural conversational beat — neither rushed nor awkward |
| Within a turn, before emphasis | `250ms` | "And here's the thing... [break] it was 16 CVEs" |
| Between major segments | `600ms` | Lets the listener feel a topic shift |
| Before the sign-off | `800ms` | Gives the ending weight |

Do **not** put breaks at the start of a voice element or immediately before the closing tag — Azure Speech inserts a natural pause there already, and a double pause feels broken.

---

## Prosody for weight

When a line should feel weightier — the punchline, the takeaway, the caveat — wrap the key clause in `<prosody rate="-5%">`:

```xml
<voice name="en-US-Ava3:DragonHDLatestNeural">
  Here's what's wild —
  <prosody rate="-5%">twenty-one out of twenty-one planted bugs, zero false positives.</prosody>
</voice>
```

Avoid going beyond `-10%` — it starts to sound theatrical.

For lines that should feel snappier (banter, reactions), use `<prosody rate="+5%">`:

```xml
<voice name="en-US-Andrew3:DragonHDLatestNeural">
  <prosody rate="+5%">Wait, really? Zero false positives?</prosody>
</voice>
```

---

## Emphasis on single words

Use `<emphasis level="moderate">` for one word per turn maximum. More than one and the voice starts to sound performative.

```xml
<voice name="en-US-Andrew3:DragonHDLatestNeural">
  So the system found <emphasis level="moderate">sixteen</emphasis> new bugs in one Patch Tuesday?
</voice>
```

Levels:
- `reduced` — almost never used
- `moderate` — default for the important word
- `strong` — only for the single most surprising number in the whole episode

---

## Example: full cold open

Here's a complete cold open exchange you can show the Scriptwriter as a reference example.

```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">

  <voice name="en-US-Andrew3:DragonHDLatestNeural">
    Sixteen new Windows CVEs shipped in this month's Patch Tuesday.
    <break time="250ms"/>
    <prosody rate="-5%">Every single one of them was found by AI.</prosody>
    <break time="350ms"/>
  </voice>

  <voice name="en-US-Ava3:DragonHDLatestNeural">
    <prosody rate="+5%">Sixteen?</prosody>
    <break time="250ms"/>
    That's not a research paper anymore. That's production security work, at scale.
    <break time="350ms"/>
  </voice>

  <voice name="en-US-Andrew3:DragonHDLatestNeural">
    And four of them are rated critical. Today on Echo —
    how Microsoft's new agentic security system, called <emphasis level="moderate">MDASH</emphasis>,
    just topped a major industry benchmark, and what it means for everyone
    shipping software.
    <break time="600ms"/>
  </voice>

</speak>
```

---

## Banter patterns that work

These are dialogue moves that read naturally in TTS. Use them sparingly.

**The interrupt-to-define:**
```xml
<voice name="en-US-Ava3:DragonHDLatestNeural">
  ...the harness uses a five-stage pipeline — prepare, scan, validate, dedup, prove —
</voice>
<voice name="en-US-Andrew3:DragonHDLatestNeural">
  Hold on, what's "dedup" in this context?
</voice>
<voice name="en-US-Ava3:DragonHDLatestNeural">
  Good catch. Different agents will sometimes flag the same underlying bug
  from different angles. Dedup is the step that collapses those duplicates.
</voice>
```

**The clarifying paraphrase:**
```xml
<voice name="en-US-Andrew3:DragonHDLatestNeural">
  So let me put that in plain English — they don't trust any single AI model.
  They run a whole ensemble of them, and the bugs only count if multiple
  agents agree.
</voice>
<voice name="en-US-Ava3:DragonHDLatestNeural">
  Exactly that. And the verification stage actually generates a working
  proof-of-concept exploit, so there's no "maybe it's a bug" — it's proven.
</voice>
```

**The honest caveat (Ava raises, Andrew reflects):**
```xml
<voice name="en-US-Ava3:DragonHDLatestNeural">
  One thing worth flagging — these are retrospective benchmarks.
  They tested the system on bugs we already knew about.
</voice>
<voice name="en-US-Andrew3:DragonHDLatestNeural">
  Right, so the open question is whether it generalizes to bugs nobody's
  seen yet. Which is the whole point.
</voice>
```

---

## XML escaping checklist

Before returning SSML, the Scriptwriter must escape:

| Character | Replace with |
|-----------|--------------|
| `&` | `&amp;` |
| `<` (in text) | `&lt;` |
| `>` (in text) | `&gt;` |
| `"` (in attributes) | `&quot;` |

The Azure Speech endpoint will reject the entire payload if any of these appear unescaped in text content.

---

## What NOT to use

These SSML tags are not supported on the HD voices and will either be ignored or cause errors:

- `<voice gender>` — pick the voice by name
- `<phoneme>` — HD voices use their own pronunciation model
- `<say-as interpret-as="...">` for `cardinal`/`ordinal` — say the number out loud in the script instead
- `<mstts:express-as style="...">` — supported on some standard voices but **not** on Dragon HD voices yet
- `<audio src="...">` — no external audio in the demo

---

## Estimating duration

Roughly 155 words per minute for two-host conversational. Targets:

| Target episode length | Approximate word count |
|-----------------------|------------------------|
| 8 min | 1,240 |
| 10 min | 1,550 |
| 12 min | 1,860 |
| 14 min | 2,170 |
| 16 min | 2,480 |

Break time adds about 8–12% on top of pure word-count time. The Scriptwriter's `durationSeconds` estimate should already account for breaks.
