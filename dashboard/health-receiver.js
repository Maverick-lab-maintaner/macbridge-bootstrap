export default {
  async fetch(request, env) {
    const url = new URL(request.url);

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

    if (url.pathname === '/api/report' && request.method === 'POST') {
      try {
        const data = await request.json();
        const machineId = data.machine_id || 'unknown';
        const key = `mac:${machineId}`;

        await env.MACBRIDGE_FLEET.put(key, JSON.stringify(data));
        await env.MACBRIDGE_FLEET.put(`${key}:last_seen`, new Date().toISOString());

        const fleet = await env.MACBRIDGE_FLEET.get('fleet:all', 'json') || [];
        if (!fleet.includes(machineId)) {
          fleet.push(machineId);
          await env.MACBRIDGE_FLEET.put('fleet:all', JSON.stringify(fleet));
        }

        return new Response(JSON.stringify({ received: true, machine_id: machineId }), {
          status: 200,
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      } catch {
        return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json', ...corsHeaders },
        });
      }
    }

    if (url.pathname === '/api/status' && request.method === 'GET') {
      const fleet = await env.MACBRIDGE_FLEET.get('fleet:all', 'json') || [];
      const machines = [];

      for (const id of fleet) {
        const data = await env.MACBRIDGE_FLEET.get(`mac:${id}`, 'json');
        const lastSeen = await env.MACBRIDGE_FLEET.get(`mac:${id}:last_seen`);
        if (data) {
          const state = data.summary?.state || data.status || data.overall || 'unknown';
          machines.push({
            machine_id: id,
            hostname: data.hostname,
            state,
            failed_count: data.failed_count || data.summary?.checks_failed || 0,
            warn_count: data.summary?.checks_warn || 0,
            last_seen: lastSeen,
            timestamp: data.timestamp,
          });
        }
      }

      const rank = { blocked: 0, degraded: 1, ready: 2 };
      machines.sort((a, b) => {
        if (a.state !== b.state) {
          return (rank[a.state] ?? 9) - (rank[b.state] ?? 9);
        }
        return (b.last_seen || '').localeCompare(a.last_seen || '');
      });

      return new Response(renderDashboard(machines), {
        headers: { 'Content-Type': 'text/html; charset=utf-8', ...corsHeaders },
      });
    }

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

    return new Response('MacBridge Health Receiver - POST /api/report | GET /api/status', {
      status: 404,
      headers: corsHeaders,
    });
  },
};

function renderDashboard(machines) {
  const ready = machines.filter(m => m.state === 'ready').length;
  const degraded = machines.filter(m => m.state === 'degraded').length;
  const blocked = machines.filter(m => m.state === 'blocked').length;

  const rows = machines.map(m => {
    const statusColor = m.state === 'ready' ? '#4fd89d' : m.state === 'degraded' ? '#f2bf66' : '#ef7b7b';
    const lastSeen = m.last_seen ? new Date(m.last_seen).toLocaleString() : 'unknown';
    return `<tr>
      <td><strong>${m.hostname || m.machine_id}</strong></td>
      <td><span style="color:${statusColor}">${m.state}</span></td>
      <td>${m.failed_count} failed / ${m.warn_count} warn</td>
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
  <div class="stat"><div class="value green">${ready}</div><div class="label">Ready</div></div>
  <div class="stat"><div class="value" style="color:#f2bf66">${degraded}</div><div class="label">Degraded</div></div>
  <div class="stat"><div class="value red">${blocked}</div><div class="label">Blocked</div></div>
  <div class="stat"><div class="value" style="color:#75cfff">${machines.length}</div><div class="label">Total</div></div>
</div>
${machines.length > 0 ? `<table><thead><tr><th>Machine</th><th>Status</th><th>Checks</th><th>Last Seen</th></tr></thead><tbody>${rows}</tbody></table>` : '<div class="empty">No machines reporting yet. Run healthd.sh --webhook on each Mac.</div>'}
<div class="footer">MacBridge Health Receiver | Refresh for updates | Machines report every 5 min</div>
</body>
</html>`;
}
