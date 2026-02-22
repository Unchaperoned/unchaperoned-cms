# Ghost 5 with custom Cloudflare R2 storage adapter + persistent Casper theme
# Key fix: adapter AND Casper theme stored at /opt (outside /var/lib/ghost/content volume)
# and copied into content/ at container startup via entrypoint script
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

# ── Casper Theme ─────────────────────────────────────────────────────────────
# Casper lives at /var/lib/ghost/versions/<version>/content/themes/casper
# Cloud Run wipes /var/lib/ghost/content on every container restart, but the
# versioned directory is safe. We copy Casper to /opt so the entrypoint can
# restore it to content/themes/ on each startup.
RUN CASPER_PATH=$(find /var/lib/ghost/versions -maxdepth 4 -name "casper" -type d 2>/dev/null | head -1) && \
    echo "Found Casper at: $CASPER_PATH" && \
    mkdir -p /opt/ghost-themes && \
    cp -r "$CASPER_PATH" /opt/ghost-themes/casper && \
    chown -R node:node /opt/ghost-themes && \
    echo "Casper staged at /opt/ghost-themes/casper" && \
    ls /opt/ghost-themes/casper | head -10

# ── Entrypoint ───────────────────────────────────────────────────────────────
COPY docker-entrypoint.sh /usr/local/bin/ghost-r2-entrypoint.sh
RUN chmod +x /usr/local/bin/ghost-r2-entrypoint.sh

USER node
ENTRYPOINT ["/usr/local/bin/ghost-r2-entrypoint.sh"]
CMD ["node", "current/index.js"]
