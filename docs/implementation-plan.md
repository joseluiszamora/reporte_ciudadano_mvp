# Plan y aceptación

Las nueve fases de desarrollo del MVP local están implementadas. La aceptación
manual se realiza en conjunto con la compilación final siguiendo la
[guía de verificación](verification.md#aceptación-final-en-android).

| Tarea | Estado | Cierre requerido |
|---|---|---|
| TASK-001 Base Android | Base generada | Analyze, tests, APK y revisión en dispositivo |
| TASK-002 SQLite | Persistencia implementada y cubierta por pruebas | Validación manual del APK en dispositivo pendiente |
| TASK-003 Mapa | Mapa y selector implementados; verificación automatizada | Revisión manual de APK, GPS real y conectividad en Android |
| TASK-004 Reportes | Lista, búsqueda, filtros y detalle implementados | Revisión manual del APK y de fotografías reales en Android |
| TASK-005 Google y perfil | Inicio con Google comprobado por el usuario en Android | Revisar retiro del claim, cambio de cuenta y firma de distribución |
| TASK-006 Alta y fotos | Alta de reportes comprobada por el usuario en Android | Revisar denegaciones y recuperación tras interrumpir la cámara |
| TASK-007 Administración | Gestión, propuestas, revisión atómica e informe privado implementados y cubiertos por pruebas | Revisar permisos/claims y evidencias en Android real |
| TASK-008 Estadísticas | Indicadores, filtros, tiempos y separación demo implementados y cubiertos por pruebas | Verificación manual de fechas locales, tiempos, lectura ampliada y actualización en Android |
| TASK-009 Calidad | Resumen compartible, navegación accesible de fotos y APK interno | Verificar hoja de compartir, TalkBack y permisos en Android real |

Trabajar en ramas feature/TASK-xxx-descripcion. Cada entrega incluye aceptación
manual y evidencias; probar permisos en repositorio, no solo ocultar botones.
No cerrar tareas por la existencia de carpetas o pantallas informativas.

Criterio de validación del prototipo: completar en Android un registro con foto
y pin, recuperar datos tras reiniciar, proponer sin resolver automáticamente,
aprobar como admin con historial, y consultar indicadores locales correctos.
Repetir con GPS denegado, foto que falla, perfil incompleto y usuario sin permisos.
