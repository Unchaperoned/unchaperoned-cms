#!/bin/sh
# Ghost Entrypoint — R2 Adapter + All Built-in Themes
# Copies both the R2 storage adapter and ALL built-in themes from /opt into
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

# ── All Built-in Themes ───────────────────────────────────────────────────────
# Restore all themes staged at /opt/ghost-themes (casper, source, etc.)
# so whichever theme is active in the Ghost database will be available.
THEMES_SRC="/opt/ghost-themes"
THEMES_DST="/var/lib/ghost/content/themes"

if [ -d "$THEMES_SRC" ]; then
    echo "[entrypoint] Installing all built-in themes..."
    mkdir -p "$THEMES_DST"
    cp -r "$THEMES_SRC/." "$THEMES_DST/"
    echo "[entrypoint] Themes installed at $THEMES_DST:"
    ls "$THEMES_DST"
else
    echo "[entrypoint] WARNING: Themes source not found at $THEMES_SRC"
fi

# ── Start Ghost ───────────────────────────────────────────────────────────────
exec "$@"
