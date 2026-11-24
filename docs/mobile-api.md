# API para Flutter

El panel y la aplicación móvil pueden usar la misma API HTTPS en
`/api/v1`. En este equipo se ejecuta en `http://localhost:3001/api/v1`.
Para probar las lecturas desde el emulador Android, inicia Next.js desde `web-api/` con
`npx.cmd next dev --hostname 0.0.0.0 --port 3001` y usa
`http://10.0.2.2:3001/api/v1` si la configuración de depuración permite HTTP.
Para enviar tokens en un dispositivo usa un destino HTTPS.

## Solicitudes

Las rutas protegidas aceptan `Authorization: Bearer <token ID de Firebase>`.
En Dart puedes obtener el token con
`await FirebaseAuth.instance.currentUser?.getIdToken()`. La cuenta debe
pertenecer al proyecto de Firebase configurado en el servidor. Las rutas
administrativas requieren el claim `admin: true`. El servidor valida el token
y aplica las reglas de propietario y estado.

| Método | Ruta bajo `/api/v1` | Uso |
| --- | --- | --- |
| GET | `/health`, `/ready` | Estado de la API y de PostgreSQL |
| GET | `/categories` | Catálogo activo |
| GET | `/reports`, `/reports/:id` | Listado, detalle e historial públicos |
| GET | `/reports/summary` | Totales por estado |
| GET | `/me`, `/me/reports` | Perfil y reportes propios |
| PUT | `/me/profile` | Guarda `{ "publicName": "Nombre elegido" }` |
| POST | `/reports` | Publicación autenticada con 1 a 5 fotos |
| PATCH | `/reports/:id` | Edición o borrado lógico del reporte propio, con revisión y motivo |
| GET / POST | `/reports/:id/proposals` | Consulta las propuestas propias o envía una propuesta con evidencia |
| GET | `/media/:id` | JPEG público del reporte o evidencia con los permisos correspondientes |
| GET / PUT | `/admin/session` / `/admin/profile` | Consulta o completa el perfil administrativo |
| PATCH | `/admin/reports/:id` | Edición, retiro o cambio de seguimiento |
| PATCH | `/admin/proposals/:id` | Revisa una propuesta con `{ "action": "approve", "reason": "..." }` o `reject` |

En `GET /reports` y `GET /me/reports`, usa `q`, `categoryId`, `status`,
`order` (`asc` o `desc`), `limit` (1–100) y `offset`. Los filtros
`from` y `to` usan UTC terminado en `Z`; el inicio incluye la fecha y
el final la excluye. Los estados son `REPORTED`, `IN_FOLLOW_UP` y `RESOLVED`.
`demo=true` consulta solo demostraciones. El listado devuelve `{ data, nextOffset }`.
El resumen también admite `demo=true`.

## Fotos, revisiones y reintentos

Para publicar, envía `multipart/form-data` con un campo de texto `data`
que contenga el JSON y una parte de archivo `photos` por cada foto.
`requestId` es un UUID generado por Flutter, que se conserva en los reintentos
de la misma publicación:

```json
{
  "requestId": "5d96b1be-82be-40a1-aa68-8802fa32dba0",
  "categoryId": "baches",
  "title": "Bache junto a la plaza",
  "description": "La vía presenta un bache cerca del cruce principal.",
  "latitude": -16.5,
  "longitude": -68.15,
  "addressLabel": "Cerca de la plaza",
  "publicIdentityMode": "ANONYMOUS"
}
```

Usa `PUBLIC_NAME` para atribuirlo al nombre público o `ANONYMOUS` para
publicarlo como «Ciudadano anónimo». Una creación devuelve 201 y un reintento
del mismo autor devuelve 200 con el mismo ID. Si el UUID pertenece a otra
publicación o fue retirado, la API responde 409.

Para editar, envía los campos del reporte junto con `action: "edit"`,
`revision` del detalle y un `reason` de 10–1.000 caracteres. Usa JSON para
conservar las fotos vigentes o multipart para reemplazar el conjunto completo.
Para retirar, usa JSON con `action: "delete"`, `revision` y `reason`.
Si la revisión cambió, recupera el detalle antes de volver a editar.
El seguimiento administrativo usa `action: "status"` y el campo `status`.
Para solucionar un reporte se requiere aprobar una propuesta.

Envía propuestas con el mismo formato multipart: `data` con `requestId`
y `note`, y un solo archivo `photos`. Cada foto puede pesar hasta 10 MiB y
tener hasta 20 megapíxeles. El servidor acepta JPEG, PNG o WebP, guarda JPEG
sin metadatos en PostgreSQL y devuelve rutas relativas para su consulta.
La evidencia pendiente o rechazada es accesible para su proponente y el
administrador. La evidencia aprobada aparece en el detalle público.

Las respuestas usan `{ data }` o `{ error }`. Trata 401 como sesión
requerida, 403 como perfil o permiso insuficiente, y 409 como conflicto de
revisión, estado o identificador. Conserva el borrador y su UUID ante fallos
de red. Los repositorios SQLite de Flutter siguen funcionando en modo local;
este contrato habilita un cliente remoto para una integración posterior.
