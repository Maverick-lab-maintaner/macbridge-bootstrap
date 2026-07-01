// MacBridge — LemonSqueezy purchase webhook → Studio Pro key delivery.
//
// STATUS: BUILT, NOT WIRED. Nothing deploys or references this worker until
// the activation steps in commerce/README.md are done. With no signing secret
// configured it refuses every request (503), so an accidental deploy is inert.
//
// Flow (when wired):
//   LemonSqueezy order_created/subscription_created
//     -> POST /webhook/lemonsqueezy (HMAC-SHA256 signed)
//     -> verify signature -> generate MB- key (same math as the Go CLI)
//     -> store {key, email, order} in KV -> deliver key to the customer
//
// Delivery note: the webhook response goes to LemonSqueezy, not the customer.
// Delivery is step 5 of the runbook (Resend email, or LemonSqueezy's own
// license-key field via API). Until then keys land in KV for manual sending.

import { generateKey, validate } from "./keygen.mjs";

const HANDLED_EVENTS = new Set(["order_created", "subscription_created"]);

async function verifySignature(secret, rawBody, signatureHex) {
  if (!signatureHex) return false;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(rawBody)));

  // Constant-time hex comparison.
  const expected = [...mac].map((b) => b.toString(16).padStart(2, "0")).join("");
  if (expected.length !== signatureHex.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signatureHex.toLowerCase().charCodeAt(i);
  }
  return diff === 0;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname !== "/webhook/lemonsqueezy" || request.method !== "POST") {
      return new Response("not found", { status: 404 });
    }

    // DARK GUARD: unconfigured worker refuses everything.
    if (!env.LEMONSQUEEZY_SIGNING_SECRET) {
      return new Response("commerce webhook is not wired (no signing secret configured)", { status: 503 });
    }

    const rawBody = await request.text();
    const ok = await verifySignature(
      env.LEMONSQUEEZY_SIGNING_SECRET,
      rawBody,
      request.headers.get("X-Signature"),
    );
    if (!ok) {
      return new Response("invalid signature", { status: 401 });
    }

    let payload;
    try {
      payload = JSON.parse(rawBody);
    } catch {
      return new Response("invalid JSON", { status: 400 });
    }

    const eventName = payload?.meta?.event_name;
    if (!HANDLED_EVENTS.has(eventName)) {
      // Acknowledge unhandled events so LemonSqueezy doesn't retry them.
      return Response.json({ handled: false, event: eventName ?? "unknown" });
    }

    const attrs = payload?.data?.attributes ?? {};
    const email = attrs.user_email ?? attrs.customer_email ?? "unknown";
    const orderId = payload?.data?.id ?? "unknown";

    // Idempotency: LemonSqueezy retries webhooks — never mint two keys for
    // one order.
    const orderKey = `order:${eventName}:${orderId}`;
    if (env.MACBRIDGE_COMMERCE) {
      const existing = await env.MACBRIDGE_COMMERCE.get(orderKey, "json");
      if (existing) {
        return Response.json({ handled: true, deduped: true });
      }
    }

    const licenseKey = generateKey();
    if (!validate(licenseKey).ok) {
      // Should be impossible; refuse rather than deliver a bad key.
      return new Response("key generation self-check failed", { status: 500 });
    }

    const record = {
      key: licenseKey,
      email,
      event: eventName,
      order_id: orderId,
      created_at: new Date().toISOString(),
      delivered: false, // flips true once email delivery (step 5) is wired
    };

    if (env.MACBRIDGE_COMMERCE) {
      await env.MACBRIDGE_COMMERCE.put(orderKey, JSON.stringify(record));
      await env.MACBRIDGE_COMMERCE.put(`license:${licenseKey}`, JSON.stringify(record));
    }

    // TODO(wire, step 5): deliver the key to `email` (Resend, or LemonSqueezy
    // license-key API). Until then: keys are in KV under license:* for manual
    // delivery.

    return Response.json({ handled: true, order_id: orderId });
  },
};
