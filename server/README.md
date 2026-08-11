# fg-backups-server

API que corre en tu VPS. Hace un backup diario (jala una carpeta de otra máquina por SSH/rsync) y expone endpoints para que la app Flutter prenda/apague el backup automático y vea la lista de backups.

## Como funciona

- Todos los días a la hora definida en `CRON_SCHEDULE`, si `enabled` es `true`, se ejecuta `rsync` sobre SSH para copiar `SOURCE_PATH` (en `SOURCE_HOST`) hacia una carpeta nueva con fecha dentro de `BACKUP_DEST_DIR`.
- El botón de encendido/apagado en la app Flutter solo activa/desactiva ese `enabled`, no dispara un backup inmediato.
- Los backups más viejos que `RETENTION_DAYS` se borran automáticamente después de cada corrida.

## Requisitos en el VPS

- Node.js >= 18
- `rsync` instalado (`apt install rsync`)
- Una llave SSH (sin passphrase o con agente configurado) que tenga acceso al usuario/host origen, apuntada por `SSH_KEY_PATH`. La llave pública debe estar en `~/.ssh/authorized_keys` de la máquina origen.

## Setup

```bash
cd server
npm install
cp .env.example .env
# editar .env con tus datos reales (API_KEY, SOURCE_*, BACKUP_DEST_DIR, etc)
npm start
```

La API queda escuchando en `http://TU_VPS:4000` (o el `PORT` que definas). Todas las rutas requieren el header `x-api-key: <API_KEY>`.

## Endpoints

- `GET /api/status` -> `{ enabled, lastRun, lastStatus, lastError }`
- `POST /api/toggle` con body `{ "enabled": true }` -> enciende/apaga el backup diario
- `GET /api/backups` -> lista `[{ name, date, sizeBytes }, ...]`

## Dejarlo corriendo siempre (systemd)

Crea `/etc/systemd/system/fg-backups.service`:

```ini
[Unit]
Description=fg-backups API
After=network.target

[Service]
Type=simple
WorkingDirectory=/ruta/a/server
EnvironmentFile=/ruta/a/server/.env
ExecStart=/usr/bin/node src/index.js
Restart=on-failure
User=tu_usuario

[Install]
WantedBy=multi-user.target
```

Luego:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fg-backups
```

## Exponerlo a internet

Si la app Flutter se conecta desde fuera del VPS, pon un reverse proxy (nginx/caddy) con HTTPS delante del puerto 4000 y usa esa URL (`https://tu-dominio`) en la configuración de la app. No expongas el puerto 4000 directo sin TLS.
