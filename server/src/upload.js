const fs = require('fs');
const path = require('path');
const multer = require('multer');

const BACKUP_DEST_DIR = process.env.BACKUP_DEST_DIR;
const RETENTION_DAYS = Number(process.env.RETENTION_DAYS || '30');

const CLIENT_ID_RE = /^[a-zA-Z0-9._-]+$/;

function clientDir(clientId) {
  return path.join(BACKUP_DEST_DIR, clientId);
}

const storage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const clientId = req.body.clientId;
    if (!clientId || !CLIENT_ID_RE.test(clientId)) {
      cb(new Error('clientId invalido o faltante'));
      return;
    }
    const dir = clientDir(clientId);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const pad = (n) => String(n).padStart(2, '0');
    const d = new Date();
    const stamp =
      `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
      `_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
    const safeOriginal = path.basename(file.originalname).replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, `${stamp}_${safeOriginal}`);
  },
});

const upload = multer({ storage, limits: { fileSize: 10 * 1024 * 1024 * 1024 } });

function pruneOldBackups(clientId) {
  const retentionMs = RETENTION_DAYS * 24 * 60 * 60 * 1000;
  if (!Number.isFinite(retentionMs) || retentionMs <= 0) return;

  const dir = clientDir(clientId);
  if (!fs.existsSync(dir)) return;

  const cutoff = Date.now() - retentionMs;
  for (const name of fs.readdirSync(dir)) {
    const fullPath = path.join(dir, name);
    const stat = fs.statSync(fullPath);
    if (stat.isFile() && stat.mtimeMs < cutoff) {
      fs.rmSync(fullPath, { force: true });
    }
  }
}

module.exports = { upload, pruneOldBackups, clientDir, CLIENT_ID_RE };
