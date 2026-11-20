# MVP 1.0 — Reportes Ciudadanos de El Alto

**Estado:** definición funcional inicial confirmada · **Fecha:** 19 de noviembre de 2026

**Nombre del producto:** provisional; no se ha elegido una marca definitiva.

**Ámbito:** municipio de El Alto (Bolivia).

**Plataforma inicial:** Android, desarrollado con Flutter.
**Persistencia:** SQLite local (sin API ni backend propio en esta fase).

> **Actualización confirmada — 19 de noviembre de 2026:** el usuario administrador
> gestionará reportes y revisará soluciones desde Android en esta fase local;
> la aprobación desde una app web se incorporará después con backend compartido.
> Tras Google, cada persona elegirá su nombre público. La eliminación será lógica
> y las acciones se conservarán para informes de auditoría. Si una fotografía no
> se guarda correctamente, se notificará y se pedirá adjuntarla de nuevo, sin
> guardar un reporte incompleto. Las reglas precisas, límites y transiciones están
> en [docs/business-rules.md](docs/business-rules.md), que prevalece sobre las
> referencias iniciales a moderación exclusivamente futura y simulación.
> El esquema inicial actualizado está en `assets/database/schema_v1.sql` y el
> estado real de implementación en [docs/implementation-plan.md](docs/implementation-plan.md).

## 1. Propósito y criterio de éxito

Facilitar que los ciudadanos documenten problemas urbanos y consulten su estado, evidencia fotográfica y el tiempo transcurrido hasta su solución. Primero se validará en un MVP local antes de incorporar una plataforma centralizada y una base de datos compartida.

**Limitación deliberada:** los reportes, historiales y estadísticas del MVP existen en el dispositivo que los crea. No son visibles en otros dispositivos. Los datos precargados deben distinguirse como *demostración*. No representar estadísticas locales como indicadores oficiales o públicos de la ciudad.

## 2. Decisiones confirmadas

| Tema | Decisión |
|---|---|
| Primera ciudad | El Alto, Bolivia |
| Primera plataforma | Solo Android |
| Framework | Flutter |
| Base de datos | SQLite local |
| Backend propio | Pospuesto |
| Autenticación | Google Sign-In; Firebase Authentication es la integración recomendada |
| Lectura | Permitida sin iniciar sesión |
| Crear reporte | Requiere sesión de Google |
| Identidad pública | Nombre elegido después de Google; anonimato opcional por reporte |
| Fotografías | Al menos una obligatoria |
| Geolocalización | GPS con ajuste manual en mapa |
| Mapas | OpenStreetMap, vista de mapa y listado |
| Categorías | Inicialmente sembradas en SQLite; administradas en el futuro desde backend |
| Estados públicos | Reportado, En seguimiento, Solucionado |
| Verificación | Propuesta con evidencia y aprobación por usuario admin en Android; app web futura |
| Indicadores | Conteo por estado/categoría; días pendientes y tiempo de resolución |
| Participación avanzada | Votaciones, comentarios, confirmaciones masivas y moderación multiusuario quedan para versiones posteriores |

## 3. Categorías iniciales

1. Baches y daños en las calles
2. Semáforos averiados
3. Aceras bloqueadas u ocupadas
4. Alumbrado público defectuoso
5. Basura y acumulación de residuos
6. Alcantarillas o drenajes dañados
7. Señalización vial dañada o ausente
8. Otros problemas urbanos

Las categorías tendrán identificadores estables (UUID o claves de catálogo persistentes), nombre, ícono, orden de visualización, estado activo e identificador futuro de servidor. No deben codificarse rígidamente en las pantallas.

## 4. Roles y permisos

| Acción | Visitante | Usuario Google con perfil completo | Admin local |
|---|:---:|:---:|:---:|
| Ver mapa, listado y detalle | Sí | Sí | Sí |
| Filtrar, consultar estadísticas | Sí | Sí | Sí |
| Crear reporte | No | Sí | Sí |
| Crear reporte público anónimo | No | Sí | Sí |
| Proponer solución con evidencia | No | Sí | Sí |
| Editar reportes propios (regla limitada) | No | Sí | Sí |
| Aprobar/rechazar propuesta de solución | No | No | Sí |
| Administrar categorías/usuarios | No | No | Sí |

