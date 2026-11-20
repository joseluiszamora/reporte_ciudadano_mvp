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

## Aceptación manual pendiente

1. Instalar el APK y entrar como visitante a Estadísticas sin configurar Firebase.
2. Con datos locales, contrastar conteos con lista/mapa y verificar las categorías.
3. Probar un rango de días en la zona horaria del teléfono y restablecerlo.
4. Cambiar pestañas y comprobar conservación de filtros y posiciones independientes.
5. Esperar un minuto, o volver después de seguimiento/aprobación/reapertura/eliminación, y contrastar tiempos y muestras.
6. Verificar separación demo si existen registros de demostración identificados.
7. Ampliar texto y recorrer todos los indicadores sin recortes ni pérdida de controles.

No se realizó prueba en un teléfono real durante esta entrega. Firebase sigue pendiente para crear reportes y validar cuentas/claims reales; consultar estadísticas de los datos ya guardados no requiere login. Los indicadores no evalúan atención institucional ni representan información de otros dispositivos.

Rama: `codex/TASK-008-estadisticas`, basada en `4889380`. Próxima fase: TASK-009 (compartir, accesibilidad y aceptación/calidad del APK).