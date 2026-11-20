# Decisiones funcionales confirmadas

Estas reglas complementan la especificación inicial; prevalecen sobre sus
referencias anteriores a moderación futura o simulación exclusivamente administrativa.

## Identidad y permisos

- Google autentica; después se exige un nombre público elegido por la persona.
  No tiene que ser único. No copiar automáticamente el nombre de Google.
- Visitantes leen. Perfil incompleto no crea ni modifica datos. No pedir GPS para leer.
- Cada reporte elige nombre o anonimato. Guardar nombre público como instantánea
  del momento de publicar; una actualización del perfil no modifica reportes anteriores.
- Reportes anónimos muestran «Ciudadano anónimo» sin UID, correo ni foto de Google
  en tarjetas, detalle o al compartir. Auditoría e identidad interna son privadas.
- El autor edita título, descripción, categoría, fotos, ubicación y atribución solo
  mientras está REPORTADO y no eliminado. Registrar campos cambiados en auditoría.
- Admin gestiona reportes, revisa propuestas, edita y elimina con motivo.
  Rol asignado a un UID verificado mediante configuración controlada al integrar
  autenticación. Nadie puede elegir ser admin al crear su perfil. No hay admin
  de contraseña fija ni cuenta sembrada. En producción remota, permisos en servidor.

## Estados y propuestas

- Admin inicia seguimiento: REPORTADO → EN SEGUIMIENTO. Puede devolverlo a
  REPORTADO con motivo. Registrar toda transición.
- Ciudadano con perfil completo propone solución en reportes no eliminados ni
  resueltos; nota y fotografía obligatorias. No cambia automáticamente el estado.
- Una propuesta pendiente por usuario/reporte. Otros usuarios pueden presentar
  evidencia adicional. Admin aprueba o rechaza con motivo; no se revisa dos veces.
- Aprobar actualiza propuesta, reporte a SOLUCIONADO, fecha UTC de resolución,
  historial y auditoría en una transacción. Rechazar las demás pendientes con
  motivo «Sustituida por propuesta aprobada» en la misma transacción.
- Admin reabre SOLUCIONADO → EN SEGUIMIENTO con motivo; vaciar resolved_at.
  Conservar resoluciones anteriores en historial. Nueva resolución exige nueva
  propuesta. Tiempo mostrado al resolver: creación hasta la última resolución.
- Consultas y acciones excluyen reportes eliminados salvo informes de auditoría.
  Políticas de dominio deben comprobar además existencia, borrado y sesión actual
  dentro del repositorio antes de cada mutación.

## Límites

Texto recortado en extremos; contar puntos de código Unicode. Nombre 2–50,
título 10–100, descripción 20–2.000, notas y motivos 10–1.000 caracteres.
Entre 1 y 5 fotos por reporte; cada foto entre 1 byte y 10 MiB. JPEG, PNG o WebP;
validar decodificación real y retirar EXIF innecesario. Evidencia de solución: una
foto con los mismos límites. Latitud [-90,90], longitud [-180,180], valores finitos.
En alta se aceptan JPEG/PNG/WebP recibidos del selector, con hasta 20 megapíxeles
antes de procesar. Se corrige orientación, reduce el lado mayor a 2048 px y guarda
JPEG al 85 %, sin copiar EXIF/GPS/perfiles al archivo persistente. Los archivos
originales del usuario permanecen intactos.
Sin geocerca restrictiva. Advertir a más de 30 km del centro aproximado
(-16.5000, -68.1500); esto no representa límites oficiales.

## Eliminación y auditoría

Eliminación lógica por autor o admin, con motivo: deleted_at, deleted_by_uid,
deletion_reason. No borrar físicamente reportes, fotos, propuestas ni historial
como efecto de esta acción. Excluirlos de listados e indicadores normales.
La conservación local dura hasta una política posterior o borrado de datos de
la aplicación; no promete respaldo ni auditoría inviolable.

Registrar LOGIN, LOGOUT, PROFILE_COMPLETED, PROFILE_UPDATED, REPORT_CREATED,
REPORT_UPDATED, REPORT_DELETED, REPORT_STATUS_CHANGED, PROPOSAL_CREATED,
PROPOSAL_APPROVED, PROPOSAL_REJECTED, PHOTO_REPLACED y ROLE_REFRESHED. Registrar actor UID,
rol al actuar, entidad, acción, fecha UTC, motivo, campos cambiados y origen demo.
Los cambios persistentes y su evento se guardan en una transacción.
El historial conserva estados antes/después y vínculo a propuesta. No registrar
tokens, credenciales, bytes de fotos ni correos en auditoría. El adaptador no
expondrá actualización/eliminación de eventos. Informes administrativos podrán
agrupar por actor, acción, fecha y entidad. TASK-007 incluye visor privado y CSV
copiable de hasta 500 eventos recientes por consulta; los totales resumen solo
esas filas. Permite filtrar por UID, acción, entidad, fechas y origen demo, incluso
para reportes eliminados. Las fechas del informe son días locales y el CSV conserva UTC.