**MVP:** no existe servicio de moderación centralizado. El admin autenticado gestiona los reportes presentes en su teléfono. Las revisiones de datos demo deben identificarse como simuladas. Una aprobación local no equivale a verificación oficial o comunitaria.

## 5. Requisitos funcionales

### 5.1 Inicio y navegación

- Pantalla inicial con acceso a **Mapa**, **Reportes**, **Crear reporte**, **Estadísticas**, **Mi perfil**.
- Navegación disponible para invitados, excepto acciones de creación y propuesta de solución.
- Mostrar botón para iniciar sesión cuando una acción protegida lo requiera; tras autenticarse, recuperar el flujo pendiente.
- Estados vacíos para base de datos sin reportes y estado demostración para datos sembrados.

### 5.2 Mapa y listado

- Centrar la cámara inicial en El Alto, con ajuste según GPS si el usuario lo autoriza.
- Mostrar marcadores por categoría/estado, y permitir abrir el detalle.
- Listar título, fotografía principal, categoría, ubicación aproximada, estado y tiempo transcurrido.
- Filtrar por categoría, estado y fecha; ordenar por más recientes y más antiguos.
- Vista de mapa y listado reflejan los mismos filtros.
- No exigir permiso GPS solo para consultar información; usar el mapa con ubicación inicial aunque se deniegue.

### 5.3 Alta de reporte

Campos obligatorios: categoría, título, descripción, al menos una fotografía, latitud y longitud (capturadas o elegidas manualmente). Fecha y hora generadas automáticamente en UTC. El autor elige `PUBLIC_NAME` o `ANONYMOUS` para la atribución pública.

Flujo sugerido:

1. Iniciar sesión con Google (si no lo hizo) y completar el nombre público elegido.
2. Elegir categoría.
3. Escribir título y descripción.
4. Adjuntar foto(s) mediante cámara o galería; validar mínimo una.
5. Seleccionar GPS o corregir posición en mapa.
6. Elegir mostrar nombre o publicar anónimamente.
7. Revisar vista previa y guardar.
8. Ver detalle del reporte creado.

Fotos guardadas en el directorio privado de la aplicación; SQLite guarda solo las rutas relativas y los metadatos. Nunca depender exclusivamente de una ruta temporal producida por el selector de imágenes. Considerar optimización de tamaño y eliminación de metadatos EXIF innecesarios.

### 5.4 Detalle e historial

- Fotografías ampliables, descripción, categoría, ubicación, estado, fecha de reporte.
- Mostrar `Tiempo pendiente: X días / horas` mientras no esté solucionado, y `Resuelto en: X días / horas` cuando esté cerrado.
- Línea cronológica de cambios de estado y propuestas de solución.
- Mostrar el alias “Ciudadano anónimo” en reportes publicados anónimamente, sin exponer email, UID ni foto de Google.
- Posibilidad de compartir texto resumen o una imagen por hoja de compartir Android en el MVP. **No generar enlaces públicos inexistentes**, porque el reporte no existe en un servidor compartido.

### 5.5 Propuesta y verificación de solución

Estados visibles del reporte: `REPORTED`, `IN_FOLLOW_UP`, `RESOLVED`. El admin inicia seguimiento con una acción explícita y motivo; la aprobación de evidencia es el único camino hacia `RESOLVED`.

La *propuesta de solución* es un objeto separado con estado `PENDING`, `APPROVED` o `REJECTED`. Un usuario autenticado puede señalar que el problema fue reparado y aportar fotografía de evidencia. Solo cuando la propuesta sea aprobada se cambia el reporte a `RESOLVED` y se registra `resolved_at`. Para el MVP, la aprobación se prueba mediante un simulador administrativo local; posteriormente corresponderá a una autoridad/moderador o un mecanismo de validación comunitaria definido por el producto.

Conservar en el historial: fecha, actor interno, estado anterior, estado nuevo, motivo y evidencia cuando corresponda. Evitar cambios silenciosos de estado. El paso a `IN_FOLLOW_UP` puede registrarse cuando se añade actividad de seguimiento local; su disparador definitivo se configurará al diseñar el backend.

### 5.6 Estadísticas

