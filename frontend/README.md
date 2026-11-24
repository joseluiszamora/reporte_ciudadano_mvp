# Panel web de reportes ciudadanos

Panel local de Next.js. El navegador usa rutas del mismo origen y Next.js envía
las solicitudes a Express. Prisma accede a PostgreSQL en Docker Desktop desde
Express, donde también se validan los permisos y se registran los cambios.

## Arranque

Inicia PostgreSQL y Express siguiendo la [guía del backend](../backend/README.md).
Desde este directorio:

```powershell
if (!(Test-Path .env.local)) { Copy-Item .env.example .env.local }
npm.cmd ci
npm.cmd run dev
```

Abre [el panel local](http://localhost:3001). Si Express escucha en otro puerto,
ajusta `REPORTS_API_URL` en `.env.local`. El listado, los filtros y el detalle
son públicos. Separan reportes reales y de demostración, y excluyen los retirados.

## Gestión con Google

Sigue la [guía de acceso de administrador](../docs/firebase-setup.md#acceso-de-administrador-al-panel-web)
para registrar el panel en Firebase y asignar `admin: true` a tu cuenta de Google.

El usuario confirmó el inicio de sesión con Google y el acceso como administrador
en el panel local de Reportes Ciudadanos.

Desde el detalle se pueden editar los datos, iniciar seguimiento, devolver a
reportado, reabrir o retirar lógicamente. Las acciones requieren motivo y
comprueban la revisión del reporte para evitar sobrescrituras. Resolver un
reporte requiere una propuesta aprobada. La revisión de propuestas y la
visualización de archivos de imágenes quedan pendientes de sus servicios remotos.

Los reportes guardados en SQLite en el teléfono aparecerán en el panel cuando se
integren las escrituras remotas de Flutter.
