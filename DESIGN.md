# MacBridge Design System

## Product Frame

MacBridge is not a generic hosting product and it is not a Mac rental marketplace. It is a controlled cloud macOS workflow for developers who need iOS build capability without owning or maintaining Apple hardware. The public-facing site should emphasize relief, readiness, and technical trust rather than internal provisioning mechanics.

## Brand Intent

- Precise, premium, and calm
- Technical without reading like internal infrastructure notes
- Futuristic through restraint, not gimmicks
- Operationally credible for developers shipping Flutter and iOS builds

## Audience

- Flutter developers working primarily from Windows
- Solo builders and small teams that need TestFlight delivery
- AI-assisted developers who want Claude Code, Codex, or OpenCode in a ready environment
- Buyers who care about speed-to-build more than learning macOS setup

## Messaging Priorities

1. No Mac required
2. No setup required
3. Xcode and iOS tooling already working
4. Connect, build, archive, and ship to TestFlight
5. Bring your preferred coding agent and workflow

## Content Guardrails

- Do not expose internal lesson counts, terminal log lengths, or provisioning journal statistics on the landing page.
- Do not over-describe bootstrap layers or implementation phases.
- Do not imply MacBridge is the cloud provider itself if the architecture uses external infrastructure.
- Keep technical specificity only when it increases trust for the buyer.
- Public copy should describe outcomes first and mechanics second.

## Visual Direction

The interface should feel like a private command center: dark, polished, and sharply structured with a controlled teal-electric accent. Surfaces should layer with subtle gradients and glass-like borders, but the layout must stay readable and not drift into noisy cyberpunk styling.

## Color System

- Background base: `#071116`
- Background elevated: `#0d1a21`
- Surface panel: `rgba(13, 26, 33, 0.72)`
- Surface strong: `#10232c`
- Border soft: `rgba(124, 224, 255, 0.16)`
- Border emphasis: `rgba(124, 224, 255, 0.34)`
- Primary text: `#f2fbff`
- Secondary text: `#9ab5c0`
- Muted text: `#6d8793`
- Accent cyan: `#7ce0ff`
- Accent mint: `#7fffd4`
- Accent highlight: `#d7fff4`
- Warning contrast: `#ffb36b`

Color theory rationale:

- The deep blue-green base conveys infrastructure, precision, and low-noise focus.
- Cyan provides a modern technical accent without defaulting to purple futurism.
- Mint is used sparingly to signal readiness and success states.
- Warm contrast is reserved for friction or pain points so the hierarchy stays legible.

## Typography

- Display and body: Manrope
- Utility, labels, and technical metadata: IBM Plex Mono

Type usage:

- Headlines should be compact, high-contrast, and slightly dense.
- Supporting copy should stay short with generous line-height.
- Labels, chips, and metrics should use mono to reinforce the technical environment.

## Layout Principles

- Use wide horizontal composition on desktop and stacked clarity on mobile.
- Alternate between dense information blocks and open breathing space.
- Prefer asymmetric section framing over repetitive equal-card grids where possible.
- Keep CTA paths obvious and low-friction.

## Components

- Hero with framed status rail and strong left-to-right narrative
- Glass panels with thin luminous borders
- Chip tags for toolchain and agent support
- Comparison or pain-relief panels with explicit contrast
- Timeline or process strip for the build journey
- Pricing card that reads as a clean transaction, not a startup gimmick

## Motion

- Use subtle entrance fades and upward drift for key sections
- Use slow ambient glows rather than fast looping effects
- Hover interactions should slightly lift or brighten surfaces
- Motion should never reduce readability or feel decorative-only

## Accessibility

- Maintain strong contrast for all body text and UI labels
- Preserve visible focus states on links and buttons
- Avoid relying on color alone for meaning
- Keep line lengths reasonable and tap targets generous on mobile

## Success Criteria

The page should make a Windows-based Flutter developer immediately understand:

- what MacBridge is,
- why it removes the usual Apple hardware friction,
- how quickly they can get to a TestFlight-ready build,
- and why this is a credible, premium workflow rather than a fragile setup hack.
