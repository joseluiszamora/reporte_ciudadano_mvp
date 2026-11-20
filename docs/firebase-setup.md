# Activar Google/Firebase en Android

El usuario confirmó que configuró Firebase y comprobó el acceso con Google y el
registro de reportes en Android. Cada entorno que compile con Google necesita su
configuración local. El APK sin ese archivo permite explorar como visitante.

## Configuración de proyecto

1. Crear un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Registrar una app Android con paquete `bo.elalto.reporte_ciudadano_mvp`.
3. En Authentication → proveedores, habilitar Google y definir el correo de soporte.
4. Registrar SHA-1 y SHA-256 del certificado de depuración y, antes de publicar,
   del certificado de producción. Desde `android/` se pueden consultar con
   `./gradlew signingReport` (Windows: `./gradlew.bat signingReport`).
5. Descargar nuevamente `google-services.json` después de habilitar Google.
   Debe contener un cliente OAuth web (`client_type: 3`), además del cliente Android.

La integración usa opciones explícitas de Firebase y `serverClientId` de Google;
no requiere añadir el plugin Gradle de Google Services ni subir configuración al
repositorio. El SDK de Firebase gestiona su propia persistencia de sesión.
Los módulos nativos FlutterFire se compilan con SDK 35 mediante `finalizeDsl` de
AGP; instalar esa plataforma junto a las que requiera la versión de Flutter.

## Generar configuración local

Desde la raíz, usando PowerShell:

```powershell
./tool/configure_firebase.ps1 -GoogleServicesPath 'C:/ruta/google-services.json'
flutter run --dart-define-from-file=config/firebase.android.json
flutter build apk --debug --dart-define-from-file=config/firebase.android.json
```

El script valida el paquete y obtiene API key del cliente, App ID Android,
ID de proyecto, número de proyecto y client ID OAuth web. Genera
`config/firebase.android.json`, excluido de Git. La plantilla de campos es
`config/firebase.android.example.json`; los valores vacíos no habilitan Google.
No colocar claves de cuentas de servicio, secretos OAuth ni tokens de usuario en
esa configuración. No hace falta crear Firestore ni una base de reportes remota.

## Administrador

El cliente acepta rol administrador únicamente cuando el token Firebase contiene
el custom claim booleano `admin: true`. Asignarlo desde un entorno de confianza con
Firebase Admin SDK al UID correcto, conservando los demás claims existentes.
No se asigna por nombre, correo escrito, selección de perfil ni archivo de UID
compilado en el APK. La app no incluye credenciales de administrador ni un botón
para promover usuarios. Tras asignarlo, cerrar sesión y entrar de nuevo.

Si no se pueden consultar los claims por falta de conexión, no se concede admin;
una identidad persistida puede seguir usando funciones locales como ciudadano.
La administración local de reportes está implementada en TASK-007. El backend futuro
deberá validar nuevamente permisos en servidor: SQLite no reemplaza esa validación.

## Comprobaciones adicionales en Android

- Cancelación y repetición del selector Google en un teléfono Android.
- Elección obligatoria del nombre público sin copiar el de Google.
- Retorno a Crear reporte después del login y del nombre.
- Cierre y reapertura de app, restauración de nombre y sesión, logout y cambio de cuenta.
- Mis reportes sin mezclar los de otras cuentas locales.
- Denegación de acceso y configuración/firma equivocada sin bloquear exploración.
- UID con y sin claim administrador, incluido retiro del claim.

Referencias oficiales: [Firebase Auth Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth),
[Google Sign-In Android](https://pub.dev/packages/google_sign_in_android),
[Firebase custom claims](https://firebase.google.com/docs/auth/admin/custom-claims).
