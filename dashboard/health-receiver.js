/**
 * MacBridge — Health Report Receiver
 * Cloudflare Worker that receives healthd.sh JSON reports from fleet Macs.
 *
 * Deploy:
 *   npx wrangler deploy
 *
 * Endpoints:
 *   POST /api/report  — Receive health check JSON from a Mac
 *   GET  /api/status  — Dashboard: show all Macs and their health status
 *   GET  /api/status/:id — Show single Mac status
 *
 * Storage: Cloudflare KV (free tier: 1GB, 10M reads/day)
 *   npx wrangler kv:namespace create MACBRIDGE_FLEET
 *   npx wrangler kv:namespace create MACBRIDGE_FLEET --preview
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS for dashboard access
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
      });
    }

    const corsHeaders = { 'Access-Control-Allow-Origin': '*' };

    // ── POST /api/report — Receive health report ──────────────────────────

    if (url.pathname === '/api/report' && request.method === 'POST') {
      try {
        const data = await request.json();
        const machineId = data.machine_id || 'unknown';
        const key = `mac:${machineId}`;

        // Store latest report in KV
        await env.MACBRIDGE_FLEET.put(key, JSON.stringify(data));
        // Store timestamp for "last seen" tracking
        await env.MACBRIDGE_FLEET.put(`${key}:last_seen`, new Date().toISOString());
        // Keep a list of all known machine IDs
        const fleet = await env.MACBRIDGE_FLEET.get('fleet:all', 'json') || [];
        if (!fleet.includes(machineId)) {
          fleet.push(machineId);
          await env.MACBRIDGE_FLEET.put('fleet:all', JSON.stringify(fleet));
        }

        return new Response(JSON.stringify({ received: true, machine_id: machineId }), {
          status: 200,
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      } catch (e) {
        return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }
    }

    // ── GET /api/status — Fleet dashboard ─────────────────────────────────

    if (url.pathname === '/api/status' && request.method === 'GET') {
      const fleet = await env.MACBRIDGE_FLEET.get('fleet:all', 'json') || [];
      const machines = [];

      for (const id of fleet) {
        const data = await env.MACBRIDGE_FLEET.get(`mac:${id}`, 'json');
        const lastSeen = await env.MACBRIDGE_FLEET.get(`mac:${id}:last_seen`);
        if (data) {
          machines.push({
            machine_id: id,
            hostname: data.hostname,
            overall: data.overall,
            failed_count: data.failed_count,
            last_seen: lastSeen,
            timestamp: data.timestamp,
          });
        }
      }

      // Sort: unhealthy first, then by last seen
      machines.sort((a, b) => {
        if (a.overall !== b.overall) return a.overall === 'degraded' ? -1 : 1;
        return (b.last_seen || '').localeCompare(a.last_seen || '');
      });

      const html = renderDashboard(machines);
      return new Response(html, {
        headers: { 'Content-Type': 'text/html; charset=utf-8', ...corsHeaders },
      });
    }

    // ── GET /api/status/:id — Single Mac detail ───────────────────────────

    const statusMatch = url.pathname.match(/^\/api\/status\/(.+)$/);
    if (statusMatch && request.method === 'GET') {
      const machineId = statusMatch[1];
      const data = await env.MACBRIDGE_FLEET.get(`mac:${machineId}`, 'json');
      const lastSeen = await env.MACBRIDGE_FLEET.get(`mac:${machineId}:last_seen`);

      if (!data) {
        return new Response(JSON.stringify({ error: 'Machine not found' }), {
          status: 404,
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }

      return new Response(JSON.stringify({ ...data, last_seen: lastSeen }, null, 2), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // ── 404 ──────────────────────────────────────────────────────────────

    return new Response('MacBridge Health Receiver — POST /api/report | GET /api/status', {
      status: 404,
      headers: corsHeaders,
    });
  },
};

// ── Minimal dashboard HTML ─────────────────────────────────────────────────

function renderDashboard(machines) {
  const healthy = machines.filter(m => m.overall === 'healthy').length;
  const degraded = machines.filter(m => m.overall !== 'healthy').length;

  const rows = machines.map(m => {
    const statusColor = m.overall === 'healthy' ? '#4fd89d' : '#ef7b7b';
    const statusIcon = m.overall === 'healthy' ? '🟢' : '🔴';
    const lastSeen = m.last_seen ? new Date(m.last_seen).toLocaleString() : 'unknown';
    return `<tr>
      <td>${statusIcon}</td>
      <td><strong>${m.hostname || m.machine_id}</strong></td>
      <td><span style="color:${statusColor}">${m.overall}</span></td>
      <td>${m.failed_count} failed</td>
      <td style="color:#72889b;font-size:0.8rem">${lastSeen}</td>
    </tr>`;
  }).join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MacBridge Fleet</title>
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#081017;color:#edf4f7;font-family:system-ui,sans-serif;padding:32px}
  h1{font-size:1.5rem;margin-bottom:8px}
  .summary{display:flex;gap:24px;margin-bottom:24px}
  .stat{background:#0f1923;border:1px solid rgba(133,209,244,0.18);border-radius:8px;padding:16px 24px}
  .stat .value{font-size:2rem;font-weight:700}
  .stat .label{font-size:0.8rem;color:#72889b}
  .stat .value.green{color:#4fd89d}
  .stat .value.red{color:#ef7b7b}
  table{width:100%;border-collapse:collapse}
  th,td{padding:10px 14px;text-align:left;border-bottom:1px solid rgba(133,209,244,0.08)}
  th{color:#72889b;font-size:0.75rem;text-transform:uppercase;letter-spacing:0.08em}
  td{font-size:0.9rem}
  .empty{text-align:center;padding:48px;color:#72889b}
  .footer{margin-top:24px;color:#72889b;font-size:0.75rem}
</style>
</head>
<body>
<h1>MacBridge Fleet</h1>
<div class="summary">
  <div class="stat"><div class="value green">${healthy}</div><div class="label">Healthy</div></div>
  <div class="stat"><div class="value red">${degraded}</div><div class="label">Degraded</div></div>
  <div class="stat"><div class="value" style="color:#75cfff">${machines.length}</div><div class="label">Total</div></div>
</div>
${machines.length > 0 ? `<table><thead><tr><th></th><th>Machine</th><th>Status</th><th>Checks</th><th>Last Seen</th></tr></thead><tbody>${rows}</tbody></table>` : '<div class="empty">No machines reporting yet. Run healthd.sh --webhook on each Mac.</div>'}
<div class="footer">MacBridge Health Receiver · Refresh for updates · Machines report every 5 min</div>
</body>
</html>`;
}
