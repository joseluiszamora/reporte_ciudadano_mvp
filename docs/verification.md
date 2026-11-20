# Verificación de TASK-003

- `flutter test --no-pub --concurrency=1 --reporter=expanded`: 39 pruebas aprobadas.
- `flutter build apk --debug --no-pub`: APK final compilado correctamente.
- Formato Dart verificado sin cambios pendientes.
- `flutter analyze --no-pub`: sin problemas.

## Cobertura automatizada

La suite conserva las pruebas SQLite de TASK-002 y añade:

- Apertura del mapa sin solicitar permiso GPS.
- Marcadores con coordenadas y categoría leídos desde SQLite; exclusión de eliminados.
- Selección por toque después del intervalo de doble toque; confirmación deshabilitada
  hasta elegir un punto y devolución de coordenadas al cerrar el selector.
- Entrada manual con decimal por punto o coma tras denegar GPS.
- Denegación permanente, servicio apagado, posición obtenida y timeout del adaptador nativo.
- Corrección manual que prevalece sobre una respuesta GPS tardía; cierre con GPS pendiente.
- Reenfoque incluso si el GPS devuelve las mismas coordenadas.
- Advertencia de distancia sin bloquear confirmación.
- Resumen al pulsar marcador, etiquetado demo y atribución visible.
- Teselas que fallan y reintento que recrea el proveedor sin perder el selector.
- Selector en pantalla 360 × 640 con texto al 130 %, error GPS y advertencia de distancia.

Los tests de mapa usan teselas en memoria y un gateway controlado; no descargan
teselas ni solicitan permisos reales. La prueba de error provoca deliberadamente
mensajes «Invalid image data»; verifica después que el reintento funcione.
No sustituyen la comprobación de GPS y conectividad en un teléfono Android.

## Revisión manual del APK

1. Abrir sin haber concedido ubicación: el mapa debe centrarse en El Alto sin diálogo GPS.
2. Mover y ampliar el mapa; verificar atribución visible y enlace de OpenStreetMap.
3. Pulsar «Elegir ubicación»: comprobar que no permite confirmar sin elegir un punto.
4. Tocar el mapa, corregir el pin y confirmar; el punto debe aparecer en la vista principal.
5. Pedir «Mi ubicación», denegar el permiso y seleccionar por toque o coordenadas.
6. Con permiso bloqueado o GPS apagado, comprobar mensajes y acceso a ajustes.
7. Quitar Internet y navegar a una zona no almacenada: debe mostrar el fallo y permitir
   introducir coordenadas y cambiar a Reportes. Restaurar red y pulsar «Reintentar».
8. Introducir 0,0: mostrar advertencia de distancia y permitir confirmar.
9. Volver atrás sin confirmar: conservar la selección anterior.

No se siembran reportes ni usuarios: los marcadores aparecen cuando existen datos
locales. La creación de reportes desde formulario corresponde a TASK-006; el detalle
completo y los filtros, a TASK-004. La selección actual no crea reportes ni se guarda
como reporte: se devuelve al mapa y está preparada para reutilizarse en el formulario.

APK: `build/app/outputs/flutter-apk/app-debug.apk`.
Rama: `feature/TASK-003-mapa-ubicacion`. Sin commit ni push.
No se realizó revisión manual en dispositivo durante esta entrega.
