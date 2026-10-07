extends RefCounted

# Oeffentliche Netz-Einstellungen (keine Geheimnisse: alles hier landet im Spiel).

# Supabase-Funktion fuer TURN-Zugangsdaten, z. B.
# "https://<projekt>.supabase.co/functions/v1/turn-credentials". Leer = nur STUN.
const TURN_URL := "https://biunpatbnpbvwprfltni.supabase.co/functions/v1/turn-credentials"