- Total de reportes locales.
- Reportados, en seguimiento, solucionados.
- Reportes por categoría.
- Antigüedad de los pendientes (días/horas desde `created_at`).
- Tiempo promedio de resolución (`resolved_at - created_at`) para reportes solucionados.
- Filtro por fechas.
- Campo opcional de institución presuntamente responsable, inicialmente sin asignación automática ni calificación institucional; la gestión/validación del catálogo corresponde a una etapa futura.
- Etiqueta inequívoca: **“Estadísticas locales; no representan a toda la ciudad”**. Separar datos demo y añadir su aviso cuando estén incluidos; excluir reportes eliminados.

## 6. Reglas de negocio y validación

- Identificador de entidades de usuario: UUID generado en el dispositivo, excepto `users.id` (Firebase UID). Categorías: claves de catálogo estables para permitir futura sincronización.
- `created_at`, `updated_at`, `resolved_at`: UTC ISO 8601; la interfaz muestra la zona horaria local.
- Categoría habilitada para registrar; categorías desactivadas permanecen asociadas a registros históricos.
- No permitir guardar un reporte sin foto válida o sin coordenadas.
- Mantener una ruta local relativa y verificar que el archivo de cada foto exista al abrir el detalle.
- El autor de un reporte anónimo se conserva como UID interno; no se publica.
- Un visitante no puede crear, editar ni proponer solución.
- La solución propuesta **no** cambia automáticamente el estado público a solucionado.
- Registrar todos los cambios de estado para auditar resoluciones.
- El reloj del dispositivo puede alterarse; los tiempos locales son provisionales y no constituyen prueba fiable de atención institucional. En el backend deberán utilizarse marcas temporales de servidor.
- La ubicación de El Alto es el ámbito geográfico del proyecto, pero el MVP no aplicará una geocerca municipal no verificada. Mostrar advertencia si la posición se aleja del área esperada y definir más adelante los límites oficiales.

## 7. Modelo de datos SQLite recomendado

### `users`

`id TEXT PRIMARY KEY` (Firebase UID), `display_name TEXT`, `email TEXT`, `photo_url TEXT`, `created_at TEXT`, `last_sign_in_at TEXT`. Datos privados, no expuestos en listados públicos.

### `categories`

`id TEXT PRIMARY KEY`, `slug TEXT UNIQUE`, `name TEXT NOT NULL`, `icon_key TEXT`, `color_key TEXT`, `sort_order INTEGER`, `is_active INTEGER`, `server_id TEXT NULL`, `updated_at TEXT`.

### `reports`

`id TEXT PRIMARY KEY`, `author_uid TEXT NOT NULL`, `category_id TEXT NOT NULL`, `title TEXT NOT NULL`, `description TEXT NOT NULL`, `latitude REAL NOT NULL`, `longitude REAL NOT NULL`, `address_label TEXT NULL`, `status TEXT NOT NULL`, `public_identity_mode TEXT NOT NULL`, `responsible_institution_label TEXT NULL`, `created_at TEXT NOT NULL`, `updated_at TEXT NOT NULL`, `resolved_at TEXT NULL`, `sync_state TEXT NOT NULL DEFAULT 'LOCAL_ONLY'`, `server_id TEXT NULL`, `deleted_at TEXT NULL`.

Claves foráneas a `users` y `categories`; índices por categoría, estado, fecha y autor.

### `report_images`

`id TEXT PRIMARY KEY`, `report_id TEXT NOT NULL`, `local_relative_path TEXT NOT NULL`, `mime_type TEXT`, `sort_order INTEGER NOT NULL`, `created_at TEXT NOT NULL`, `server_id TEXT NULL`. Clave foránea a `reports` con eliminación en cascada definida según política de retención.

### `report_status_history`

`id TEXT PRIMARY KEY`, `report_id TEXT NOT NULL`, `from_status TEXT NULL`, `to_status TEXT NOT NULL`, `actor_uid TEXT NULL`, `note TEXT NULL`, `created_at TEXT NOT NULL`, `is_demo_action INTEGER NOT NULL DEFAULT 0`.

### `resolution_proposals`

`id TEXT PRIMARY KEY`, `report_id TEXT NOT NULL`, `proposer_uid TEXT NOT NULL`, `note TEXT NOT NULL`, `status TEXT NOT NULL`, `evidence_image_path TEXT NOT NULL`, `created_at TEXT NOT NULL`, `reviewed_at TEXT NULL`, `reviewer_uid TEXT NULL`, `review_note TEXT NULL`, `is_demo_review INTEGER NOT NULL DEFAULT 0`.

