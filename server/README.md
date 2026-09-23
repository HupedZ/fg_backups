# fg-backups-server

API que corre en tu VPS. Recibe los backups que sube la app Flutter instalada en cada servidor de cliente y los deja organizados por cliente y fecha.

## Como funciona

- Cada instalacion de la app Flutter (una por servidor de cliente) sube, todos los dias a la hora que se configure en la propia app, un `.zip` por cada carpeta seleccionada.
- Los archivos quedan en `BACKUP_DEST_DIR/<clientId>/<fecha>_<carpeta>.zip`, donde `clientId` es el nombre que se puso al configurar la app en ese servidor.
- Despues de cada subida de un cliente se borran sus backups mas viejos que `RETENTION_DAYS` (30 por defecto), **salvo el ultimo backup de cada mes de cada carpeta**, que se conserva de forma permanente. Con backups diarios es el del ultimo dia del mes; con semanales, el ultimo semanal del mes.
- Este servidor **no** dispara backups por si solo: solo recibe. El horario y la decision de que respaldar viven en cada instalacion de la app.

## Requisitos en el VPS

- Node.js >= 18

## Setup

```bash
cd server
npm install
cp .env.example .env
# editar .env con tus datos reales (API_KEY, BACKUP_DEST_DIR, etc)
npm start
```

La API queda escuchando en `http://TU_VPS:4000` (o el `PORT` que definas). Todas las rutas requieren el header `x-api-key: <API_KEY>`.

## Endpoints

- `POST /api/upload` — multipart/form-data con campos `clientId` (texto) y `file` (el `.zip`). Guarda el archivo y devuelve `{ name, sizeBytes }`.
- `GET /api/backups?clientId=<id>` — lista `[{ name, date, sizeBytes }, ...]` de ese cliente.

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

Los servidores de tus clientes se van a conectar a este VPS desde internet, asi que necesitas HTTPS. Pon un reverse proxy (nginx/caddy) con TLS delante del puerto 4000 y usa esa URL (`https://tu-dominio`) en `lib/config.dart` de la app Flutter. No expongas el puerto 4000 directo sin TLS: la API key viajaria en texto plano.
