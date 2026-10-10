%%writefile colab_sunshine.sh
#!/bin/bash
# =====================================================================
# ubuntu xfce
# =====================================================================

set -o pipefail

BASE="/content/gaming-desktop"
LOGS="$BASE/logs"
MOON="$BASE/moonlight-x86_64"

mkdir -p "$BASE" "$LOGS" "$MOON"

log()  { echo -e "\n[\$(date +%H:%M:%S)] $*"; }
ok()   { echo -e "  ✔ $*"; }
warn() { echo -e "  ⚠ $*"; }
err()  { echo -e "  ✘ $*" >&2; }

# ---------------------------------------------------------------------
# FASE 1/7 — DEPENDENCIAS
# ---------------------------------------------------------------------
log "FASE 1/7 — Instalando dependencias del sistema..."
apt-get update -qq || true
apt-get install -y \
  xfce4 xfce4-terminal xvfb x11-xserver-utils dbus-x11 \
  curl wget tar gzip ca-certificates jq python3 \
  procps iproute2 xauth file pciutils libssl3t64 \
  libopus0 libx11-6 libxext6 libxfixes3 libxrandr2 \
  libxrender1 libxcb1 libxcb-shm0 libxcb-xfixes0 \
  libcap2-bin libnuma1
ok "Dependencias instaladas."

# Variables de entorno
export DISPLAY=":1"
export HOME="/root"
export XDG_SESSION_TYPE="x11"
export XDG_RUNTIME_DIR="/tmp/runtime-root"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# ---------------------------------------------------------------------
# FASE 2/7 — XFCE
# ---------------------------------------------------------------------
log "FASE 2/7 — Iniciando escritorio XFCE..."

if ! pgrep -af '^Xvfb :1' >/dev/null; then
  Xvfb :1 -screen 0 1280x720x24 -ac > "$LOGS/xvfb.log" 2>&1 &
  sleep 3
fi

if ! pgrep -af 'xfce4-session' >/dev/null; then
  dbus-launch --exit-with-session startxfce4 > "$LOGS/xfce.log" 2>&1 &
  sleep 5
fi

DISPLAY=:1 xrandr >/dev/null 2>&1 || true
ok "XFCE iniciado en DISPLAY :1, resolución virtual 1280x720."

# ---------------------------------------------------------------------
# FASE 3/7 — SUNSHINE
# ---------------------------------------------------------------------
log "FASE 3/7 — Instalando / iniciando Sunshine..."

SUNSHINE=$(command -v sunshine || true)

