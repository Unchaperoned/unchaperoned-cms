'use strict';

// Use Ghost's own ghost-storage-base to avoid class instance mismatch
let StorageBase;
try {
  StorageBase = require('/var/lib/ghost/current/node_modules/ghost-storage-base');
} catch (e1) {
  try {
    StorageBase = require('/var/lib/ghost/versions/5.130.6/node_modules/ghost-storage-base');
  } catch (e2) {
    StorageBase = require('ghost-storage-base');
  }
}

const { S3Client, PutObjectCommand, DeleteObjectCommand, HeadObjectCommand } = require('@aws-sdk/client-s3');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

class R2StorageAdapter extends StorageBase {
  constructor(config) {
    super(config || {});
    const cfg = config || {};
    this.accessKeyId = cfg.accessKeyId || process.env.GHOST_R2_ACCESS_KEY;
    this.secretAccessKey = cfg.secretAccessKey || process.env.GHOST_R2_SECRET_KEY;
    this.bucket = cfg.bucket || process.env.GHOST_R2_BUCKET;
    this.endpoint = cfg.endpoint || process.env.GHOST_R2_ENDPOINT;
    this.assetHost = cfg.assetHost || process.env.GHOST_R2_ASSET_HOST || 'https://assets.unchaperonedlife.com';
    this.pathPrefix = cfg.pathPrefix || 'ghost-media';

    if (!this.accessKeyId || !this.secretAccessKey) {
      throw new Error('R2 adapter: GHOST_R2_ACCESS_KEY and GHOST_R2_SECRET_KEY are required');
    }

    this.s3 = new S3Client({
      region: 'auto',
      endpoint: this.endpoint,
      credentials: {
        accessKeyId: this.accessKeyId,
        secretAccessKey: this.secretAccessKey,
      },
      forcePathStyle: false,
    });
  }

  // Override getTargetDir - avoid moment dependency
  getTargetDir(baseDir) {
    const now = new Date();
    const year = now.getFullYear().toString();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    return baseDir ? path.join(baseDir, year, month) : path.join(year, month);
  }

  // Override getUniqueFileName - avoid base class recursion issues
  getUniqueFileName(file, targetDir) {
    const ext = path.extname(file.name);
    const baseName = path.basename(file.name, ext).replace(/[^\w@.]/gi, '-');
    const rand = crypto.randomBytes(4).toString('hex');
    const uniqueName = `${baseName}-${rand}${ext}`;
    return Promise.resolve(path.join(targetDir, uniqueName));
  }

  // Required: check if a file exists
  exists(fileName, targetDir) {
    const dir = targetDir || this.getTargetDir(this.pathPrefix);
    const key = this._stripLeadingSlash(path.join(dir, fileName));
    return this.s3.send(new HeadObjectCommand({ Bucket: this.bucket, Key: key }))
      .then(() => true)
      .catch(() => false);
  }

  // Required: save a file, return its public URL
  save(image, targetDir) {
    const directory = targetDir || this.getTargetDir(this.pathPrefix);
    return this.getUniqueFileName(image, directory).then(fileName => {
      const key = this._stripLeadingSlash(fileName);
      const fileData = fs.readFileSync(image.path);
      const contentType = image.type || 'application/octet-stream';
      return this.s3.send(new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: fileData,
        ContentType: contentType,
      })).then(() => {
        const url = `${this._stripTrailingSlash(this.assetHost)}/${key}`;
        return url;
      });
    });
  }

  // Required: serve middleware (R2 files served via CDN)
  serve() {
    return (req, res, next) => next();
  }

  // Required: delete a file
  delete(fileName, targetDir) {
    const dir = targetDir || this.getTargetDir(this.pathPrefix);
    const key = this._stripLeadingSlash(path.join(dir, fileName));
    return this.s3.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }))
      .then(() => true)
      .catch(() => false);
  }

  // Required: read a file
  read(options) {
    return Promise.reject(new Error('R2 adapter: read() not supported — files are served via CDN'));
  }

  _stripLeadingSlash(s) {
    return s.startsWith('/') ? s.slice(1) : s;
  }

  _stripTrailingSlash(s) {
    return s.endsWith('/') ? s.slice(0, -1) : s;
  }
}

module.exports = R2StorageAdapter;