Considerar tabla `schema_migrations` o aprovechar las migraciones versionadas de Drift. Activar `PRAGMA foreign_keys=ON` y pruebas de integridad. Aplicar restricciones CHECK para los estados y el modo de identidad.

**Evolución:** la API reutilizará los UUID del cliente, `server_id` y `sync_state`; evitar que las entidades dependan de enteros autoincrementales exclusivos del teléfono. Definir después estrategia de conflictos y versionado de registros.

## 8. Arquitectura Flutter

Patrón: **feature-first + capas presentación / dominio / datos + repositorios**.

Tecnologías recomendadas:

- `flutter_bloc` (Cubit/BLoC): gestión de estados de UI.
- `go_router`: navegación y redirección por autenticación.
- `drift` + `drift_flutter`: tipado, consultas reactivas y migraciones sobre SQLite.
- `firebase_core`, `firebase_auth`, `google_sign_in`: autenticación con Google gestionada externamente.
- `flutter_map`, `latlong2`: visualización de mapas con fuentes basadas en OSM.
- `geolocator`: coordenadas del dispositivo, sujetas a permisos.
- `image_picker`: cámara y galería.
- `path_provider`: almacenamiento persistente local de fotografías.
- `share_plus`: compartir resumen/imágenes sin enlace público durante MVP.
- `intl`, `uuid`: fechas y claves.

La elección exacta de versiones se confirmará con `flutter pub add`, compatibilidad Flutter/Dart y `flutter pub outdated` al inicializar el repositorio.

```text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    database/
    errors/
    location/
    media/
    utils/
  features/
    auth/
      data/
      domain/
      presentation/
    categories/
      data/
      domain/
    reports/
      data/
      domain/
      presentation/
    map/
      presentation/
    statistics/
      domain/
      presentation/
    profile/
      presentation/
  shared/
    widgets/
```

**Contratos recomendados:** `AuthRepository`, `CategoryRepository`, `ReportRepository`, `ReportImageRepository`, `ResolutionRepository`, `StatisticsRepository`. Sus consumidores deben depender de interfaces y no de clases SQLite. Sustituir posteriormente adaptadores por API REST + sincronización. Las imágenes también deben pasar por una interfaz de almacenamiento para su futura migración a almacenamiento remoto.

## 9. Pantallas y flujo principal

1. **Inicio/Mapa**: marcadores, filtros, buscador inicial simple y navegación a detalle.
2. **Reportes**: lista filtrable y ordenable con tarjetas.
3. **Detalle**: carrusel fotográfico, mapa, estado, días transcurridos, historial y propuesta de solución.
4. **Nuevo reporte**: formulario, fotos, ubicación corregible, identidad pública y vista previa.
5. **Estadísticas**: contadores, agrupaciones por categoría y tiempos.
6. **Mi perfil**: estado de sesión, Google Sign-In/Sign-Out, mis reportes y explicaciones de privacidad.
7. **Validación local de prueba**: acceso separado para simular aprobación/rechazo de propuestas (no funcionalidad pública real).

**Flujo de invitado:** abrir app -> explorar mapa/listado -> detalle -> intentar crear -> autenticarse -> volver al formulario.

**Flujo de usuario:** autenticar -> nuevo reporte -> foto(s) -> pin de mapa -> anonimato público -> guardar -> detalle -> seguimiento.

## 10. Plan progresivo de implementación con Codex

| Tarea | Entrega concreta | Aceptación / verificación |
|---|---|---|
| TASK-001 | Repositorio Flutter Android, estructura, lint, navegación y tema | `flutter analyze` sin errores, arranque en emulador o dispositivo |
| TASK-002 | Drift/SQLite, entidades, migraciones y semillas de 8 categorías | CRUD y pruebas de integridad, persistencia tras reinicio |
| TASK-003 | Mapa OSM y selector de ubicación | Visualización, marcadores y ajuste manual del pin; sin GPS obligatorio para invitados |
| TASK-004 | Lista, filtros y pantalla de detalle | Consultas coherentes con mapa y categorías; estados vacíos |
| TASK-005 | Login Google/Firebase y restricciones de acciones | Invitado lee; usuario autenticado crea; logout; retomar flujo protegido |
| TASK-006 | Formulario completo de nuevo reporte y fotos | No guarda sin imagen o coordenadas; anonimato público respetado |
| TASK-007 | Historial, propuesta de solución y simulador de aprobación | Persisten transiciones; una propuesta sin aprobar no resuelve |
| TASK-008 | Estadísticas y tiempo transcurrido | Cálculos locales correctos; aviso de datos demostrativos |
| TASK-009 | Compartir resumen, accesibilidad, pruebas y release interno APK | No se comparte enlace inexistente; permisos y denegaciones bien manejados |

