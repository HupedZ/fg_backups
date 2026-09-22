const fs = require('fs');
const path = require('path');

function listBackups(clientId) {
  const dir = path.join(process.env.BACKUP_DEST_DIR, clientId);
  if (!fs.existsSync(dir)) return [];

  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile())
    .map((e) => {
      const fullPath = path.join(dir, e.name);
      const stat = fs.statSync(fullPath);
      return {
        name: e.name,
        date: stat.mtime.toISOString(),
        sizeBytes: stat.size,
      };
    })
    .sort((a, b) => new Date(b.date) - new Date(a.date));
}

module.exports = { listBackups };
