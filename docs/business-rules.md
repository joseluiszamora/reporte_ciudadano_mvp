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
PROPOSAL_APPROVED, PROPOSAL_REJECTED y PHOTO_REPLACED. Registrar actor UID,
rol al actuar, entidad, acción, fecha UTC, motivo, campos cambiados y origen demo.
Los cambios persistentes y su evento se guardan en una transacción.
El historial conserva estados antes/después y vínculo a propuesta. No registrar
tokens, credenciales, bytes de fotos ni correos en auditoría. El adaptador no
expondrá actualización/eliminación de eventos. Informes administrativos podrán
agrupar por actor, acción, fecha y entidad; el visor/exportador se implementa en TASK-007.

## Datos locales y demostración

No sembrar reportes reales ni usuarios. Categorías sembradas son catálogo.
Reportes demo usan is_demo y se distinguen por registro; su revisión es simulada.
Indicadores separan demo de datos propios y excluyen eliminados. Etiqueta base:
«Estadísticas locales; no representan a toda la ciudad»; agregar aviso demo al incluirlos.
Primera autenticación requiere Internet; sesión persistida permite trabajo local
si sigue disponible. No prometer renovar credenciales sin conexión. Mapas sin red
no bloquean lista local. Denegar GPS permite pin manual. Reinstalar puede perder datos.

## Búsqueda

TASK-004 incluye búsqueda local de título y descripción, sin distinguir mayúsculas,
combinada con filtros de categoría, estado y fechas. Mapa y lista comparten consulta.
