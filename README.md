# Reportes ciudadanos de El Alto

Base Flutter Android de un MVP con SQLite privado. Repositorio:
[joseluiszamora/reporte_ciudadano_mvp](https://github.com/joseluiszamora/reporte_ciudadano_mvp).

## Estado actual

Incluye proyecto Android, tema, cinco rutas navegables y persistencia SQLite:
repositorios de categorías y reportes, CRUD con eliminación lógica, permisos,
auditoría y versiones privadas. La base migra de v1 a v2 conservando los datos.
La pestaña Reportes muestra tarjetas con foto principal, categoría, ubicación,
estado y antigüedad. Permite buscar en título/descripción y filtrar por categoría,
estado y fechas de creación, con orden reciente/antiguo. Los mismos filtros se
conservan al cambiar al mapa. El catálogo está en «Ver categorías».

La pestaña Mapa incorpora OpenStreetMap centrado en El Alto, marcadores de los
reportes locales por categoría/estado y acceso al detalle al pulsarlos. «Elegir ubicación»
abre el selector: toque para colocar/corregir el pin, coordenadas manuales y GPS
opcional. El punto se devuelve al mapa; todavía no crea ni guarda un reporte.

El detalle incluye autor público o anónimo, galería ampliable, mapa, fechas,
tiempos e historial con propuestas. Si falta una foto, muestra un aviso y permite
reintentar. Los reportes eliminados no se muestran en lista, mapa ni detalle.

Incluye flujo de acceso Google/Firebase, elección de nombre público, cierre de
sesión, rutas protegidas y Mis reportes. **Falta crear y configurar el proyecto
Firebase para usar cuentas reales**; sin configuración se puede explorar como
visitante. Ver [configuración Firebase](docs/firebase-setup.md).

El formulario de alta incluye categoría, título, descripción, cámara/galería,
ubicación corregible, anonimato y vista previa antes de publicar. Guarda las fotos
en privado como JPEG de hasta 2048 px y retira metadatos; conserva borradores por
cuenta y evita duplicados al reintentar. Requiere sesión Google y nombre público.

Todavía no incluye revisión administrativa ni estadísticas. No contiene usuarios ni
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

La integración de Google/Firebase está preparada; requiere la configuración local
descrita en `docs/firebase-setup.md`. El rol admin proviene de un claim de Firebase.
No publicar tokens ni claves de firma. El nombre público se elige después de Google.
El admin local solo puede gestionar los datos presentes en su teléfono.
La administración web futura requiere backend y sincronización.

Se conserva información de acciones mediante auditoría y eliminación lógica.
SQLite y fotos se perderán al borrar datos de la aplicación o desinstalarla;
esta versión no incluye respaldo ni sincronización.
