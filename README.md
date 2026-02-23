# Unchaperoned CMS — Ghost on Cloud Run

**CMS admin:** [cms.unchaperonedlife.com/ghost](https://cms.unchaperonedlife.com/ghost)  
**Cloud Run service:** `ghost-cms` (us-west1)  
**Artifact Registry:** `us-west1-docker.pkg.dev/unchaperoned/ghost-cms/ghost-cms-r2`  
**Repository:** [github.com/Unchaperoned/unchaperoned-cms](https://github.com/Unchaperoned/unchaperoned-cms)

---

## Overview

This repository contains the Docker image definition and CI/CD pipeline for the Unchaperoned Life headless Ghost CMS instance. Ghost serves as the content management backend for the entire [web.unchaperonedlife.com](https://web.unchaperonedlife.com) site — all blog posts, podcast episodes, page copy, program cards, FAQs, and CTAs are authored here and consumed by the React frontend via the Ghost Content API.

The image extends the official `ghost:5` base image with two additions: a custom Cloudflare R2 storage adapter (so uploaded media goes to R2 instead of the container filesystem) and a startup entrypoint that restores the adapter and all built-in themes on every container boot (necessary because Cloud Run wipes the `/var/lib/ghost/content` volume on each restart).

---

## Repository Structure

```
unchaperoned-cms/
├── Dockerfile                  # Multi-layer Ghost image with R2 adapter + themes
├── docker-entrypoint.sh        # Startup script: restores adapter + themes, then starts Ghost
├── cloudbuild.yaml             # Cloud Build pipeline: build → push → deploy to Cloud Run
└── r2-adapter/
    ├── index.js                # Custom Ghost storage adapter for Cloudflare R2
    └── package.json            # Adapter dependencies (@aws-sdk/client-s3)
```

---

## Architecture

### Infrastructure

| Component | Service | Details |
|---|---|---|
| Ghost CMS | Google Cloud Run | `ghost-cms` service, `us-west1`, port 2368 |
| Database | Google Cloud SQL | MySQL 8.0, `ghost-cms-mysql` instance, `us-west1` |
| Media Storage | Cloudflare R2 | Bucket: `unchaperoned-life-assets` |
| CDN / Asset Host | Cloudflare | `https://assets.unchaperonedlife.com` |
| Custom Domain | Cloudflare DNS | `cms.unchaperonedlife.com` → Cloud Run |
| Container Registry | Artifact Registry | `us-west1-docker.pkg.dev/unchaperoned/ghost-cms` |
| CI/CD | Google Cloud Build | Triggered on push to `main` |
| Email (member notifications) | Brevo SMTP | `smtp-relay.brevo.com`, port 587 |

### Why the Custom Entrypoint?

Cloud Run is a stateless container platform — every time the container restarts (on deploy, scale-out, or cold start), the `/var/lib/ghost/content` directory is reset to a fresh empty volume. Ghost requires its storage adapter and themes to live inside that directory at runtime. The `docker-entrypoint.sh` script solves this by:

1. Copying the R2 adapter from `/opt/ghost-r2-adapter` → `/var/lib/ghost/content/adapters/storage/r2`
2. Copying all built-in themes (Casper, Source) from `/opt/ghost-themes` → `/var/lib/ghost/content/themes`
3. Then executing the Ghost startup command (`node current/index.js`)

Both `/opt` directories are populated at image build time via the `Dockerfile`, so they survive container restarts.

### R2 Storage Adapter

The custom adapter (`r2-adapter/index.js`) extends Ghost's `ghost-storage-base` class and implements the required interface using the AWS SDK v3 S3 client pointed at the Cloudflare R2 S3-compatible endpoint. Key behaviors:

- Files are uploaded to R2 with a `YYYY/MM/filename-{random}.ext` key structure (no path prefix — files go to the bucket root)
- Public URLs are constructed as `https://assets.unchaperonedlife.com/{key}`
- The adapter loads `ghost-storage-base` from Ghost's own `node_modules` to avoid class instance mismatch errors
- The `read()` method is intentionally unsupported — all files are served via the Cloudflare CDN

---

## CI/CD Pipeline

Pushing any commit to the `main` branch automatically triggers Cloud Build (`cloudbuild.yaml`):

1. **Build** — Docker image built and tagged with `$COMMIT_SHA` and `latest`
2. **Push** — Both tags pushed to Artifact Registry
3. **Deploy** — Cloud Run updated to the new `$COMMIT_SHA` image with zero-downtime rollout

The Cloud Run service is configured with `--allow-unauthenticated` (Ghost handles its own auth) and `--port=2368`.

---

## Environment Variables (Cloud Run)

All secrets are set directly on the Cloud Run service via the GCP Console or `gcloud` CLI. They are **never** stored in this repository.

| Variable | Purpose |
|---|---|
| `storage__active` | Set to `r2` to activate the R2 storage adapter |
| `storage__r2__accessKeyId` | Cloudflare R2 Access Key ID |
| `storage__r2__secretAccessKey` | Cloudflare R2 Secret Access Key |
| `storage__r2__bucket` | R2 bucket name (`unchaperoned-life-assets`) |
| `storage__r2__endpoint` | R2 S3-compatible endpoint URL |
| `storage__r2__assetHost` | Public CDN URL (`https://assets.unchaperonedlife.com`) |
| `database__client` | `mysql` |
| `database__connection__host` | Cloud SQL Unix socket path |
| `database__connection__user` | MySQL username |
| `database__connection__password` | MySQL password |
| `database__connection__database` | Database name (`ghost`) |
| `url` | `https://cms.unchaperonedlife.com` |
| `mail__transport` | `SMTP` |
| `mail__options__host` | `smtp-relay.brevo.com` |
| `mail__options__port` | `587` |
| `mail__options__auth__user` | Brevo SMTP username |
| `mail__options__auth__pass` | Brevo SMTP API key |
| `mail__from` | Sender address for Ghost emails |

---

## Current Features

**Ghost 5 headless CMS** serving all content for the Unchaperoned Life website via the Content API. Content types in use:

- **Posts (tagged `podcast`)** — Podcast episodes with structured Episode Metadata blocks (Episode number, Description, Host, Guest, Duration, Spotify/YouTube/Apple URLs)
- **Posts (tagged `blog`)** — Resource library articles with topic tags, authors, and feature images
- **Pages** — Editable copy blocks for Home, About, Programs, Resources, and Connect pages, parsed by `## Section Heading` markers in the React frontend
- **Tags** — Topic categorization for filtering on the Podcast and Resources pages; Ghost native `featured` flag controls featured sections
- **Authors** — Bylines for blog articles

**Cloudflare R2 media storage** — All images uploaded via Ghost admin are stored in R2 and served via the `assets.unchaperonedlife.com` CDN. Files are organized by upload date (`YYYY/MM/`) with random suffixes to prevent enumeration. No path prefix is used — files upload directly to the bucket root.

**Brevo SMTP email** — Ghost member notification emails (password reset, magic link login) are delivered via Brevo's transactional SMTP relay.

---

## Content Management Guide

### Podcast Episodes

Each episode post must be tagged `podcast` and include a structured `## Episode Metadata` section at the top of the post body:

```
## Episode Metadata

Episode: 01
Description: A one-to-two sentence episode summary shown on the detail page.
Host: Host Name
Guest: Guest Name (leave blank if none)
Duration: 45 minutes
Spotify: https://open.spotify.com/episode/...
YouTube: https://www.youtube.com/watch?v=...
Apple: https://podcasts.apple.com/...
```

Leave platform URL fields blank if the episode is not yet published to that platform. The React frontend only shows platform buttons when a URL is present.

### Blog / Resource Articles

Tag each article with `blog` plus one or more topic tags (e.g., `attachment-healing`, `dating-skills`, `faith-dating`). The topic tag is shown on the article card and used for category filtering. Use the Ghost native star (featured) toggle to promote 2–3 articles to the featured section at the top of the Resources page.

### Page Copy

Home, About, Programs, Resources, and Connect page copy is stored in Ghost Pages. Each section is delimited by an `## H2 Heading` that the React component uses as a parser key. Do not change heading text without also updating the corresponding parser in the React codebase.

---

## Features on the To-Do List

| Feature | Notes |
|---|---|
| Ghost member authentication | Enable Ghost Members for gated Connection Collective content |
| Webhooks to GoHighLevel | Trigger GHL automations on new Ghost member signups |
| Newsletter integration | Connect Ghost newsletter to email list (Brevo or GHL) |
| Audit R2 legacy paths | Some early images may have been uploaded with a `ghost-media/` path prefix; verify all are accessible at the correct CDN URL |

---

## Changelog

### v3 — `7fbe351` · Feb 22, 2026

**All built-in Ghost themes preserved across restarts.** Ghost's `casper` and `source` themes are now staged at `/opt/ghost-themes` during the Docker build and restored by the entrypoint script on every container startup. This fixed a 500 error that occurred when the theme active in the Ghost database was not present in the content volume after a cold start.

### v2 — `5d27312` · Feb 22, 2026

**Initial Cloud Build deployment triggered.** A commit was pushed to `main` to trigger the first Cloud Build run and verify the full build → push → deploy pipeline end-to-end.

### v1 — `c6f5ba8` · Feb 22, 2026

**Initial commit.** Ghost 5 Docker image with custom Cloudflare R2 storage adapter, Cloud Build CI/CD pipeline (`cloudbuild.yaml`), and startup entrypoint script. R2 adapter implements the full Ghost storage interface using AWS SDK v3 against the Cloudflare R2 S3-compatible API. Files are served via `assets.unchaperonedlife.com`.

---

## Local Development

To run Ghost locally with SQLite (no MySQL required):

```bash
docker build -t ghost-cms-local .

docker run -p 2368:2368 \
  -e url=http://localhost:2368 \
  -e database__client=sqlite3 \
  ghost-cms-local
```

Ghost admin will be available at `http://localhost:2368/ghost`. Note that the R2 adapter requires valid credentials to function; without them Ghost will fall back to local filesystem storage.

---

## Deploying a Change

Any push to `main` triggers an automatic Cloud Build deployment. To deploy manually:

```bash
# Build and push
docker build -t us-west1-docker.pkg.dev/unchaperoned/ghost-cms/ghost-cms-r2:latest .
docker push us-west1-docker.pkg.dev/unchaperoned/ghost-cms/ghost-cms-r2:latest

# Deploy to Cloud Run
gcloud run deploy ghost-cms \
  --image us-west1-docker.pkg.dev/unchaperoned/ghost-cms/ghost-cms-r2:latest \
  --region us-west1 \
  --platform managed
```
