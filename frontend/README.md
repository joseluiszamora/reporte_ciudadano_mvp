# Panel web de reportes ciudadanos

Next.js sirve el panel y la API REST desde el mismo proceso. Los Route Handlers
verifican los tokens de Firebase y usan Prisma para consultar y modificar
PostgreSQL. La app Android puede usar la misma [API versionada](../docs/mobile-api.md).

## Arranque

Usa Node.js 24.11 o posterior de la serie 24, o Node.js 22.18 o posterior de la
serie 22. Desde este directorio:

```powershell
if (!(Test-Path .env.local)) { Copy-Item .env.example .env.local }
npm.cmd ci
npm.cmd run db:generate
npm.cmd run db:migrate
npm.cmd run dev
```

Antes de migrar, configura el destino en `.env.local`:

- **Neon**. Usa la URL agrupada en `DATABASE_URL` y la URL directa en
  `DIRECT_DATABASE_URL` para Prisma Migrate. Conserva `channel_binding` si
  aparece y usa `sslmode=verify-full` en la URL agrupada.
- **Docker local**. Usa la URL local de `.env.example` y deja
  `DIRECT_DATABASE_URL` vacío. Ejecuta
  `docker compose --env-file .env.local up -d --wait` antes de migrar.
  Si 5432 está ocupado, ajusta `POSTGRES_PORT` y el puerto de `DATABASE_URL`.

Abre [el panel local](http://localhost:3001) y comprueba
[la conexión con PostgreSQL](http://localhost:3001/api/v1/ready).
Para desplegar, ejecuta `npm.cmd run build` y usa un servidor Node.js con
`npx.cmd next start`, el puerto del proveedor y las variables del entorno.
Configura los valores `NEXT_PUBLIC_FIREBASE_*` antes de compilar.
Las fotos necesitan un proveedor que admita el tamaño de petición descrito
en el contrato de la API. El despliegue requiere el runtime de Next.js.

Con el esquema aplicado, `npm.cmd run test:api` ejecuta la prueba de integración
contra PostgreSQL y revierte sus registros al finalizar.

## Gestión con Google

Sigue la [guía de acceso de administrador](../docs/firebase-setup.md#acceso-de-administrador-al-panel-web)
para registrar el panel en Firebase y asignar `admin: true` a tu cuenta de Google.

El usuario confirmó el inicio de sesión con Google y el acceso como administrador
en el panel local de Reportes Ciudadanos.

Desde el detalle se pueden editar los datos, iniciar seguimiento, devolver a
reportado, reabrir o retirar lógicamente. Las acciones requieren motivo y
comprueban la revisión del reporte para evitar sobrescrituras. El panel también
muestra las fotos y permite revisar evidencia, aprobar o rechazar propuestas.
Al aprobar una propuesta se marca el reporte como solucionado.

Los reportes guardados en SQLite en el teléfono aparecerán en el panel cuando se
integren las escrituras remotas de Flutter.
