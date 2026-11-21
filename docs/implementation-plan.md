# Plan y aceptación

El MVP local quedó aceptado el 20 de noviembre de 2026. El usuario probó el APK
`1.0.0+3` en su dispositivo Android y confirmó que la app funciona correctamente.
Las nueve fases están finalizadas. La evidencia y los escenarios para repetir la
validación están en la [guía de verificación](verification.md#aceptación-final-en-android).

| Tarea | Estado | Entrega |
|---|---|---|
| TASK-001 Base Android | Finalizada | Proyecto Flutter, navegación y APK interno |
| TASK-002 SQLite | Finalizada | Persistencia, integridad y migración |
| TASK-003 Mapa | Finalizada | Mapa, GPS y selector manual de ubicación |
| TASK-004 Reportes | Finalizada | Lista, búsqueda, filtros y detalle |
| TASK-005 Google y perfil | Finalizada | Inicio de sesión con Google, nombre público y Mis reportes |
| TASK-006 Alta y fotos | Finalizada | Formulario, borradores, ubicación y fotografías |
| TASK-007 Administración | Finalizada | Gestión, propuestas, historial e informe privado |
| TASK-008 Estadísticas | Finalizada | Indicadores locales, filtros, tiempos y sección demo |
| TASK-009 Calidad | Finalizada | Resumen compartible, controles de galería y APK de aceptación |

Trabajar en ramas feature/TASK-xxx-descripcion. Cada entrega incluye aceptación
manual y evidencias; probar permisos en repositorio, no solo ocultar botones.
No cerrar tareas por la existencia de carpetas o pantallas informativas.

Criterio de validación del prototipo: completar en Android un registro con foto
y pin, recuperar datos tras reiniciar, proponer sin resolver automáticamente,
aprobar como admin con historial, y consultar indicadores locales correctos.
Repetir con GPS denegado, foto que falla, perfil incompleto y usuario sin permisos.
