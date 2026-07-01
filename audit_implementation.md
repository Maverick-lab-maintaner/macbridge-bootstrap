# Audit Implementation

## Synthesis

The repo already had the right primitives: layered bootstrap, independent verification, fleet health shipping, and a thin Go CLI. The missing architecture was not "more scripts". It was a shared operational contract across those scripts and a small seam for provider orchestration.

The highest-leverage improvements from the audit and knowledge-base context were:

1. Canonical status contract shared by `verify`, `healthd`, `doctor`, the dashboard, and the CLI.
2. Explicit machine states beyond green/red: `ready`, `degraded`, `blocked`.
3. A first machine-readable `doctor` rules layer so institutional knowledge is executable.
4. Local usage telemetry instead of webhook-only best effort.
5. A provider abstraction seam so the CLI stops baking in one-off manual provisioning assumptions.

## Implementation Plan

- [x] Add a shared shell status contract library in `lib/status-contract.sh`.
- [x] Move `verify.sh` and `healthd.sh` onto the shared contract schema.
- [x] Add `doctor.sh` plus `lib/doctor-rules.json` for actionable remediation.
- [x] Extend telemetry so events are written locally as NDJSON as well as shipped remotely.
- [x] Add a provider interface in Go and route `macbridge provision` through it.
- [x] Replace the CLI's fragile string-parsed status path with real JSON parsing.
- [x] Update the dashboard to understand `ready` / `degraded` / `blocked`.

## Acceptance Criteria

- `verify.sh --json` emits one stable schema with summary, provider, telemetry, and checks.
- `healthd.sh` emits the same schema family and can still POST to a webhook.
- `doctor.sh` turns failing checks into concrete remediation steps.
- `macbridge status` parses JSON structurally instead of scraping strings.
- The dashboard no longer assumes a binary healthy/degraded world.

## Result

The repo is still shell-first, which is the correct choice for this stage. The improvement is that it now has a clearer control plane: verification is canonical, status semantics are explicit, remediation is encoded, telemetry is durable locally, and the Go CLI has an actual provider seam instead of hard-coded provisioning copy.
