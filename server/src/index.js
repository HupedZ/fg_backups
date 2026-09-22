require('dotenv').config();
const express = require('express');
const cors = require('cors');

const { upload, pruneOldBackups, CLIENT_ID_RE } = require('./upload');
const { listBackups } = require('./backups-list');

const app = express();
app.use(cors());

app.use((req, res, next) => {
  const key = req.header('x-api-key');
  if (!process.env.API_KEY || key !== process.env.API_KEY) {
    return res.status(401).json({ error: 'API key invalida o faltante' });
  }
  next();
});

app.post('/api/upload', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Falta el archivo (campo "file")' });
  }
  pruneOldBackups(req.body.clientId);
  res.json({ name: req.file.filename, sizeBytes: req.file.size });
});

app.get('/api/backups', (req, res) => {
  const clientId = req.query.clientId;
  if (!clientId || !CLIENT_ID_RE.test(clientId)) {
    return res.status(400).json({ error: 'clientId invalido o faltante' });
  }
  try {
    res.json(listBackups(clientId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`API de backups escuchando en el puerto ${PORT}`);
});
