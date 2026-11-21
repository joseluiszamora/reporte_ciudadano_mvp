# Verificación de TASK-008

- Suite completa: `flutter test --no-pub --concurrency=1 --reporter=expanded`: 114 pruebas aprobadas (101 anteriores y 13 nuevas).
- `flutter analyze --no-pub`: sin problemas.
- `flutter build apk --debug --no-pub`: APK de depuración compilado.
- Formato Dart y diferencias Git verificados.

## Funcionalidad entregada

La pestaña Estadísticas está disponible como visitante. Muestra total, Reportados, En seguimiento y Solucionados; conteos y barras por categoría; antigüedad media y máxima de pendientes; promedio de resolución con tamaño de muestra.

Los filtros de categoría y fechas de creación son independientes del mapa/lista y permanecen al navegar durante la sesión. El intervalo de días locales se convierte a UTC con inicio inclusivo y final exclusivo. Categorías inactivas conservan sus registros históricos.

Reportes eliminados no contribuyen a ningún indicador. Los demo se excluyen por defecto y solo aparecen al activarlos, en su propia sección sin mezclar conteos ni promedios. Se muestra «Estadísticas locales; no representan a toda la ciudad».

Pendientes = Reportado + En seguimiento. Se miden desde creación hasta el momento del cálculo, con actualización por cambios de datos y cada minuto. Resolver usa creación hasta la última resolución, solo para reportes actualmente solucionados. Reabrir los retira del promedio; una nueva aprobación incorpora el nuevo tiempo. Se distingue una medición de cero de la ausencia de muestra.

## Evidencia automatizada nueva

Ocho pruebas del repositorio verifican:

- Base vacía, ceros y ausencia de muestras; lectura sin identidad.
- Conteos por estado/categoría y exclusión de eliminados en todas las métricas.
- Medias y máximos exactos, precisión menor a una hora y reloj retrasado acotado a cero.
- Filtros por creación, intervalos abiertos, límites UTC y fracciones de segundo con distinta precisión; categoría parametrizada e inactiva.
- Datos demo opcionales y separados, incluso con tiempos extremos o filtros sin datos reales.
- Reportes de varias cuentas y ausencia de multiplicación por fotos/propuestas.
- Flujo real de propuesta, aprobación, reapertura y segunda aprobación con fecha conservada de creación.
- Actualización por commit y ticks, ausencia de notificaciones de rollback y cancelación del temporizador.

Cinco pruebas de interfaz verifican:

- Visitante: aviso local, conteos cero y acceso a Crear pasando por login.
- Demo separado, filtro de categoría conservado al cambiar pestañas y búsqueda de reportes sin alteraciones.
- Calendario en español, días locales convertidos a UTC, filtros de fechas y restablecimiento.
- Reintento ante error y ocultación de resultados anteriores mientras llega una nueva consulta.
- Pantalla de 360 × 640 con texto al 200 %, desplazamiento hasta categorías y actualización de tiempos sin suscripciones duplicadas.

Los tests usan SQLite real en memoria, reloj/ticks controlados y proveedores de mapas sin tráfico de red. Los datos de prueba no se incluyen en el APK.

## Escenarios de regresión de estadísticas

1. Instalar el APK y entrar como visitante a Estadísticas sin configurar Firebase.
2. Con datos locales, contrastar conteos con lista/mapa y verificar las categorías.
3. Probar un rango de días en la zona horaria del teléfono y restablecerlo.
4. Cambiar pestañas y comprobar conservación de filtros y posiciones independientes.
5. Esperar un minuto, o volver después de seguimiento/aprobación/reapertura/eliminación, y contrastar tiempos y muestras.
6. Verificar separación demo si existen registros de demostración identificados.
7. Ampliar texto y recorrer todos los indicadores sin recortes ni pérdida de controles.

Después de esta entrega, el usuario confirmó que inició sesión con Google y registró reportes en Android. Consultar estadísticas no requiere login.

Rama histórica: `codex/TASK-008-estadisticas`, basada en `4889380`.

