const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const { writeState } = require('./state');

const {
  SOURCE_USER,
  SOURCE_HOST,
  SOURCE_PATH,
  SSH_KEY_PATH,
  BACKUP_DEST_DIR,
  RETENTION_DAYS = '30',
} = process.env;

function timestampFolderName(date = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `_${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
  );
}

function runRsync(destDir) {
  return new Promise((resolve, reject) => {
    const sshCommand = `ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=accept-new`;
    const remoteSource = `${SOURCE_USER}@${SOURCE_HOST}:${SOURCE_PATH.replace(/\/?$/, '/')}`;
    const args = ['-az', '-e', sshCommand, remoteSource, destDir];

    execFile('rsync', args, { maxBuffer: 1024 * 1024 * 10 }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(stderr || error.message));
        return;
      }
      resolve(stdout);
    });
  });
}

function pruneOldBackups() {
  const retentionMs = Number(RETENTION_DAYS) * 24 * 60 * 60 * 1000;
  if (!Number.isFinite(retentionMs) || retentionMs <= 0) return;

  const cutoff = Date.now() - retentionMs;
  const entries = fs.readdirSync(BACKUP_DEST_DIR, { withFileTypes: true });

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const fullPath = path.join(BACKUP_DEST_DIR, entry.name);
    const stat = fs.statSync(fullPath);
    if (stat.mtimeMs < cutoff) {
      fs.rmSync(fullPath, { recursive: true, force: true });
    }
  }
}

async function runBackup() {
  fs.mkdirSync(BACKUP_DEST_DIR, { recursive: true });
  const destDir = path.join(BACKUP_DEST_DIR, timestampFolderName());
  fs.mkdirSync(destDir, { recursive: true });

  try {
    await runRsync(destDir);
    pruneOldBackups();
    writeState({ lastRun: new Date().toISOString(), lastStatus: 'ok', lastError: null });
  } catch (err) {
    writeState({ lastRun: new Date().toISOString(), lastStatus: 'error', lastError: err.message });
    throw err;
  }
}

module.exports = { runBackup };
