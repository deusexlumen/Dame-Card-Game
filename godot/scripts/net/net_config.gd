extends RefCounted

# Oeffentliche Netz-Einstellungen (keine Geheimnisse: alles hier landet im Spiel).

# Supabase-Funktion fuer TURN-Zugangsdaten, z. B.
# "https://<projekt>.supabase.co/functions/v1/turn-credentials". Leer = nur STUN.
const TURN_URL := "https://biunpatbnpbvwprfltni.supabase.co/functions/v1/turn-credentials"

# Signaling fuer Raumcodes: Supabase Realtime (Broadcast, nur Verbindungsdaten).
# Der anon-Schluessel ist oeffentlich gedacht (steckt auch in jedem Browser-Client).
const SIGNALING_URL := "wss://biunpatbnpbvwprfltni.supabase.co/realtime/v1/websocket"
const SIGNALING_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpdW5wYXRibnBidndwcmZsdG5pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5Mjg1ODIsImV4cCI6MjA4OTUwNDU4Mn0._mXhE8S0WHtGX8cd1QYpLk3Is7jsial-WjvcP6xqrlk"