## Datos locales y demostración

No sembrar reportes reales ni usuarios. Categorías sembradas son catálogo.
Reportes demo usan is_demo y se distinguen por registro; su revisión es simulada.
Indicadores separan demo de datos propios y excluyen eliminados. Etiqueta base:
«Estadísticas locales; no representan a toda la ciudad»; agregar aviso demo al incluirlos.
Primera autenticación requiere Internet; sesión persistida permite trabajo local
si sigue disponible. No prometer renovar credenciales sin conexión. Mapas sin red
no bloquean lista local. Denegar GPS permite pin manual. Reinstalar puede perder datos.

## Borradores y fotografías (TASK-006)

El borrador es privado y se guarda por UID al cambiar campos o fotos. Cambiar de
cuenta reconstruye el formulario y carga únicamente el borrador correspondiente.
No se crea un reporte antes de confirmar la vista previa. Antes de abrir cámara o
galería se conserva el borrador y la cuenta asociada al selector. Los resultados
que Android recupere tras interrumpir la actividad solo se adjuntan a esa cuenta.

La publicación conserva un UUID estable del borrador. Reintentar el mismo UUID
devuelve el reporte ya creado para ese autor y no duplica fotos, historial ni
auditoría. Un UUID de otro autor o de un reporte eliminado no permite recrearlo.
Un fallo SQL mantiene el borrador y las copias privadas para reintentar; un fallo
de foto informa «Vuelve a adjuntarla» y no guarda un reporte incompleto.

Quitar una foto o descartar un borrador elimina solo copias sin referencias.
Nunca eliminar fotos usadas por reportes, propuestas o versiones históricas,
incluidos reportes eliminados lógicamente. No se garantiza respaldo del borrador
ni recuperación tras borrar datos de la app. Copias parciales de procesos
interrumpidos pueden permanecer privadas hasta una limpieza futura controlada.

## Búsqueda local

TASK-004 incluye búsqueda local de título y descripción, sin distinguir mayúsculas,
combinada con filtros de categoría, estado y fechas. Mapa y lista comparten consulta.

## Gestión local (TASK-007)

«Acciones y propuestas» requiere sesión y nombre completo. Ciudadanos ven sus
propias propuestas en gestión; el admin ve todas. El historial público sigue sin
identificadores internos de autores o proponentes. El admin accede al informe de
acciones desde Perfil. Los permisos se verifican en cada repositorio y no dependen
de que el botón esté visible. No se crea una cuenta admin sin identidad verificada.

La edición comprueba la revisión cargada para impedir sobrescrituras. El cambio
de estado también usa revisión esperada; resolver directamente está prohibido y
requiere aprobar evidencia. Se registra un evento por cada propuesta sustituida.
El identificador estable de envío evita duplicar una propuesta al reintentar.

Ediciones y propuestas sin enviar se conservan solo mientras la pantalla siga
abierta; la UI lo informa. Sus fotos nuevas usan las mismas comprobaciones privadas
del alta. Al salir se intenta retirar únicamente copias sin referencias; reportes,
evidencias enviadas y versiones anteriores permanecen protegidos. La recuperación
persistente de borradores de TASK-006 se aplica al alta, no a estos formularios.

## Indicadores locales (TASK-008)

Se consultan sin sesión y abarcan los reportes de todas las cuentas guardadas en
el teléfono. Excluir reportes eliminados de conteos, categorías y tiempos. Por
defecto no se leen datos demo; al activarlos se muestran conteos y promedios en una
sección separada, identificada como demostración, sin sumarlos a los reales.

Filtros: categoría (incluidas históricas inactivas) y fecha de creación. Los días
seleccionados son locales y se convierten a instantes UTC: inicio inclusivo y
medianoche posterior al día final exclusiva. Se conservan al navegar durante la
sesión, con opción de restablecer; no modifican filtros del mapa/lista.

Pendiente = Reportado o En seguimiento. La antigüedad media y máxima cuentan desde
creación hasta el momento del cálculo y se actualizan cada minuto o al cambiar
datos. Promedio de resolución = media de `resolved_at - created_at` de los reportes
actualmente solucionados dentro de los filtros. Reabrir retira ese reporte del
promedio; aprobar nuevamente usa su última resolución y conserva creación como
inicio. No contar propuestas pendientes como soluciones ni promediar resoluciones
históricas. Acotar a cero ante reloj retrasado; sin muestra, indicar su ausencia.

Cada reporte cuenta una sola vez aunque tenga varias fotos/propuestas. Categorías
se muestran con conteo legible y barra proporcional al total de su sección.
Base vacía muestra ceros y acceso a Crear, que exige login para publicar. No se
asignan instituciones ni se generan calificaciones de atención institucional.
