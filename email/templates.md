# MacBridge — Onboarding Emails

Email templates for the customer onboarding flow. Sent via your email provider
(Resend, SendGrid, SES, or LemonSqueezy transactional emails).

---

## Email 1: Your MacBridge Environment Is Ready

**Subject:** 🟢 Your MacBridge environment is ready

**Trigger:** Bootstrap completes + all health checks pass.

---

Hey {{name}},

Your {{tier}} MacBridge environment is provisioned and verified.

**🖥️  DeskIn (GUI):** `{{deskin_id}}` — open DeskIn, enter this ID.
**💻 SSH:** `ssh {{username}}@{{host}}`

**Installed and verified:**
✓ Xcode 26.6 · ✓ Flutter 3.44.4 · ✓ CocoaPods 1.16.2
✓ Ruby 4.x · ✓ Homebrew · ✓ Git + GitHub CLI
{{#if agent_tier}}
✓ Claude Code · ✓ OpenCode · ✓ Codex CLI · ✓ tmux
{{/if}}
✓ iOS Simulator 26.5 · ✓ flutter doctor (green)

**Estimated setup time: 0 minutes.** Everything was verified before this email reached you.

💡 First time? Start with DeskIn — see the full Mac desktop.
💡 Power user? SSH directly — terminal and tools ready.

**Your SSH key is attached.** Import it into your SSH client (Termius, Terminal, VS Code).

**Next steps:**
1. Connect via SSH or DeskIn
2. Clone your project: `git clone git@github.com:you/your-repo.git`
3. {{#if agent_tier}}Start your agent: `claude`, `opencode`, or `codex`{{else}}Run: `flutter build ios`{{/if}}

Questions? Reply to this email. We built MacBridge from 10 hard-earned provisioning lessons — we know what breaks and how to fix it.

— Maverix Labs

---

## Email 2: Welcome Wizard Reminder

**Subject:** 👋 First time on MacBridge? Here's a 3-minute guide.

**Trigger:** 24 hours after environment ready, if user hasn't connected.

---

Hey {{name}},

Your MacBridge environment has been waiting for you. It takes about 3 minutes to go from "ready" to "coding."

**Quick start:**
1. **Connect:** `ssh {{username}}@{{host}}`
2. **Welcome Wizard:** `bash welcome.sh` — guides you through GitHub auth and project setup
3. **Start coding:** Clone your repo and run `flutter build ios`

{{#if agent_tier}}
Your AI agents are pre-installed. Type `claude`, `opencode`, or `codex` and start building.
{{/if}}

**From your phone?** Install Termius (free), import the SSH key we sent, and connect. Same session, different device. The agent keeps working while you commute.

— Maverix Labs

---

## Email 3: Session Expiring Soon

**Subject:** ⏰ Your MacBridge session expires in 2 hours

**Trigger:** Rental period ending (e.g., 22 hours into a 24-hour session).

---

Hey {{name}},

Your MacBridge session expires in 2 hours. Your data will be preserved — the Mac stops but nothing is lost.

**Before your session ends:**
- Push any uncommitted work: `git push`
- Your projects and configs will be exactly as you left them
- Resume anytime: just sign in again

**Need more time?** Extend your session at {{billing_url}}.

— Maverix Labs

---

## Email 4: Golden Image Update Available

**Subject:** 🔔 MacBridge update available — new {{component}} version

**Trigger:** New Xcode or Flutter stable release detected by watcher scripts.

---

Hey {{name}},

{{component}} {{new_version}} was released {{date}}. Your MacBridge environment is on {{current_version}}.

**What's new:** {{release_notes_summary}}

**Upgrade your environment (opt-in):**
1. SSH into your Mac
2. Run: `bash migrate.sh --upgrade`
3. Your projects, keys, and configs are preserved — only the toolchain updates

This is an opt-in upgrade. Your current environment continues to work. No forced updates, ever.

— Maverix Labs