## TASK-009

La suite completa pasó 115 pruebas. El análisis estático quedó limpio y `apksigner`
verificó la firma del APK interno. La nueva prueba de interfaz cubre las etiquetas
de acciones, la cancelación, el anonimato y la eliminación durante la vista previa.

El resumen de texto se revisa antes de abrir la hoja nativa de Android. Incluye
datos del detalle público y marca los reportes demo. La acción vuelve a consultar
el reporte al confirmar y descarta un resumen que haya cambiado o se haya eliminado.
El texto no adjunta archivos ni agrega identificadores internos o enlaces al reporte.

El APK de depuración usa el código de versión 2. El manifiesto conserva Internet
y ubicación en primer plano. Compartir texto no necesita permisos nuevos. La cámara
y galería usan el selector del sistema, y el pin manual sigue disponible sin GPS.

Para repetir los escenarios en el teléfono, usar la configuración Firebase
validada y el mismo certificado que la instalación existente.

Referencias: [hoja de compartir de Android](https://developer.android.com/training/sharing/send?hl=es)
y [pruebas de accesibilidad en Flutter](https://docs.flutter.dev/ui/accessibility/accessibility-testing).

## Aceptación final en Android

El 20 de noviembre de 2026, el usuario confirmó que el APK `1.0.0+3` funciona
correctamente en su dispositivo Android y solicitó cerrar las nueve fases del MVP.
La suite completa registró 116 pruebas aprobadas. Tras consolidar el nuevo paquete,
pasaron 33 pruebas de regresión y el análisis estático. La firma del APK con
Firebase coincide con el SHA‑1 registrado para `com.mvp.reporte_ciudadano_mvp`.
Los escenarios de abajo se conservan como guía de regresión para futuras versiones.

Usar el APK interno de versión `1.0.0+3` compilado con el archivo Firebase ya
validado y el mismo certificado de la instalación que contiene tus reportes.
Actualizar sobre esa instalación para comprobar que se conservan SQLite y fotos.
La [guía de Firebase](firebase-setup.md) contiene los comandos y la asignación del rol admin.

| Escenario | Resultado esperado |
|---|---|
| Abrir como visitante y cargar ejemplos desde Perfil | Aparecen tres casos marcados como demo en mapa y lista. Repetir la acción no agrega duplicados. |
| Abrir Estadísticas antes y después de activar demostración | El total de reportes reales permanece igual. La sección demo muestra un caso por estado y 12 horas de resolución promedio. |
| Crear como visitante y completar Google y nombre público | El flujo vuelve al formulario. Cerrar sesión devuelve a modo visitante y «Mis reportes» se separa por cuenta. |
| Registrar un reporte con foto, pin y anonimato | La vista previa coincide con el detalle. Tras reiniciar se conservan el reporte y su foto. |
| Denegar GPS, cancelar la cámara y probar una foto que falle | El pin manual funciona, cancelar conserva el borrador y el fallo pide volver a adjuntar la foto. |
| Quitar Internet y abrir mapa y lista | El mapa permite reintentar. La lista y el detalle siguen mostrando los datos guardados. |
| Proponer una solución y revisar con un admin | La propuesta pendiente conserva el estado. Aprobar registra historial, revisión y fecha de solución. Un ciudadano no puede aprobar. |
| Reabrir, editar y eliminar | La reapertura retira el caso de la media de resolución. El borrado oculta el reporte y el admin conserva el evento en el informe y CSV. |
| Compartir el detalle de un reporte anónimo | La vista previa y la hoja nativa muestran el resumen sin datos de cuenta ni enlaces al reporte. Cancelar cierra el flujo. |
| Usar TalkBack y texto ampliado | Los controles de galería permiten avanzar y retroceder, y las acciones y resultados se pueden recorrer con el lector de pantalla. |

La carga demo es opcional y deliberadamente usa casos sin fotos. Para probar cámara,
galería, evidencia y el ciclo administrativo completo, crear un reporte de prueba
con las cuentas configuradas en tu Android.
