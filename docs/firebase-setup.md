# Configurar Google y Firebase en Reportes Ciudadanos

- [Acceso de administrador al panel web](#acceso-de-administrador-al-panel-web)
- [Inicio de sesión en Android](#inicio-de-sesión-en-android)

## Inicio de sesión en Android

El usuario confirmó que configuró Firebase y comprobó el acceso con Google y el
registro de reportes en Android. Cada entorno que compile con Google necesita su
configuración local. El APK sin ese archivo permite explorar como visitante.

El paquete de la rama consolidada es `com.mvp.reporte_ciudadano_mvp`. Android
solo conserva los datos al actualizar una instalación del mismo paquete firmada
con el mismo certificado. Si el teléfono ya tiene `bo.elalto.reporte_ciudadano_mvp`,
la nueva aplicación se instala por separado y no abre la base anterior.

## Configuración de proyecto

1. Abrir el proyecto de esta app en [Firebase Console](https://console.firebase.google.com/).
   Si todavía no existe, crearlo.
2. Registrar una app Android con paquete `com.mvp.reporte_ciudadano_mvp`.
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

Desde la raíz, con el Dart que incluye Flutter:

```sh
dart tool/configure_firebase.dart "/ruta/a/google-services.json"
flutter run --dart-define-from-file=config/firebase.android.json
flutter build apk --debug --dart-define-from-file=config/firebase.android.json
```

En Windows, el comando anterior de PowerShell sigue disponible como
`./tool/configure_firebase.ps1 -GoogleServicesPath 'C:/ruta/google-services.json'`.

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
La administración local de reportes está implementada en TASK-007. El backend
web verifica el token y comprueba el permiso en cada solicitud administrativa.

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

## Acceso de administrador al panel web

Usa una cuenta de Google para entrar al panel. Firebase le asigna un UID la
primera vez que inicia sesión. El permiso de gestión del proyecto se otorga a
ese UID mediante el atributo personalizado booleano `admin: true`. Necesitas
acceso al proyecto en Firebase Console con permisos para configurarlo y una
credencial autorizada para gestionar usuarios de Firebase Authentication.

### 1. Habilitar Google y registrar el panel

1. Entra en [Firebase Console](https://console.firebase.google.com/) con la
   cuenta que administra el proyecto. Abre el proyecto existente que usa
   Android. Si aún no tienes proyecto, selecciona **Crear un proyecto**.
2. Abre **Authentication → Método de acceso**, habilita **Google**, selecciona
   un correo de asistencia del proyecto y guarda.
3. En **Authentication → Configuración → Dominios autorizados**, agrega
   `localhost` si aún no aparece. Escribe solo el dominio. Para el flujo
   local de esta guía, abre siempre el panel como `http://localhost:3001`.
4. En **Configuración del proyecto → General → Tus apps**, selecciona el
   icono web **</>**. Registra la app como **Reportes Ciudadanos Web** y copia
   el objeto `firebaseConfig` que muestra Firebase. Puedes dejar Firebase
   Hosting sin activar para ejecutar el panel localmente.

Consulta la documentación de [configuración web](https://firebase.google.com/docs/web/setup),
[inicio con Google](https://firebase.google.com/docs/auth/web/google-signin) y
[dominios autorizados](https://firebase.google.com/docs/auth/faq-and-troubleshooting).

### 2. Configurar y arrancar el panel local

En `web-api/.env.local`, crea el archivo a partir de `web-api/.env.example`
si aún no existe. Sustituye los marcadores por los valores de la **app web**:

```dotenv
FIREBASE_PROJECT_ID=<projectId>
NEXT_PUBLIC_FIREBASE_API_KEY=<apiKey>
NEXT_PUBLIC_FIREBASE_PROJECT_ID=<projectId>
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=<authDomain>
NEXT_PUBLIC_FIREBASE_APP_ID=<appId>
```

Usa el mismo `projectId` en las variables del servidor y del navegador. Conserva
la conexión a PostgreSQL en el mismo archivo. Sigue la
[guía de arranque](../web-api/README.md) para instalar las dependencias,
aplicar el esquema e iniciar o reiniciar Next.js.

### 3. Identificar el UID que vas a autorizar

1. Abre [el panel local](http://localhost:3001). En **Acceso administrativo**,
   selecciona **Entrar con Google** y usa la cuenta que gestionará los reportes.
   Si aparece «Tu cuenta no tiene permisos de administración» en este primer
   acceso, la cuenta de Google ya inició sesión y falta asignar el permiso.
2. En Firebase Console, abre **Authentication → Usuarios**. Busca el correo de
   esa cuenta y copia su **UID de usuario**. Confirma el correo y el proveedor
   Google antes de continuar.

### 4. Asignar el permiso con Firebase Admin SDK

En **Configuración del proyecto → Cuentas de servicio → Firebase Admin SDK**,
selecciona **Generar nueva clave privada**. Guarda el JSON fuera del repositorio
en un directorio privado. Si tu organización restringe la generación de
claves, solicita que un administrador del proyecto ejecute la asignación con
sus credenciales autorizadas. [Configuración del SDK de administrador](https://firebase.google.com/docs/admin/setup).

Abre una terminal de PowerShell en `web-api/` con las dependencias instaladas.
Ajusta la ruta del JSON, el ID del proyecto y el UID antes de ejecutar:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\ruta\privada\firebase-admin.json'
$env:FIREBASE_PROJECT_ID = 'id-de-tu-proyecto'
$env:FIREBASE_ADMIN_UID = 'uid-copiado-de-firebase'

@'
import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const { FIREBASE_PROJECT_ID: projectId, FIREBASE_ADMIN_UID: uid } = process.env;
if (!projectId || !uid) throw new Error("Indica el proyecto y el UID.");

const auth = getAuth(initializeApp({ projectId, credential: applicationDefault() }));
const user = await auth.getUser(uid);
if (user.disabled || !user.providerData.some(({ providerId }) => providerId === "google.com")) {
  throw new Error("El UID debe pertenecer a un usuario habilitado con Google.");
}

await auth.setCustomUserClaims(uid, { ...user.customClaims, admin: true });
if ((await auth.getUser(uid)).customClaims?.admin !== true) {
  throw new Error("Firebase no confirmó el permiso.");
}
console.log("Permiso de administrador confirmado en Firebase.");
'@ | node --input-type=module
```

El comando conserva los demás atributos personalizados. Mantén el JSON de la
cuenta de servicio fuera de Git, de `web-api/` y de cualquier archivo
`NEXT_PUBLIC_*`. [Asignación de permisos con atributos personalizados](https://firebase.google.com/docs/auth/admin/custom-claims).

### 5. Comprobar el acceso

1. Cierra sesión en el panel y vuelve a entrar con la misma cuenta de Google.
   Así Firebase emite un token que incluye el nuevo permiso.
2. Si el panel lo solicita, introduce tu nombre público y guárdalo.
3. Abre un reporte de PostgreSQL. El detalle debe mostrar **Gestión del
   reporte** con los botones de edición, seguimiento o reapertura, y retiro.
   Si la base está vacía, puedes confirmar el acceso por el nombre guardado en
   el menú del panel. Los botones de gestión aparecerán al abrir un reporte.

Si Google indica que el dominio no está autorizado, revisa `localhost` en el
paso 1. Si el panel sigue indicando que faltan permisos después de volver a
entrar, verifica que el UID y los dos valores de `projectId` correspondan al
mismo proyecto. Si Firebase rechaza el comando del paso 4, verifica que la
credencial tenga permiso para modificar usuarios de Firebase Authentication.
