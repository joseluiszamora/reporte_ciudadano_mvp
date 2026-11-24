# API integrada en Next.js

El panel, las rutas REST y Prisma se ejecutan desde `frontend/`. Consulta
la [guía de arranque y conexión con Neon](../frontend/README.md) y el
[contrato para Flutter](../docs/mobile-api.md).

Si vienes de la versión con Express, mueve los valores
`DATABASE_URL`, `DIRECT_DATABASE_URL` y `FIREBASE_PROJECT_ID` de
`backend/.env` a `frontend/.env.local`. Conserva los valores públicos de
Firebase web y aplica las migraciones con `npm.cmd run db:migrate` desde
`frontend/`. La API estará disponible en el mismo puerto que el panel.
