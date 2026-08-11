require('dotenv').config();
const express = require('express');
const cors = require('cors');

const { readState, writeState } = require('./state');
const { listBackups } = require('./backups-list');
const { startScheduler } = require('./scheduler');

const app = express();
app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  const key = req.header('x-api-key');
  if (!process.env.API_KEY || key !== process.env.API_KEY) {
    return res.status(401).json({ error: 'API key invalida o faltante' });
  }
  next();
});

app.get('/api/status', (req, res) => {
  res.json(readState());
});

app.post('/api/toggle', (req, res) => {
  const { enabled } = req.body;
  if (typeof enabled !== 'boolean') {
    return res.status(400).json({ error: 'Se espera { enabled: boolean }' });
  }
  res.json(writeState({ enabled }));
});

app.get('/api/backups', (req, res) => {
  try {
    res.json(listBackups());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`API de backups escuchando en el puerto ${PORT}`);
  startScheduler();
});
