const fs = require('fs');
const path = require('path');

function dirSizeBytes(dirPath) {
  let total = 0;
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name);
    total += entry.isDirectory() ? dirSizeBytes(fullPath) : fs.statSync(fullPath).size;
  }
  return total;
}

function listBackups() {
  const destDir = process.env.BACKUP_DEST_DIR;
  if (!fs.existsSync(destDir)) return [];

  const entries = fs.readdirSync(destDir, { withFileTypes: true });

  return entries
    .filter((e) => e.isDirectory())
    .map((e) => {
      const fullPath = path.join(destDir, e.name);
      const stat = fs.statSync(fullPath);
      return {
        name: e.name,
        date: stat.mtime.toISOString(),
        sizeBytes: dirSizeBytes(fullPath),
      };
    })
    .sort((a, b) => new Date(b.date) - new Date(a.date));
}

module.exports = { listBackups };