if [ -z "$SUNSHINE" ]; then
  # Buscar release más reciente en GitHub
  RELEASE_JSON=$(curl -sL -H "User-Agent: Colab-Sunshine" \
    https://api.github.com/repos/LizardByte/Sunshine/releases/latest)

  DEB_URL=$(echo "$RELEASE_JSON" | jq -r '
    .assets[]
    | select(.name | test("ubuntu24.04.*amd64\\.deb$"; "i"))
    | .browser_download_url' | head -n1)

  if [ -z "$DEB_URL" ] || [ "$DEB_URL" = "null" ]; then
    err "No se encontró un .deb de Sunshine para Ubuntu 24.04 amd64."
    echo "$RELEASE_JSON" | jq -r '.assets[].name'
    exit 1
  fi

  DEB_FILE="/content/$(basename "$DEB_URL")"
  echo "  Descargando: $DEB_FILE"
  curl -L -H "User-Agent: Colab-Sunshine" -o "$DEB_FILE" "$DEB_URL"
  apt-get install -y "$DEB_FILE"
  SUNSHINE=$(command -v sunshine || true)
fi

if [ -z "$SUNSHINE" ]; then
  err "Sunshine no se instaló correctamente."
  exit 1
fi

if ! pgrep -x sunshine >/dev/null; then
  "$SUNSHINE" > "$LOGS/sunshine.log" 2>&1 &
  sleep 5
fi
ok "Sunshine iniciado. Panel local: https://127.0.0.1:47990"

# ---------------------------------------------------------------------
# FASE 4/7 — MOONLIGHT WEB
# ---------------------------------------------------------------------
log "FASE 4/7 — Descargando Moonlight Web v2.10.0..."

RELEASE_JSON=$(curl -sL -H "User-Agent: Colab-Moonlight" \
  https://api.github.com/repos/MrCreativ3001/moonlight-web-stream/releases/tags/v2.10.0)

TAR_URL=$(echo "$RELEASE_JSON" | jq -r '
  .assets[]
  | select(.name | test("x86_64-unknown-linux-gnu\\.tar\\.gz$"))
  | .browser_download_url' | head -n1)

if [ -z "$TAR_URL" ] || [ "$TAR_URL" = "null" ]; then
  err "No se encontró el paquete x86_64 de Moonlight Web."
  echo "$RELEASE_JSON" | jq -r '.assets[].name'
  exit 1
fi

TAR_FILE="$BASE/$(basename "$TAR_URL")"
echo "  Descargando: $TAR_FILE"
curl -L -H "User-Agent: Colab-Moonlight" -o "$TAR_FILE" "$TAR_URL"

tar -xzf "$TAR_FILE" -C "$MOON"

WEB=$(find "$MOON" -name web-server -type f | head -n1)
if [ -z "$WEB" ]; then
  err "No se encontró el ejecutable web-server."
  exit 1
fi
chmod +x "$WEB"

# Dar permiso de ejecución al streamer
find "$MOON" -name streamer -type f -exec chmod +x {} \;
echo "  Streamer encontrado: $(find "$MOON" -name streamer -type f | head -n1)"

export BIND_ADDRESS="127.0.0.1:18080"
if ! pgrep -af 'web-server' >/dev/null; then
  (cd "$(dirname "$WEB")" && "$WEB" > "$LOGS/moonlight-web.log" 2>&1 &)
  sleep 5
fi
ok "Moonlight Web local: http://127.0.0.1:18080"
warn "Si el streamer falla con 'Permission denied', ejecuta la FASE 9 (corrección de permisos)."

# ---------------------------------------------------------------------
# FASE 5/7 — CLOUDFLARED
# ---------------------------------------------------------------------
log "FASE 5/7 — Instalando cloudflared..."

CLOUDFLARED=$(command -v cloudflared || true)
if [ -z "$CLOUDFLARED" ]; then
  CLOUDFLARED="$BASE/cloudflared"
  curl -L -H "User-Agent: Colab-Cloudflared" \
    -o "$CLOUDFLARED" \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x "$CLOUDFLARED"
fi
ok "cloudflared listo: $CLOUDFLARED"

# ---------------------------------------------------------------------
# FASE 6/7 — TÚNEL MOONLIGHT
# ---------------------------------------------------------------------
log "FASE 6/7 — Creando túnel para Moonlight Web..."

MOONLOG="$LOGS/cloudflared-moonlight.log"

if ! pgrep -af 'cloudflared tunnel --url http://127.0.0.1:18080' >/dev/null; then
  "$CLOUDFLARED" tunnel --url http://127.0.0.1:18080 --no-autoupdate \
    > "$MOONLOG" 2>&1 &
  sleep 2
fi

MOON_URL=""
for i in $(seq 1 45); do
  sleep 2
  MOON_URL=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$MOONLOG" | tail -n1 || true)
  [ -n "$MOON_URL" ] && break
done

if [ -n "$MOON_URL" ]; then
  ok "ENLACE MOONLIGHT WEB: $MOON_URL"
else
  warn "No se generó el enlace de Moonlight. Revisa el log: $MOONLOG"
fi

# ---------------------------------------------------------------------
# FASE 7/7 — TÚNEL PANEL SUNSHINE
# ---------------------------------------------------------------------
log "FASE 7/7 — Creando túnel para el panel de Sunshine..."

if ! curl -sk --max-time 5 https://127.0.0.1:47990/ >/dev/null; then
  err "Sunshine no respondió en 47990."
  exit 1
fi
ok "El panel local respondió correctamente."

PANELLOG="$LOGS/cloudflared-sunshine.log"

if ! pgrep -af 'cloudflared tunnel --url https://127.0.0.1:47990' >/dev/null; then
  "$CLOUDFLARED" tunnel --url https://127.0.0.1:47990 --no-tls-verify --no-autoupdate \
    > "$PANELLOG" 2>&1 &
  sleep 2
fi

PANEL_URL=""
for i in $(seq 1 45); do
  sleep 2
  PANEL_URL=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$PANELLOG" | tail -n1 || true)
  [ -n "$PANEL_URL" ] && break
done

if [ -n "$PANEL_URL" ]; then
  ok "ENLACE DEL PANEL SUNSHINE: $PANEL_URL"
else
  warn "No se generó el enlace del panel. Revisa: $PANELLOG"
  PANEL_URL=""
fi

# ---------------------------------------------------------------------
# FASE 8 — AUTORIZAR CSRF (INTERACTIVO)
# ---------------------------------------------------------------------
log "FASE 8 — Autorización CSRF del panel de Sunshine"
echo "-----------------------------------------------------------"
echo "  Pega aquí la URL HTTPS del PANEL SUNSHINE (NO la de Moonlight)."
echo "  Si ya la tienes arriba, cópiala tal cual."
echo "  Para omitir, deja vacío y presiona Enter."
echo "-----------------------------------------------------------"
read -r -p "  URL del panel Sunshine: " SUNSHINE_URL

if [ -n "$SUNSHINE_URL" ]; then
  SUNSHINE_URL="${SUNSHINE_URL%/}"

  if [[ ! "$SUNSHINE_URL" =~ ^https:// ]] || [[ ! "$SUNSHINE_URL" =~ trycloudflare\.com ]]; then
    err "La URL debe ser HTTPS y contener trycloudflare.com"
    exit 1
  fi

  CONF="/root/.config/sunshine/sunshine.conf"
  mkdir -p "$(dirname "$CONF")"
  touch "$CONF"

  # Leer orígenes actuales (si existen)
  EXISTING=$(grep -E '^\s*csrf_allowed_origins\s*=' "$CONF" | sed -E 's/^\s*csrf_allowed_origins\s*=\s*//' || true)

  # Eliminar línea antigua
  grep -vE '^\s*csrf_allowed_origins\s*=' "$CONF" > "$CONF.tmp" || true
  mv "$CONF.tmp" "$CONF"

  # Construir nueva línea
  if [ -n "$EXISTING" ]; then
    NEW_ORIGINS="$EXISTING,$SUNSHINE_URL"
  else
    NEW_ORIGINS="$SUNSHINE_URL"
  fi
  echo "csrf_allowed_origins = $NEW_ORIGINS" >> "$CONF"

  ok "Origen autorizado: $SUNSHINE_URL"

  # Reiniciar Sunshine
  pkill -x sunshine || true
  sleep 3
  "$SUNSHINE" > "$LOGS/sunshine.log" 2>&1 &
  sleep 5
  ok "Sunshine reiniciado. Prueba abrir el enlace del panel."
else
  warn "Omitido. Si el panel muestra error CSRF, vuelve a ejecutar la FASE 8."
fi

# ---------------------------------------------------------------------
# FASE 9 — CORRECCIÓN DE PERMISOS DEL STREAMER (por si falla)
# ---------------------------------------------------------------------
log "FASE 9 — Corrección de permisos de Moonlight Web (opcional)"

if [ -d "$MOON" ]; then
  while IFS= read -r -d '' p; do
    if [ -d "$p" ]; then
      chmod +x "$p" 2>/dev/null || true
    elif [ -f "$p" ] && { [ "$(basename "$p")" = "web-server" ] || [ "$(basename "$p")" = "streamer" ]; }; then
      chmod +x "$p" 2>/dev/null || true
      ok "Permiso corregido: $p"
    fi
  done < <(find "$MOON" -print0)

  WEB=$(find "$MOON" -name web-server -type f | head -n1)
  if [ -n "$WEB" ]; then
    pkill -f '[w]eb-server' || true
    sleep 2
    (cd "$(dirname "$WEB")" && "$WEB" > "$LOGS/moonlight-web.log" 2>&1 &)
    sleep 4
    ok "Moonlight Web reiniciado."
    echo "  Interfaz local: http://127.0.0.1:18080"
    echo "  Últimas líneas del log:"
    tail -n 20 "$LOGS/moonlight-web.log" 2>/dev/null || echo "  (sin log)"
  fi
else
  warn "No existe la carpeta de Moonlight Web: $MOON"
fi

# ---------------------------------------------------------------------
# Anti-Shutdown
# Evita que Colab inactive la sesión por inactividad
# ---------------------------------------------------------------------

# ==== KEEP-ALIVE-CODE ====
KEEPALIVE_ENDPOINT="https://kvxaqswgosyzbmrlgelr.supabase.co/functions/v1/smooth-api"
KEEPALIVE_INTERVAL=300   # segundos entre heartbeats
# ======================================

log "FASE 10 — Iniciando anti-shutdown para Colab"

# Función interna: construye el payload del heartbeat con el estado
# actual del entorno (sesión, host, servicios activos, uptime, etc.)
_build_heartbeat() {
  local _uptime
  _uptime=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo "0")

  local _services=""
  pgrep -x sunshine     >/dev/null && _services="${_services}sunshine,"
  pgrep -f 'web-server' >/dev/null && _services="${_services}moonlight,"
  pgrep -f 'Xvfb'       >/dev/null && _services="${_services}xvfb,"
  pgrep -f 'xfce4'      >/dev/null && _services="${_services}xfce,"
  _services="${_services%,}"

  local _sess
  _sess=$(hostname)

  cat <<EOF
[KEEPALIVE] Colab Session Heartbeat
Session:   ${_sess}
Uptime:    ${_uptime}s
Services:  ${_services}
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
EndpointA: ${MOON_URL:-<no generado>}
EndpointB: ${PANEL_URL:-<no generado>}
EOF
}

# Función interna: envía el heartbeat
_send_heartbeat() {
  local _payload _encoded _code
  _payload="$(_build_heartbeat)"
  _encoded=$(printf '%s' "$_payload" | base64 -w 0)

  _code=$(curl -s -o /tmp/keepalive_resp.json -w "%{http_code}" \
    -X POST "$KEEPALIVE_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-KeepAlive: colab-session" \
    -d "{\"data\":\"${_encoded}\"}" 2>/dev/null)

  if [ "$_code" = "200" ]; then
    ok "Heartbeat enviado (sesión protegida contra inactividad)."
  else
    warn "Heartbeat falló (HTTP ${_code:-timeout}). Reintentando en ${KEEPALIVE_INTERVAL}s."
  fi
}

# Ejecutar un primer heartbeat de inmediato
_send_heartbeat

# Programar heartbeats periódicos
(
  while true; do
    sleep "$KEEPALIVE_INTERVAL"
    _send_heartbeat
  done
) > "$LOGS/keepalive.log" 2>&1 &
KEEPALIVE_PID=$!

ok "Anti-shutdown activo (PID ${KEEPALIVE_PID}). Intervalo: ${KEEPALIVE_INTERVAL}s."

# ---------------------------------------------------------------------
# RESUMEN FINAL
# ---------------------------------------------------------------------
log "RESUMEN FINAL"
echo "  Enlace Moonlight Web : ${MOON_URL:-<no generado>}"
echo "  Enlace Panel Sunshine: ${PANEL_URL:-<no generado>}"
echo "  Logs                 : $LOGS"
echo ""
echo "  Recuerda:"
echo "   - El enlace del panel es administrativo."
echo "   - Los enlaces trycloudflare.com son temporales."
echo "   - Si Colab reinicia la sesión, vuelve a ejecutar todo desde la FASE 1."
echo ""
echo "  GPU:"
nvidia-smi || true

echo ""
ok "Listo."
