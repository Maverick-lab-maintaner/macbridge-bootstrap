# Release Checklist — Homebrew Tap + v0.1.0

> The 10-minute runbook that turns Studio P0 (merged, proven on real hardware) into an
> installable release a beta user can `brew install`. Companion to
> [`STUDIO_PACKAGING.md`](STUDIO_PACKAGING.md).

---

## Prerequisite check (2 min, once)

- [x] **Is `macbridge-bootstrap` public?** ✅ Verified PUBLIC (2026-07-01) — Homebrew
  formulas can download release assets over plain HTTPS with no auth.
- [ ] You are logged into `gh` as the repo owner (`gh auth status`).

## A. One-time: create the tap repo (5 min)

A Homebrew "tap" is just a GitHub repo named `homebrew-<something>` containing formulas.

```bash
# 1. Create the tap repo (public — Homebrew requires it)
gh repo create Maverick-lab-maintaner/homebrew-tap --public \
  --description "Homebrew tap for MacBridge" --clone
cd homebrew-tap
mkdir Formula

# 2. Seed it with the formula template from the main repo
cp ../macbridge-bootstrap/dist/homebrew/macbridge.rb Formula/macbridge.rb
git add Formula/macbridge.rb
git commit -m "Add macbridge formula (placeholder shas until first release)"
git push
```

Customers will then use:

```bash
brew tap maverick-lab-maintaner/tap
brew install macbridge
```

## B. Per-release: cut v0.1.0 (5 min)

```bash
cd macbridge-bootstrap
git checkout master && git pull

# 1. Tag — this is the entire release trigger.
#    release.yml builds darwin-arm64, darwin-amd64, windows-amd64 (embedded tooling,
#    version stamped via ldflags), writes checksums.txt, creates the GitHub Release.
git tag v0.1.0
git push origin v0.1.0

# 2. Watch it finish (~1 min)
gh run list --workflow release.yml --limit 1
gh release view v0.1.0
```

Then update the formula with the real hashes:

```bash
# 3. Grab the two darwin sha256s from the release
gh release download v0.1.0 --pattern checksums.txt --output - | grep darwin

# 4. In homebrew-tap/Formula/macbridge.rb:
#    - set `version "0.1.0"`
#    - replace REPLACE_WITH_ARM64_SHA256 / REPLACE_WITH_AMD64_SHA256
git -C ../homebrew-tap add Formula/macbridge.rb
git -C ../homebrew-tap commit -m "macbridge 0.1.0"
git -C ../homebrew-tap push
```

## C. Verify (5 min, needs any Mac — or use CI)

**On a Mac:**

```bash
brew tap maverick-lab-maintaner/tap
brew install macbridge
macbridge --version          # -> macbridge version v0.1.0
macbridge license            # -> free tier
macbridge install --tier vanilla   # the product path (needs Xcode present)
macbridge status
```

**No Mac handy?** Dispatch the smoke on the tag instead — it exercises the same surface on
a real Apple runner for $0:

```bash
gh workflow run macos-smoke.yml --ref v0.1.0 -f run_bootstrap=true
```

## D. Beta onboarding (per user, 1 min)

```bash
# Generate keys (vendor-only tool — never in releases)
go run ./cmd/mbkeygen 5
```

Send each beta user:

> ```
> brew tap maverick-lab-maintaner/tap && brew install macbridge
> macbridge install            # provisions your Mac (needs Xcode installed once)
> macbridge activate MB-XXXX-XXXX-XXXX-XXXX   # your Pro key
> ```
> Your own Anthropic/OpenAI/Codex keys power the agents — MacBridge never bundles tokens.

Track who got which key (a simple sheet is fine at beta scale). When LemonSqueezy checkout
lands, key delivery moves to the purchase email.

## E. Known caveats / deferred

- **Gatekeeper:** the Homebrew path works unsigned. *Direct* binary downloads will be
  blocked until Developer ID signing + notarization (needs an Apple Developer account;
  tracked in `STUDIO_PACKAGING.md` §3). Don't advertise direct downloads until then.
- **License checks are offline** (checksum + local record). Server-side entitlement
  attaches at P1 with the updates channel — fine for beta.
- **Windows binary** in the release is the *operator/remote* build (`--host` mode);
  `macbridge install` correctly refuses to run there.

## Release cadence after v0.1.0

Any merged change to the tooling or CLI → bump tag (`v0.1.x`), push, update the two shas
in the tap. The embedded tooling means a release automatically carries the latest scripts
and doctor rules — until the P1 updates channel decouples knowledge updates from binary
releases.