**Orden de ejecución:** implementar una tarea a la vez; revisar el APK y sus pruebas antes de cerrar cada tarea en GitHub. Usar `main` como rama estable y ramas `feature/TASK-xxx-descripcion` para entregables. Cada tarea debería incluir prueba de aceptación manual, pruebas automáticas cuando correspondan y una captura de pantalla o vídeo breve para revisión.

## 11. Casos de prueba imprescindibles

1. Invitado ve reportes demo y estadísticas, pero no puede guardar uno nuevo.
2. Inicio/cierre de sesión Google Android y reanudación del formulario.
3. Sin fotos: formulario impide guardar. Con foto válida: guarda y la conserva al reiniciar.
4. Permiso GPS denegado: permite seleccionar el punto manualmente.
5. Mapa sin Internet: muestra error recuperable; los reportes locales siguen accesibles en la lista.
6. Anonimato público: no filtra email, UID ni foto de perfil en ningún detalle, tarjeta ni texto compartido.
7. Propuesta pendiente: el reporte no aparece como solucionado.
8. Aprobación simulada: se registra en historial y calcula tiempo hasta resolución; se identifica como demostración.
9. Base vacía: estadísticas muestran cero y CTA coherente; sin datos falsos sin etiquetar.
10. Migración de esquema: conserva reportes y fotos registrados previamente.

## 12. Fuera de alcance de MVP 1.0

- Backend propio, PostgreSQL o API compartida.
- Sincronización entre teléfonos y tablero público real.
- Panel administrativo remoto o notificaciones push.
- Gestión remota de categorías y asignación verificada de instituciones.
- Comentarios y votaciones ciudadanas distribuidas.
- Moderación, denuncias de contenido y comprobación comunitaria multiusuario reales.
- Rankings oficiales de instituciones o garantías de tiempos de resolución.
- Soporte para iOS o web.

## 13. Riesgos y decisiones para versiones posteriores

- **Validez ciudadana:** la visibilidad y comparación pública de reportes requieren centralizar datos y establecer una política de moderación.
- **Privacidad:** controlar la información personal en fotos, rostros, menores, matrículas y ubicaciones sensibles; prever denuncia y eliminación de contenido antes de un lanzamiento público real.
- **Fiabilidad de tiempos:** timestamps locales son manipulables; usar fechas del servidor y bitácora auditable cuando exista backend.
- **Abuso y duplicados:** limitar spam, detectar incidentes cercanos y comprobar evidencia en futuras etapas.
- **Mapas:** `flutter_map` no implica hospedaje de teselas. Respetar atribución, identificación del cliente, caché y restricciones de uso de OpenStreetMap; seleccionar un proveedor de teselas apropiado si hay despliegue masivo. El servidor público de OSM no permite descargas masivas de mapas offline.
- **Firebase:** es un servicio externo de autenticación, no un backend de reportes; requiere configurar la aplicación Android y sus firmas de desarrollo y publicación.
- **Pérdida de datos:** reinstalar o borrar datos de la app elimina SQLite y fotos locales; advertirlo y no prometer respaldo hasta contar con sincronización.

## 14. Definición de terminado (MVP)

Una persona sin sesión puede abrir el APK, consultar un mapa/listado de reportes de prueba y estadísticas claramente locales. Tras iniciar sesión con Google, puede registrar un problema con su categoría, descripción, foto y ubicación geográfica, eligiendo atribución visible o anónima. El reporte persiste en SQLite, se visualiza correctamente y permite seguir estados y propuestas de solución simuladas, con fecha, historial y cálculo de tiempo. La app conserva una arquitectura que permitirá reemplazar los repositorios locales con adaptadores de API sin reescribir los flujos de UI.

## 15. Referencias técnicas

- Firebase Authentication Flutter: https://firebase.google.com/docs/auth/flutter/start
- Drift SQLite Flutter: https://pub.dev/packages/drift
- flutter_map: https://pub.dev/packages/flutter_map
- Política de uso de teselas OSM: https://operations.osmfoundation.org/policies/tiles/
