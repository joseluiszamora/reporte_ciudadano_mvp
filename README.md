# Reportes ciudadanos de El Alto

Base Flutter Android de un MVP con SQLite privado. Repositorio:
[joseluiszamora/reporte_ciudadano_mvp](https://github.com/joseluiszamora/reporte_ciudadano_mvp).

## Estado actual

Incluye proyecto Android, tema, cinco rutas navegables y persistencia SQLite:
repositorios de categorías y reportes, CRUD con eliminación lógica, permisos,
auditoría y versiones privadas. La base migra de v1 a v2 conservando los datos.
La pestaña Reportes muestra las ocho categorías leídas desde SQLite.

La pestaña Mapa incorpora OpenStreetMap centrado en El Alto, marcadores de los
reportes locales por categoría/estado y resumen al pulsarlos. «Elegir ubicación»
abre el selector: toque para colocar/corregir el pin, coordenadas manuales y GPS
opcional. El punto se devuelve al mapa; todavía no crea ni guarda un reporte.

Todavía no incluye las pantallas de listado/alta de reportes, acceso con Google,
captura de fotos, revisión administrativa ni estadísticas. El CRUD se encuentra
en la capa de datos y se verifica mediante pruebas. No contiene usuarios ni
credenciales de demostración que aparenten autenticación real.

## Ejecutar y verificar

Requisitos: Flutter 3.47.3 / Dart 3.13.3 o compatibles, SDK Android y dispositivo
o emulador Android. Desde la raíz:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```

APK de depuración: `build/app/outputs/flutter-apk/app-debug.apk`.
La firma de publicación aún no está configurada; no distribuir el build release
con la firma de depuración que incluye la plantilla Android.

## Archivos principales

- [Especificación funcional](mvp-reportes-ciudadanos-el-alto.md)
- [Decisiones, permisos y límites](docs/business-rules.md)
- [Arquitectura e integraciones pendientes](docs/architecture.md)
- [Plan por tarea y criterios de aceptación](docs/implementation-plan.md)
- `assets/database/schema_v1.sql` y `schema_v2.sql`: esquema, categorías y migración.
- `lib/app/`: aplicación, rutas y tema.
- `lib/core/`: base de datos, medios y validaciones.
- `lib/features/`: contratos y políticas por dominio.
- `lib/shared/`: componentes de presentación compartidos.
- `test/`: navegación, políticas y restricciones/transacciones SQLite.

## Configuración futura

Google/Firebase y el UID administrador se integrarán en TASK-005. No publicar
tokens ni claves de firma. El nombre público se elige después de Google.
El admin local solo puede gestionar los datos presentes en su teléfono.
La administración web futura requiere backend y sincronización.

Se conserva información de acciones mediante auditoría y eliminación lógica.
SQLite y fotos se perderán al borrar datos de la aplicación o desinstalarla;
esta versión no incluye respaldo ni sincronización.
