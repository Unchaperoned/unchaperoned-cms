# Ghost 5 with custom Cloudflare R2 storage adapter + all built-in themes persisted
# Key fix: adapter AND all themes stored at /opt (outside /var/lib/ghost/content volume)
# and copied into content/ at container startup via entrypoint script.
# This ensures whichever theme is active in the Ghost DB (casper, source, etc.) is available.
FROM ghost:5

USER root

# ── R2 Adapter ──────────────────────────────────────────────────────────────
COPY r2-adapter/ /tmp/r2-adapter/

RUN mkdir -p /opt/ghost-r2-adapter && \
    cd /tmp/r2-adapter && \
    npm install --production --no-audit --no-fund 2>&1 | tail -5 && \
    cp index.js /opt/ghost-r2-adapter/index.js && \
    cp -r node_modules /opt/ghost-r2-adapter/node_modules && \
    echo '{"name":"ghost-storage-r2","version":"1.0.0","main":"index.js"}' > \
         /opt/ghost-r2-adapter/package.json && \
    chown -R node:node /opt/ghost-r2-adapter && \
    rm -rf /tmp/r2-adapter && \
    echo "R2 adapter staged at /opt/ghost-r2-adapter"

# ── All Built-in Themes ───────────────────────────────────────────────────────
# Ghost ships with casper and source themes inside the versioned directory.
# Cloud Run wipes /var/lib/ghost/content on every container restart, but the
# versioned directory is safe. We copy ALL themes to /opt so the entrypoint
# can restore whichever theme is active in the database on each startup.
RUN THEMES_PATH=$(find /var/lib/ghost/versions -maxdepth 3 -name "themes" -type d 2>/dev/null | head -1) && \
    echo "Found themes directory at: $THEMES_PATH" && \
    mkdir -p /opt/ghost-themes && \
    cp -r "$THEMES_PATH/." /opt/ghost-themes/ && \
    chown -R node:node /opt/ghost-themes && \
    echo "All themes staged at /opt/ghost-themes:" && \
    ls /opt/ghost-themes

# ── Entrypoint ───────────────────────────────────────────────────────────────
COPY docker-entrypoint.sh /usr/local/bin/ghost-r2-entrypoint.sh
RUN chmod +x /usr/local/bin/ghost-r2-entrypoint.sh

USER node
ENTRYPOINT ["/usr/local/bin/ghost-r2-entrypoint.sh"]
CMD ["node", "current/index.js"]
