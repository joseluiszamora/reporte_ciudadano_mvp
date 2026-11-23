# API de reportes ciudadanos

Servicio HTTP en JavaScript con Node.js, Express 5, Prisma 7 y PostgreSQL. La
migración inicial crea el esquema y carga las mismas ocho categorías que el MVP
Android. Crea una base independiente, sin importar datos del teléfono.

## Inicio local

Con Node.js 24 LTS (desde 24.11) o Node.js 22 (desde 22.18), y Docker Compose:

```powershell
cd backend
if (!(Test-Path .env)) { Copy-Item .env.example .env }
docker compose up -d --wait
npm.cmd ci
npm.cmd run db:generate
npm.cmd run db:migrate
npm.cmd run dev
```

Si el puerto 5432 ya está ocupado, configura `POSTGRES_PORT` en `.env` y usa
el mismo puerto en `DATABASE_URL`. El contenedor sigue escuchando en su puerto
interno 5432.

Si ya tienes PostgreSQL, apunta `DATABASE_URL` a esa base y omite Docker Compose.
Usa una base UTF-8 con una configuración regional que reconozca mayúsculas
acentuadas, como `C.UTF-8` con el proveedor integrado de PostgreSQL 17.
Las credenciales del ejemplo son para la base local. El servidor escucha por
defecto en `127.0.0.1:3000`. Usa `npm.cmd start` para ejecutarlo sin reinicio
automático. En Linux o macOS, usa `cp` y `npm` en los comandos.

```powershell
Invoke-RestMethod http://127.0.0.1:3000/ready
Invoke-RestMethod http://127.0.0.1:3000/api/v1/categories
Invoke-RestMethod 'http://127.0.0.1:3000/api/v1/reports?categoryId=baches&limit=10'
```

## Endpoints

| Método y ruta | Respuesta |
|---|---|
| `GET /health` | Estado del proceso HTTP |
| `GET /ready` | Disponibilidad de PostgreSQL, con HTTP 503 si falla la conexión |
| `GET /api/v1/categories` | Catálogo activo, ordenado, en `data` |
| `GET /api/v1/reports` | Resúmenes públicos en `data` y `nextOffset` para la página siguiente |
| `GET /api/v1/reports/summary` | Totales por estado para reportes reales o de demostración |
| `GET /api/v1/reports/:id` | Detalle público en `data`, con historial de estados y metadatos de imágenes |
| `GET /api/v1/admin/session` | Consulta el perfil del administrador autenticado |
| `PUT /api/v1/admin/profile` | Guarda el nombre público elegido |
| `PATCH /api/v1/admin/reports/:id` | Edita, cambia el seguimiento o retira un reporte según la revisión indicada |

El listado admite `q` (búsqueda literal en título y descripción sin distinguir
mayúsculas), `categoryId`, `status` (`REPORTED`, `IN_FOLLOW_UP`, `RESOLVED`),
`from` (inclusivo), `to` (exclusivo), `order` (`asc` o `desc`, por defecto
`desc`), `limit` (1–100, por defecto 20) y `offset` (por defecto 0). Envía
las fechas en UTC, por ejemplo `2026-11-20T00:00:00Z`. `demo=true` devuelve
solo reportes de demostración. El listado predeterminado devuelve reportes reales.
Una base nueva comienza con el listado vacío.

Las lecturas excluyen reportes borrados y omiten UIDs y claves internas de archivos.
Los reportes anónimos se atribuyen a «Ciudadano anónimo».

## Desarrollo del esquema

Los modelos están en `prisma/schema.prisma` y el código HTTP en `src/`.
Para agregar una migración en desarrollo, ejecuta
`npm.cmd run db:migrate:dev -- --name nombre_del_cambio` y después
`npm.cmd run db:generate`. Versiona la migración junto con el cambio de esquema.

Para habilitar la gestión, configura `FIREBASE_PROJECT_ID` con el mismo
proyecto que usa el panel Next.js. Express valida los tokens de Firebase y
comprueba el claim booleano `admin: true`. Los permisos se toman del token
verificado y el perfil debe tener nombre público. Consulta la guía del
[panel web](../frontend/README.md). El alta remota desde Flutter, el almacenamiento
de imágenes y la revisión de propuestas todavía están pendientes.
