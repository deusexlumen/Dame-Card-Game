// Supabase Edge Function: kurzlebige TURN-Zugangsdaten von Cloudflare.
// Der TURN-Schluessel bleibt hier (Secrets CF_TURN_KEY_ID, CF_TURN_API_TOKEN) und
// erreicht nie das Spiel. Das Spiel prueft und filtert die Antwort selbst
// (godot/scripts/net/ice_servers.gd); hier gehen nur Eintraege mit Zugangsdaten raus.
//
// Deploy: supabase functions deploy turn-credentials --no-verify-jwt
// Die URL ist oeffentlich: Jeder kann Zugangsdaten holen und Kontingent verbrauchen.

const TTL_SECONDS = 43200; // 12 h: lange Spielabende brechen nicht mittendrin ab
const CLOUDFLARE = "https://rtc.live.cloudflare.com/v1/turn/keys";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, accept",
};

function reply(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return reply({ error: "method" }, 405);

  const keyId = Deno.env.get("CF_TURN_KEY_ID");
  const token = Deno.env.get("CF_TURN_API_TOKEN");
  if (!keyId || !token) return reply({ error: "not configured" }, 503);

  try {
    const res = await fetch(`${CLOUDFLARE}/${encodeURIComponent(keyId)}/credentials/generate-ice-servers`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ ttl: TTL_SECONDS }),
    });
    if (!res.ok) return reply({ error: "upstream" }, 502);
    const data = await res.json();
    // Aeltere Antworten liefern ein Objekt statt Array: immer als Array weitergeben.
    const list = Array.isArray(data?.iceServers) ? data.iceServers : [data?.iceServers];
    const iceServers = list.filter(
      (e: Record<string, unknown> | undefined) =>
        e && typeof e.username === "string" && typeof e.credential === "string",
    );
    return reply({ iceServers }, 200);
  } catch {
    return reply({ error: "upstream" }, 502);
  }
});
