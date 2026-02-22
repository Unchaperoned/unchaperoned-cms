# Unchaperoned CMS

Ghost CMS Docker build for [cms.unchaperonedlife.com](https://cms.unchaperonedlife.com).

This repository contains the custom Ghost Docker image used to power the Unchaperoned Life content management system. It extends the official `ghost:5` image with:

- **Cloudflare R2 storage adapter** — all media uploads go to `assets.unchaperonedlife.com` via Cloudflare R2 instead of local disk
- **Casper theme persistence** — Ghost's default theme is baked into the image so it survives Cloud Run container restarts
- **Startup entrypoint** — copies the R2 adapter and Casper theme into the Ghost content directory on every container start

## Architecture

```
unchaperoned-cms/           ← This repo (Ghost infrastructure)
├── Dockerfile
├── docker-entrypoint.sh
├── r2-adapter/
│   ├── index.js
│   └── package.json
└── cloudbuild.yaml

unchaperoned-www/           ← Separate repo (React website)
```

The React website at `unchaperonedlife.com` fetches content from Ghost at runtime via the Ghost Content API. No deployment is needed on the website side when content is published in Ghost.

## Deployment

Pushing to `main` automatically triggers Cloud Build, which:
1. Builds the Docker image
2. Pushes it to `us-west1-docker.pkg.dev/unchaperoned/ghost-cms/ghost-cms-r2`
3. Deploys it to the `ghost-cms` Cloud Run service in `us-west1`

## Environment Variables (set in Cloud Run)

| Variable | Purpose |
|---|---|
| `storage__active` | Set to `r2` to activate the R2 storage adapter |
| `storage__r2__accessKeyId` | Cloudflare R2 Access Key ID |
| `storage__r2__secretAccessKey` | Cloudflare R2 Secret Access Key |
| `storage__r2__bucket` | R2 bucket name (`unchaperoned-life-assets`) |
| `storage__r2__endpoint` | R2 S3-compatible endpoint URL |
| `storage__r2__assetHost` | Public CDN URL (`https://assets.unchaperonedlife.com`) |
| `database__client` | `mysql` |
| `database__connection__*` | MySQL/TiDB connection details |
| `url` | `https://cms.unchaperonedlife.com` |

## Local Development

```bash
docker build -t ghost-cms-local .
docker run -p 2368:2368 \
  -e url=http://localhost:2368 \
  -e database__client=sqlite3 \
  ghost-cms-local
```
