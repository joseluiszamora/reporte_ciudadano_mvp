# Arquitectura y estado de la base

La aplicación Android usa Flutter. `app/` contiene configuración, tema y rutas;
`core/` infraestructura transversal; `features/` contratos y reglas por dominio;
`shared/` widgets compartidos. La UI depende de interfaces de repositorios.

## Estructura prevista por feature

Cada feature incorpora `domain/`, `data/` y `presentation/` conforme se implementa.
No se crean adaptadores vacíos ni servicios que aparenten autenticación real.

| Feature | Dominio | Datos | Presentación pendiente |
|---|---|---|---|
| auth | AppUser, AuthRepository | FirebaseGoogleGateway, GoogleAuthRepository, LocalUserStore | Login con Google comprobado por el usuario en Android |
| categories | CategoryRepository | SqliteCategoryRepository | Catálogo y selector del formulario implementados |
| reports | ReportPolicy, ReportRepository, ReportReadRepository, ReportComposition, ResolutionRepository | Repositorios SQLite, PrivateReportDraftStore | Lista, detalle, alta, edición y gestión implementados |
| map | GeoPoint, LocationGateway, MapReportRepository | GeolocatorGateway, SqliteMapReportRepository, caché de teselas | CityMapPage y LocationPickerPage implementados |
| statistics | StatisticsFilter, LocalStatistics, StatisticsGroup | SqliteStatisticsRepository | StatisticsPage y filtros independientes implementados |
| profile | Usuario autenticado, MyReportsRepository | AuthRepository, SqliteMyReportsRepository | Nombre, logout y Mis reportes implementados |

## Persistencia

`AppDatabase` abre SQLite privado con Drift. `assets/database/schema_v1.sql`
contiene tablas, restricciones, índices y ocho categorías estables. La versión 2
añade `revision`, índice de visibilidad y `report_revisions` para conservar
instantáneas privadas y referencias a fotos antes y después de modificar datos.
La migración 1 → 2 preserva registros y rutas existentes. Las instantáneas de
reportes heredados se capturan al modificarlos por primera vez.

`ReportDao` convierte filas SQL a modelos tipados. `SqliteReportRepository`
implementa creación, lectura pública, edición con revisión esperada y borrado
lógico. Las consultas usan parámetros y las escrituras validan sesión, permisos,
categoría, campos y existencia de fotos. Auditoría, historial y versiones se
guardan en la misma transacción. El repositorio no elimina archivos al editar.
Las futuras tareas de limpieza deben respetar también las referencias históricas.

`LocalUserStore` persiste identidades previamente verificadas; no autentica ni
permite seleccionar rol. `LocalSession` toma el UID del adaptador de sesión y lee
el rol desde SQLite para cada operación. Las pruebas usan sesiones y almacén de
fotos controlados; no hay acceso simulado expuesto en la aplicación.

La pestaña Reportes consulta la base y ofrece el catálogo persistente. `watchQuery` registra
suscripciones antes de consultar y recibe notificaciones de Drift al confirmar
transacciones; los cambios abortados no se publican.

No modificar migraciones distribuidas: agregar versiones incrementales y probar
conservación de registros y rutas. El esquema SQL se mantiene explícito, sin
generación de código; los tipos se aplican en DAOs y modelos de dominio.

## Fotos y alta (TASK-006)

`PrivatePhotoStorage` implementa PhotoStorage en la misma raíz privada que
`PrivatePhotoReader`. Decodifica JPEG/PNG/WebP en un isolate, valida tamaño y
dimensiones, corrige orientación y copia los píxeles a una imagen RGB nueva para
no trasladar metadatos. Escribe un archivo `.part`, verifica los bytes y renombra
a `photos/UUID.jpg`. Ante un fallo, limpia sus copias conocidas y deja el original
intacto. `ReportMediaReferences` impide borrar rutas aún usadas por reportes,
evidencias o snapshots privados de auditoría.

