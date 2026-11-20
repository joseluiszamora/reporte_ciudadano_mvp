# Plan y aceptación

No se considera completado el MVP con esta estructura.

| Tarea | Estado | Cierre requerido |
|---|---|---|
| TASK-001 Base Android | Base generada | Analyze, tests, APK y revisión en dispositivo |
| TASK-002 SQLite | Persistencia implementada y cubierta por pruebas | Validación manual del APK en dispositivo pendiente |
| TASK-003 Mapa | Mapa y selector implementados; verificación automatizada | Revisión manual de APK, GPS real y conectividad en Android |
| TASK-004 Reportes | Lista, búsqueda, filtros y detalle implementados | Revisión manual del APK y de fotografías reales en Android |
| TASK-005 Google y perfil | Integración y flujos implementados; configuración Firebase pendiente | Crear proyecto Firebase y verificar login/firmas/claims reales en Android |
| TASK-006 Alta y fotos | Formulario, vista previa, fotos y borradores implementados | Configurar Firebase y revisar cámara/galería y reinicio en Android real |
| TASK-007 Administración | Gestión, propuestas, revisión atómica e informe privado implementados y cubiertos por pruebas | Configurar Firebase y revisar permisos/claims y evidencias en Android real |
| TASK-008 Estadísticas | Pendiente | Filtros, tiempos, exclusión de eliminados y separación demo |
| TASK-009 Calidad | Pendiente | Compartir, accesibilidad, permisos, APK interno y revisión manual |

Trabajar en ramas feature/TASK-xxx-descripcion. Cada entrega incluye aceptación
manual y evidencias; probar permisos en repositorio, no solo ocultar botones.
No cerrar tareas por la existencia de carpetas o pantallas informativas.

Criterio de validación del prototipo: completar en Android un registro con foto
y pin, recuperar datos tras reiniciar, proponer sin resolver automáticamente,
aprobar como admin con historial, y consultar indicadores locales correctos.
Repetir con GPS denegado, foto que falla, perfil incompleto y usuario sin permisos.
