#!/bin/sh
# Ghost Entrypoint — R2 Adapter + Casper Theme
# Copies both the R2 storage adapter and the Casper theme from /opt into
# /var/lib/ghost/content/ at container startup, then starts Ghost.
# This is needed because Cloud Run wipes the content volume on every restart.
set -e

# ── R2 Storage Adapter ───────────────────────────────────────────────────────
ADAPTER_SRC="/opt/ghost-r2-adapter"
ADAPTER_DST="/var/lib/ghost/content/adapters/storage/r2"

if [ -d "$ADAPTER_SRC" ]; then
    echo "[entrypoint] Installing R2 storage adapter..."
    mkdir -p "$ADAPTER_DST"
    cp -r "$ADAPTER_SRC/." "$ADAPTER_DST/"
    echo "[entrypoint] R2 adapter installed at $ADAPTER_DST"
else
    echo "[entrypoint] WARNING: R2 adapter source not found at $ADAPTER_SRC"
fi

# ── Casper Theme ─────────────────────────────────────────────────────────────
THEME_SRC="/opt/ghost-themes/casper"
THEME_DST="/var/lib/ghost/content/themes/casper"

if [ -d "$THEME_SRC" ]; then
    echo "[entrypoint] Installing Casper theme..."
    mkdir -p "/var/lib/ghost/content/themes"
    cp -r "$THEME_SRC" "$THEME_DST"
    echo "[entrypoint] Casper theme installed at $THEME_DST"
else
    echo "[entrypoint] WARNING: Casper theme source not found at $THEME_SRC"
fi

# ── Start Ghost ───────────────────────────────────────────────────────────────
exec "$@"
