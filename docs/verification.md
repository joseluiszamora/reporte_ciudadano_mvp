# Verificación de TASK-004

- `flutter analyze --no-pub`: sin problemas.
- `flutter test --no-pub --concurrency=1 --reporter=expanded`: 48 pruebas aprobadas.
- `flutter build apk --debug --no-pub`: APK final compilado correctamente.
- Formato Dart verificado sin cambios pendientes.

## Cobertura

Se mantienen las pruebas de SQLite, migraciones, permisos y mapa de las fases
anteriores. Esta entrega añade comprobaciones de:

- Igualdad de identificadores y orden entre mapa y lista al combinar búsqueda,
  categoría, estado y límites de fecha. Mayúsculas españolas y búsqueda literal
  con `%` o texto similar a SQL.
- Conservación de categorías inactivas en consultas históricas y exclusión de
  reportes eliminados tanto en lista como en detalle.
- Proyección pública anónima e historial/propuestas sin actores internos.
- Navegación lista → búsqueda → mapa → detalle → regreso, conservando filtros.
- Filtro de estado sin coincidencias y restauración con «Limpiar filtros».
- Lectura privada de fotos, rechazo de rutas externas, archivo ausente y apertura
  del visor con zoom sobre una imagen real de prueba.
- Manejo de retroceso del reloj para el tiempo pendiente.
- Buscador con teclado Android en pantalla 360 × 640, sin desbordamiento.

Los datos se crean solo en fixtures de pruebas, no en el APK. Las teselas se
inyectan desde memoria y no se realizan descargas de mapas en las pruebas.

## Revisión manual

1. Abrir Reportes con la base vacía y comprobar el aviso y acceso a Crear reporte.
2. Abrir «Ver categorías» para consultar el catálogo local.
3. Abrir filtros, elegir estado/categoría/fechas y orden; aplicar y limpiar.
4. Escribir una búsqueda, cambiar al mapa y comprobar que el texto se conserva.
5. Con datos locales existentes, abrir una tarjeta o marcador y revisar autor
   público/anónimo, fotos ampliables, ubicación, tiempos e historial.
6. Si falta una foto, comprobar aviso, reintento y acceso al resto del reporte.
7. Sin Internet, verificar lista, filtros, detalle y fotos locales; el mapa puede
   mostrar un error recuperable por falta de teselas.

No se realizó revisión manual en dispositivo durante esta entrega. El formulario
de alta llegará en TASK-006; hasta entonces una instalación vacía no tiene reportes
de ejemplo ni usuarios simulados. Google y el UID administrador son TASK-005.

APK: `build/app/outputs/flutter-apk/app-debug.apk`.
Rama: `feature/TASK-004-reportes-detalle`.
El avance previo está guardado en `ef07714`; esta fase se guarda en un segundo
commit al cerrar la entrega. Los commits son locales, sin push al remoto.