`AndroidPhotoSelection` recupera resultados perdidos desde el arranque y ofrece
cámara/galería con límites. `ReportComposerCubit` conserva formulario y fotos en
un borrador por cuenta; `PrivateReportDraftStore` serializa lectura/escritura para
evitar carreras al salir y volver rápidamente. El marcador del selector incluye
la cuenta propietaria; no se entregan fotos recuperadas a otra cuenta.

`NewReportPage` valida, permite revisar y publica solo por acción explícita. Su
estado se reconstruye por UID al cambiar la cuenta. No incluye sesiones falsas.
Se usa un requestId UUID v4 estable como id del reporte: la transacción de creación
detecta reintentos del mismo autor sin repetir INSERT ni auditoría. Tras confirmar
se abre el detalle, cuyo botón de regreso también funciona al entrar desde el alta.

El adaptador de `PhotoStorage` debe copiar la foto al directorio privado,
validar formato real, tamaño y lectura, y devolver ruta relativa. Nunca confiar
solo en extensión/MIME declarado. Si falla: mostrar el mensaje definido por
`PhotoStorageException`, conservar el formulario y pedir volver a adjuntarla.
No guardar reportes incompletos. Si falla SQLite tras copiar fotos, conservar las
copias referenciadas por el borrador para reintentar; limpiar solo al quitar fotos
o descartar, y respetar referencias de reportes, propuestas e historial.
Si falta una foto de un reporte existente, mostrar el error y permitir al autor
o admin reemplazarla con auditoría; no eliminar el reporte silenciosamente.

## Mapas y ubicación (TASK-003)

`GeoPoint` valida coordenadas finitas y calcula la distancia al centro aproximado
de El Alto. Se advierte a más de 30 km, sin bloquear selección ni afirmar límites
municipales. La proyección visual limita latitudes a la cobertura de Web Mercator;
las coordenadas introducidas se conservan sin modificación. Los toques normalizan
longitud si se navega a una copia del mundo.

`LocationGateway` desacopla permisos y posición nativa. `GeolocatorGateway` solicita
solo posiciones puntuales y únicamente tras «Mi ubicación». Se manejan denegación,
bloqueo permanente, servicio apagado y espera máxima de 15 segundos para obtener
posición. No se registra seguimiento continuo ni ubicación en segundo plano.
`LocationCubit` impide que una respuesta GPS tardía reemplace una corrección manual.

`MapCanvas` usa flutter_map con teselas HTTPS de OpenStreetMap, User-Agent propio,
atribución visible y enlace de licencia. El proveedor incluye caché HTTP nativa,
limitada a aproximadamente 200 MiB al inicializarse. Se usa panBuffer=0 para evitar
precargar alrededor de la vista; no hay descarga masiva ni función de mapas offline.
El tamaño del caché puede superar el objetivo durante una sesión y Android puede
limpiarlo; no se promete disponibilidad offline. Al fallar teselas se ofrece
reintentar recreando la capa, sin eliminar la selección ni bloquear coordenadas.

Los tests inyectan proveedor de teselas y ubicación para evitar tráfico real y
diálogos de sistema. Los marcadores se consultan reactivamente desde SQLite,
excluyen eliminación lógica y no incluyen UID/correo. El detalle completo y los
filtros compartidos con listado están implementados en TASK-004.

## Consulta de reportes (TASK-004)

`ReportFilterCubit` pertenece a la aplicación y conserva búsqueda, categoría,
estado, fechas y orden al cambiar entre mapa y lista o volver del detalle.
Se restablece al reiniciar la aplicación; no modifica los reportes.
`ReportQueryDao` es la consulta compartida para ambas vistas. Aplica eliminación
lógica, categoría, estado y fechas mediante parámetros SQL, con orden estable
por creación e identificador. La búsqueda literal en título/descripción usa
minúsculas Unicode de Dart para cubrir mayúsculas españolas; no elimina tildes.
Al tratarse de un MVP local, busca en memoria sobre las filas filtradas; una base
grande requerirá índices de búsqueda y paginación antes de centralizar datos.

