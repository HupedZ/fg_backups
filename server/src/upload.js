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

// <YYYY-MM-DD>_<HHMMSS>_<carpeta>_<epoch ms>.zip
const BACKUP_NAME_RE = /^(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})_(.+)_\d{10,}\.zip$/;

function describeBackup(file) {
  const m = BACKUP_NAME_RE.exec(file.name);
  if (m) {
    const [, y, mo, d, h, mi, s, folder] = m;
    return { date: new Date(+y, +mo - 1, +d, +h, +mi, +s), month: `${y}-${mo}`, folder };
  }
  const date = new Date(file.mtimeMs);
  const month = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
  return { date, month, folder: '' };
}

// Borra lo que supere retentionDays, salvo el ultimo backup de cada mes
// (por carpeta respaldada), que se conserva de forma permanente.
function selectBackupsToDelete(files, nowMs, retentionDays) {
  const retentionMs = retentionDays * 24 * 60 * 60 * 1000;
  if (!Number.isFinite(retentionMs) || retentionMs <= 0) return [];

  const described = files.map((f) => ({ name: f.name, ...describeBackup(f) }));

  const lastOfGroup = new Map();
  for (const f of described) {
    const key = `${f.month}|${f.folder}`;
    const current = lastOfGroup.get(key);
    if (!current || f.date > current.date) lastOfGroup.set(key, f);
  }

  return described
    .filter((f) => nowMs - f.date.getTime() > retentionMs)
    .filter((f) => lastOfGroup.get(`${f.month}|${f.folder}`) !== f)
    .map((f) => f.name);
}

function pruneOldBackups(clientId) {
  const dir = clientDir(clientId);
  if (!fs.existsSync(dir)) return;

  const files = fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile())
    .map((e) => ({ name: e.name, mtimeMs: fs.statSync(path.join(dir, e.name)).mtimeMs }));

  for (const name of selectBackupsToDelete(files, Date.now(), RETENTION_DAYS)) {
    fs.rmSync(path.join(dir, name), { force: true });
  }
}

module.exports = { upload, pruneOldBackups, selectBackupsToDelete, clientDir, CLIENT_ID_RE };
