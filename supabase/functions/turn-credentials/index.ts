// Supabase Edge Function: TURN-Zugangsdaten fuer das Spiel.
// Zwei Quellen, beide nur als Secrets (nie im Repo, nie im Spiel-Code):
//   1. Feste Zugangsdaten (z. B. ExpressTURN, gratis ohne Karte):
//      TURN_URLS (kommagetrennt), TURN_USERNAME, TURN_CREDENTIAL
//   2. Cloudflare Realtime TURN (kurzlebig): CF_TURN_KEY_ID, CF_TURN_API_TOKEN
// Sind beide gesetzt, gewinnt Cloudflare. Das Spiel prueft und filtert die Antwort
// selbst (godot/scripts/net/ice_servers.gd); hier gehen nur Eintraege mit Zugangsdaten raus.
//
// Deploy: supabase functions deploy turn-credentials --no-verify-jwt
// Die URL ist oeffentlich: Jeder kann die Zugangsdaten abrufen.

const TTL_SECONDS = 43200; // Cloudflare: 12 h, lange Spielabende brechen nicht ab
const CLOUDFLARE = "https://rtc.live.cloudflare.com/v1/turn/keys";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, accept",
};

type IceServer = { urls: string[]; username: string; credential: string };

function reply(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function staticServers(): IceServer[] | null {
  const urls = (Deno.env.get("TURN_URLS") ?? "").split(",").map((u) => u.trim()).filter(Boolean);
  const username = Deno.env.get("TURN_USERNAME");
  const credential = Deno.env.get("TURN_CREDENTIAL");
  if (urls.length === 0 || !username || !credential) return null;
  return [{ urls, username, credential }];
}

async function cloudflareServers(keyId: string, token: string): Promise<IceServer[] | null> {
  const res = await fetch(`${CLOUDFLARE}/${encodeURIComponent(keyId)}/credentials/generate-ice-servers`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ ttl: TTL_SECONDS }),
  });
  if (!res.ok) return null;
  const data = await res.json();
  // Aeltere Antworten liefern ein Objekt statt Array: immer als Array weitergeben.
  const list = Array.isArray(data?.iceServers) ? data.iceServers : [data?.iceServers];
  return list.filter(
    (e: Record<string, unknown> | undefined) =>
      e && typeof e.username === "string" && typeof e.credential === "string",
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return reply({ error: "method" }, 405);

  const keyId = Deno.env.get("CF_TURN_KEY_ID");
  const token = Deno.env.get("CF_TURN_API_TOKEN");
  try {
    const iceServers = keyId && token ? await cloudflareServers(keyId, token) : staticServers();
    if (iceServers === null) return reply({ error: keyId && token ? "upstream" : "not configured" }, keyId && token ? 502 : 503);
    return reply({ iceServers }, 200);
  } catch {
    return reply({ error: "upstream" }, 502);
  }
});