Las fechas de UI son días locales: inicio inclusivo y medianoche del día siguiente
al final como límite exclusivo, convertidos a UTC. Se usa calendario en español.
`SqliteReportReadRepository` publica tarjetas y detalle con historial/propuestas
sin exponer UID, correo ni identidad interna de actores. El detalle deja de estar
disponible si se elimina el reporte. Los tiempos se actualizan cada minuto mientras
la vista está abierta y se acotan a cero si el reloj retrocede.

`PrivatePhotoReader` abre rutas relativas a `getApplicationDocumentsDirectory()`;
rechaza rutas externas y enlaces que salgan del directorio privado. La
importación de TASK-006 usa esa misma raíz y guarda rutas como `photos/UUID.jpg`.
`ReportPhoto` permite ampliar con zoom y muestra recuperación si falta el archivo
o no se puede decodificar. No muestra rutas internas ni borra datos al fallar.

Referencia: [política oficial de teselas OSM](https://operations.osmfoundation.org/policies/tiles/).
Seleccionar proveedor para despliegue masivo antes de lanzamiento público.

## Autenticación (TASK-005)

El usuario configuró Firebase y comprobó el acceso en Android. La configuración
local se mantiene fuera del repositorio.
`FirebaseGoogleGateway` conecta Google Sign-In con Firebase Auth mediante opciones
explícitas y client ID OAuth web. Sin configuración no inicializa SDK ni permite
login; se mantiene la lectura como visitante. Ver `docs/firebase-setup.md`.

`GoogleAuthRepository` serializa cambios de identidad, persiste metadatos privados
y nombre elegido, publica el usuario actual y mantiene el UID de `LocalSession`.
No almacena tokens en SQLite. Las notificaciones duplicadas del SDK no duplican
LOGIN; una operación de login pendiente se invalida al cerrar sesión. Se intenta
limpiar la sesión del SDK aunque falle la auditoría de LOGOUT. La restauración
usa la identidad persistida del SDK, no la existencia de una fila en `users`.

El rol procede del claim booleano `admin` en el token Firebase. Si los claims no
se pueden leer por red/timeout no se concede admin. La actualización del rol se
audita como ROLE_REFRESHED; el nombre público no permite elegir permisos.
`AuthCubit` evita envíos duplicados y expone errores sin tokens ni detalles del SDK.
La protección de rutas conserva `/nuevo` durante Google y elección de nombre;
los destinos de retorno están limitados a rutas internas conocidas. Se puede
posponer el nombre para explorar, pero no para ejecutar acciones protegidas.

`SqliteMyReportsRepository` filtra por el UID activo dentro de SQL y comprueba que
la cuenta no cambió durante la consulta. Las escrituras de reportes también
revalidan la identidad tras la validación asíncrona de fotos.

Google/Firebase debe configurarse para `bo.elalto.reporte_ciudadano_mvp` con sus
firmas de desarrollo y publicación. No usar nombre, correo introducido por el
usuario ni un botón de UI para dar rol admin.
En esta fase local, un administrador gestionará solo los datos de su teléfono.
La app web futura necesitará API y datos compartidos antes de aprobar reportes
de otros dispositivos.

## Administración y auditoría (TASK-007)

`SqliteResolutionRepository` carga una proyección privada para la sesión actual:
permisos sobre el reporte, datos de edición y propuestas propias (todas para admin).
El detalle público conserva su proyección sin UID/correo. Las rutas protegidas
mantienen el destino de gestión durante login/nombre y restringen el informe a admin.
Las pantallas reconstruyen o esconden su contenido al cambiar de cuenta o rol.

Proponer exige nota, evidencia privada existente y un UUID de solicitud; una sola
propuesta pendiente por usuario/reporte. El UUID permite repetir una solicitud ya
confirmada sin duplicar propuesta ni evento. La aprobación verifica admin, reporte
visible, propuesta pendiente y evidencia. En una única transacción guarda revisión,
aprobación, rechazos de otras pendientes, resolved_at UTC, estado, historial y
eventos. Cualquier fallo de auditoría revierte todo. Rechazar no cambia el reporte.
Reabrir conserva aprobaciones anteriores, vacía resolved_at y exige nueva propuesta
para resolver otra vez. Los cambios de estado y edición invalidan revisiones antiguas.

`ReportDao.saveRevision` se comparte entre edición, estados y borrado lógico. Las
fotos reemplazadas conservan referencias históricas y generan PHOTO_REPLACED además
de REPORT_UPDATED. Eliminar nunca elimina archivos ni propuestas.

`ReportManagementPage` ofrece seguimiento, propuesta y revisión con motivo;
`EditReportPage` edita campos, categoría, ubicación, atribución y fotografías. Sus
cambios sin confirmar son temporales, a diferencia del borrador persistente de alta.
El marcador de selección de gestión se distingue del marcador de alta para no
adjuntar resultados perdidos al formulario equivocado. No se promete recuperar
ediciones ni propuestas sin enviar después de que Android cierre el proceso.

`SqliteAuditRepository` consulta eventos con parámetros y exige admin en cada
lectura. Incluye entidades eliminadas; devuelve hasta 500 filas recientes por
consulta, con orden estable. `AuditPage` agrupa las filas mostradas por acción,
actor y tipo de entidad; filtra fechas locales como intervalo UTC semiabierto.
La exportación consiste en CSV seleccionable/copiable de los resultados visibles;
escapa separadores/comillas y neutraliza fórmulas de hojas de cálculo. No escribe
archivos externos ni comparte automáticamente información privada. Los filtros
permiten acotar períodos para consultas mayores. No hay sincronización ni app web
administrativa todavía.

## Estadísticas (TASK-008)

`SqliteStatisticsRepository` publica agregados públicos de todas las cuentas de este
teléfono, sin seleccionar UID, título, correo, notas ni fotografías. Una consulta
une reportes con categorías, excluye eliminación lógica y filtra categoría/origen
mediante parámetros. Evita unir fotos o propuestas para no multiplicar conteos.
Las fechas se comparan como instantes Dart, conservando límites inclusivo/exclusivo
con timestamps ISO de distinta precisión. El procesamiento es en memoria para el
MVP local; bases grandes requerirán agregación/paginación en otro adaptador.

Los conteos, categorías y tiempos locales nunca se mezclan con demostración.
`LocalStatistics.demo` solo existe cuando el usuario lo solicita; incluso vacío
tiene su propia sección y aviso. Categorías históricas inactivas conservan sus
conteos. El filtro de fechas se refiere a creación y admite intervalos abiertos
en el contrato; la UI convierte los días elegidos a UTC, hasta medianoche del día
siguiente al final.

Pendientes son Reportado y En seguimiento. Su media y máximo se calculan desde
creación hasta el instante `asOf`. Resolución usa creación hasta `resolved_at`
solo para reportes actualmente solucionados; una reapertura los saca de la muestra
y una nueva aprobación usa la última resolución. No se promedian eventos del
historial. Duraciones negativas por reloj retrasado se acotan a cero. Una media
sin muestra es nula y la UI la distingue de una medición de cero.

El repositorio se suscribe antes de leer y serializa recargas por commits de
reportes/categorías y por un temporizador de un minuto. La cancelación libera
notificaciones y temporizador; cambios SQL abortados no generan indicadores nuevos.
Los constructores permiten inyectar reloj y ticks para verificar tiempos sin esperas.
Las suscripciones de la pantalla están fuera del contenido desplazable para
mantenerse al recorrer filtros, gráficos y resultados.

`StatisticsFilterCubit` vive durante la sesión de la app, conserva categoría,
período y opción demo al navegar y se reinicia al relanzar. Es independiente de
`ReportFilterCubit`. La pantalla reemplaza resultados por un estado de carga al
cambiar filtros, ofrece reintento ante error y mantiene conteos cero con acceso
a Crear cuando no hay datos. El aviso «Estadísticas locales; no representan a
toda la ciudad» permanece explícito; no se presenta como evaluación institucional.
