// MacBridge — Customer Dashboard API (BUILT, NOT WIRED).
//
// Composes the one payload the dashboard UI renders, from data the platform
// already produces (see docs/WEBSITE_DASHBOARD_SPEC.md "Implementation"):
//
//   - machine status:  latest status-contract JSON shipped by healthd
//                      (same KV the health-receiver worker writes: mac:<id>)
//   - lease record:    lease:<customer_id>   { machine_id, tier, allocated_at,
//                      earliest_release_at, expires_at }
//   - SLA acceptance:  sla:<customer_id>     { accepted_at, sla_version }
//   - license state:   license:<key> records written by the commerce webhook
//
// DARK GUARDS: without an AUTH_TOKEN secret and the KV binding this worker
// refuses all traffic, so an accidental deploy is inert. Real auth (per-
// customer tokens/magic links) replaces the shared token when the dashboard
// goes live — this stub exists so the payload shape is settled and testable.

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname !== "/api/dashboard" || request.method !== "GET") {
      return new Response("not found", { status: 404 });
    }
    if (!env.DASHBOARD_AUTH_TOKEN || !env.MACBRIDGE_FLEET) {
      return new Response("customer api is not wired", { status: 503 });
    }
    const auth = request.headers.get("Authorization") ?? "";
    if (auth !== `Bearer ${env.DASHBOARD_AUTH_TOKEN}`) {
      return new Response("unauthorized", { status: 401 });
    }

    const customerId = url.searchParams.get("customer");
    if (!customerId) {
      return new Response("missing ?customer=", { status: 400 });
    }

    const lease = await env.MACBRIDGE_FLEET.get(`lease:${customerId}`, "json");
    const sla = await env.MACBRIDGE_FLEET.get(`sla:${customerId}`, "json");

    // SLA gate: hosted plans must accept Apple's terms before anything else.
    if (lease && !sla) {
      return Response.json({ state: "sla-gate", lease });
    }

    const contract = lease?.machine_id
      ? await env.MACBRIDGE_FLEET.get(`mac:${lease.machine_id}`, "json")
      : null;

    // The 24h floor, computed server-side so the UI can't get it wrong.
    const insideMinimum =
      lease?.earliest_release_at && new Date(lease.earliest_release_at) > new Date();

    return Response.json({
      state: contract?.summary?.state ?? (lease ? "provisioning" : "tooling"),
      plan: { tier: lease?.tier ?? "tooling", mac_included: Boolean(lease), ai_tokens_included: false },
      machine: contract && {
        id: lease.machine_id,
        checks: contract.checks,
        summary: contract.summary,
      },
      lease: lease && { ...lease, inside_24h_minimum: Boolean(insideMinimum) },
      sla: sla ?? null,
    });
  },
};
