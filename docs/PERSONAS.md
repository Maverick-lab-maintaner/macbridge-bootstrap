# MacBridge Personas — and What Software-First Does to Each

> The three personas from `ONBOARDING_ENVIRONMENT_STRATEGY.md` /
> `HONEST_ASSESSMENT.md`, re-read through the software-first (Studio) decision in
> [`BUSINESS_MODELS.md`](BUSINESS_MODELS.md).

**The key shift:** the old plan assumed everyone needed *us* to provide the Mac. Software-first
splits the personas by a new question — **do they already have a Mac?** That single question
decides whether Studio serves them *today* or whether they wait for Managed.

| | AI-native builder | Flutter developer (Windows) | Small startup / indie team |
|---|---|---|---|
| **Who** | Uses Claude Code / OpenCode / Codex as the primary interface; ships with prompts | Knows Flutter/Dart; wants `flutter build ios` to just work; hates macOS admin | 2–5 people / an agency shipping client apps to TestFlight |
| **Core pain** | "My agent can't help with iOS — there's no macOS" | "Xcode/CocoaPods/signing hell, and I'm on Windows" | "We need reliable iOS delivery without a Mac admin on staff" |
| **GTM query bucket** | `build ios without mac`, `xcode not found flutter` | `flutter ios build windows`, `cocoapods flutter ios error` | `client launch`, `deadline`, `production build` |
| **Already has a Mac?** | **Often yes** — a Mac mini/Studio they run agents on locally | **Usually no** — pure Windows | **Sometimes** — an office Mac mini |
| **Served by, today** | **Studio** on their own Mac | **Managed (later)** or cloud-Mac + Studio | **Studio** on the team Mac, or Managed later |
| **AI keys** | Already has Anthropic/OpenAI accounts → BYO is natural | May need pointing to a provider | Team keys, BYO |

## What software-first changes, per persona

### 1. AI-native builder — *the biggest winner*
Under the old hosted model, this persona had to rent our Mac. But many AI-native builders
**already own a Mac mini/Studio** to run agents locally — they were previously *excluded* from
the value (doctor, signing, prepared workspace, updates). **Studio sells to them today**, on
hardware they already own. BYO AI keys is natural because they already have provider accounts.
This is the persona to launch at first: lowest friction, highest fit, and they hang out exactly
where Radar listens.

### 2. Flutter developer (Windows) — *most affected by the BYO-onboarding step*
This is the classic target — but usually has **no Mac**, so software-first adds the very step
that hurts conversion: *buy/rent a Mac → connect → install*. They are the **strongest argument
for the Managed tier** (one-click, we provide the Mac ≥24h). Until Managed ships, serve them by
making "rent a cloud Mac (Macly/AWS) + run Studio" a clean, documented path. Do **not** pretend
Studio alone solves their whole problem — it solves the *setup*, not the *missing Mac*.

### 3. Small startup / indie team — *continuity buyer*
Values reliability and continuity over price. Often has an **office Mac** (or will dedicate a
cloud Mac). **Studio on their shared Mac** works now (team seats, shared config, the knowledge/
updates channel); heavy/continuous users graduate to **Managed Dedicated** later. The recovery
and "Xcode 27 broke Flutter — known fix" value matters most here, because downtime blocks a
whole team.

## Launch implication

Sequence the go-to-market to match the model:

1. **Launch Studio to persona 1 (AI-native builders with a Mac)** — best fit, least friction.
2. **Serve persona 3 (teams with a Mac)** with Studio + team seats.
3. **Hold persona 2 (Windows, no Mac)** for the Managed tier — or give them a clean cloud-Mac
   + Studio path in the meantime, and collect them on the Managed waitlist (already on the site).

This is why the site now leads with Studio and marks Managed "coming soon": it points persona 1
and 3 at something they can buy today, and persona 2 at the waitlist that matches their need.
