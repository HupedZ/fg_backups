const cron = require('node-cron');
const { readState } = require('./state');
const { runBackup } = require('./backup');

function startScheduler() {
  const schedule = process.env.CRON_SCHEDULE || '0 3 * * *';

  cron.schedule(schedule, async () => {
    const state = readState();
    if (!state.enabled) return;

    try {
      await runBackup();
    } catch (err) {
      console.error('Backup diario fallo:', err.message);
    }
  });

  console.log(`Backup diario programado con cron "${schedule}" (activo solo si enabled=true)`);
}

module.exports = { startScheduler };
