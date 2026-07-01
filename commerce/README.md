# Commerce — LemonSqueezy → Key Delivery (BUILT, NOT WIRED)

> Status: **dark.** The code is complete and compatibility-tested, but nothing is
> deployed, no LemonSqueezy product exists, and the worker refuses all traffic until a
> signing secret is configured. Safe to ignore while testing the product.

## What's here

| File | Purpose |
|------|---------|
| `keygen.mjs` | JS port of `internal/license` key math — **byte-exact** with the Go CLI |
| `lemonsqueezy-webhook.js` | Cloudflare Worker: verify HMAC → generate key → store in KV (idempotent per order) |
| `test-keygen.mjs` | Compatibility tests (`node commerce/test-keygen.mjs`) — 5 Go-generated vectors pin the two implementations; cross-validated both directions (JS key → Go `license.Validate` accepts) |

**Compatibility contract:** if you touch `keygen.mjs` *or* `internal/license/license.go`,
run `node commerce/test-keygen.mjs` — drift between them makes sold keys invalid.

## Activation runbook (when ready to charge — ~30 min)

1. **LemonSqueezy:** create a store + a "MacBridge Studio" subscription product ($19/mo,
   per `PRICING_STRATEGY.md`). LemonSqueezy is the merchant of record (handles VAT/tax).
2. **Webhook:** in LemonSqueezy → Settings → Webhooks, add
   `https://<worker-domain>/webhook/lemonsqueezy` for `order_created` +
   `subscription_created`, and set a signing secret.
3. **Deploy the worker:**
   ```bash
   npx wrangler kv:namespace create MACBRIDGE_COMMERCE
   # add the binding + a [env] block for this worker (separate from macbridge-health)
   npx wrangler secret put LEMONSQUEEZY_SIGNING_SECRET
   npx wrangler deploy commerce/lemonsqueezy-webhook.js
   ```
4. **Test with LemonSqueezy test mode:** a test purchase should create `order:*` and
   `license:*` records in KV. Activate the minted key with `macbridge activate` to prove
   the chain end-to-end.
5. **Wire delivery** (the only TODO in code): send the key to the customer email —
   simplest is [Resend](https://resend.com) from the worker; alternative is pushing the
   key into LemonSqueezy's license-key field via their API so it appears in their
   receipt/portal. Flip `delivered: true` in the record.
6. Update the site's pricing CTA from "Request beta access" to the LemonSqueezy checkout
   link.

## Design notes

- **Idempotent per order** — LemonSqueezy retries webhooks; one order never mints two keys.
- **Dark guard** — without `LEMONSQUEEZY_SIGNING_SECRET` the worker 503s everything, so an
  accidental deploy is inert.
- **No admin UI on purpose** — LemonSqueezy's merchant dashboard covers customers,
  payments, refunds, subscriptions. KV holds only the key↔order mapping.
