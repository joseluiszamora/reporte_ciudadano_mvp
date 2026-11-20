# Verificación de TASK-007

- Suite completa: `flutter test --no-pub --concurrency=1 --reporter=expanded`: 101 pruebas aprobadas (80 anteriores y 21 nuevas).
- `flutter analyze --no-pub`: sin problemas.
- `flutter build apk --debug --no-pub`: APK de depuración compilado.
- Formato Dart y diferencias Git verificados.

## Funcionalidad entregada

Desde Detalle → Acciones y propuestas, el ciudadano envía nota y fotografía de solución sin resolver el reporte. Puede editar su reporte mientras esté Reportado y eliminarlo lógicamente con motivo. El admin edita cualquier reporte visible, inicia/devuelve seguimiento, revisa propuestas y reabre reportes resueltos.

Aprobar actualiza propuesta, reporte, resolución UTC, revisiones, historial y auditoría en una transacción, rechazando las demás pendientes como sustituidas. Reabrir mantiene la resolución anterior en historial y exige nueva evidencia para aprobar otra vez. Se conservan fotos reemplazadas y reportes eliminados.

En Perfil → Informe de acciones, el admin consulta eventos, incluidos los de reportes eliminados, por UID, acción, entidad, fecha y origen demo. Se resumen hasta 500 eventos recientes por consulta y se permite copiar CSV con las mismas filas. La exportación es texto privado para copiar/guardar, no un archivo enviado automáticamente ni una función de compartir.

## Evidencia automatizada nueva

- 12 pruebas del repositorio: permisos, perfil completo, evidencia obligatoria, UUID idempotente, límite de pendientes por usuario, aislamiento de propuestas, aprobación atómica, sustitución de pendientes y doble revisión impedida.
- Fallo de auditoría revierte aprobación, rechazos, estado, historial y versiones.
- Rechazo sin cambio de estado, reapertura y segunda resolución con evidencia nueva.
- Revisión esperada, transición directa a Solucionado prohibida y reporte eliminado inaccesible para nuevas acciones. Se comprueba sesión tras verificar evidencia.
- Revisiones demo y eventos identificados; falta de archivo impide aprobar.
- 4 pruebas del informe: acceso admin, rol consultado en cada lectura, filtros y límites de fechas, parámetros SQL, conservación tras eliminación, límite de 500, CSV con comillas/saltos de línea y neutralización de fórmulas.
- 3 pruebas de interfaz con SQLite y proveedores controlados: proponer como ciudadano, cambiar a admin, aprobar con motivo válido, reabrir y eliminar; editar título/foto conservando referencias históricas; consultar/exportar auditoría y ocultarla al cambiar a una cuenta ciudadana.
- 2 pruebas de rutas: retorno seguro tras login/nombre y bloqueo del informe a ciudadanos.

Los proveedores simulados de identidad y fotos existen únicamente en tests. El APK no incluye una cuenta admin ficticia ni evita la autenticación Google.

## Aceptación manual pendiente

1. Crear/configurar Firebase según `docs/firebase-setup.md`; confirmar login real.
2. Probar la misma cuenta con y sin claim `admin`, incluyendo su retiro.
3. Proponer con cámara/galería reales, cancelar y probar error de fotografía.
4. Como ciudadano, verificar que no hay revisión administrativa; como admin, iniciar seguimiento, aprobar/rechazar con motivo y reabrir.
5. Reiniciar y verificar estado, evidencia, historial y eventos conservados.
6. Editar campos/fotos; eliminar y verificar exclusión de mapa/lista/detalle y conservación del evento privado de eliminación.
7. Filtrar por fechas/actor/origen, copiar CSV y comprobarlo en el destino elegido.
8. Cambiar de cuenta con gestión o informe abiertos y comprobar ocultación inmediata.

No hay proyecto Firebase todavía, por confirmación del usuario. No se probaron claims, cámara ni galería en un teléfono real durante esta entrega. La aceptación manual permanece abierta. La administración es local al teléfono: la app web y el backend compartido siguen pendientes. Edición/propuesta sin enviar no son borradores persistentes; solo el alta cuenta con recuperación de TASK-006.

Rama: `codex/TASK-007-administracion`. Base conservada en `e217550`; esta fase se guarda en un nuevo commit local, sin push al remoto.