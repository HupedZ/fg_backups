const fs = require('fs');
const path = require('path');

const STATE_FILE = path.join(__dirname, '..', 'data', 'state.json');

const DEFAULT_STATE = {
  enabled: false,
  lastRun: null,
  lastStatus: null, // 'ok' | 'error'
  lastError: null,
};

function readState() {
  try {
    const raw = fs.readFileSync(STATE_FILE, 'utf8');
    return { ...DEFAULT_STATE, ...JSON.parse(raw) };
  } catch (err) {
    return { ...DEFAULT_STATE };
  }
}

function writeState(partial) {
  const next = { ...readState(), ...partial };
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(next, null, 2));
  return next;
}

module.exports = { readState, writeState };
