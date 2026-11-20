# Verificación de TASK-005

- `flutter test --no-pub --reporter=expanded --concurrency=1`: 63 pruebas aprobadas.
- `flutter analyze --no-pub`: sin problemas.
- Formato Dart aplicado y diagnósticos temporales retirados.
- APK Android de depuración compilado con los SDK de Firebase/Google y sin
  configuración de proyecto: permite explorar y muestra el estado pendiente del login.

## Casos nuevos

- Crear como visitante conduce al acceso con Google y conserva `/nuevo`.
- Login verificado exige elegir nombre; posponerlo permite explorar y vuelve a
  exigirlo al intentar crear. Guardarlo retoma la acción pendiente.
- Cancelación y error de conexión no crean usuarios autenticados ficticios.
- La restauración conserva el nombre elegido; eventos duplicados del SDK no
  duplican LOGIN. No se copian nombre ni avatar de Google a la atribución pública.
- Nombre «Administrador» no otorga permisos. Solo el claim verificado concede
  admin; una actualización que lo retira vuelve a ciudadano.
- Cierre de sesión conserva datos locales e invalida un login todavía pendiente.
- Fallo de auditoría de logout no mantiene abierta la sesión del SDK/local.
- Mis reportes filtra por cuenta activa, incluso reportes anónimos.
- Cambio de sesión durante validación de fotos aborta la creación del reporte.
- Envío doble inicia un único flujo de proveedor.
- Sin configuración Firebase la app conserva lectura pública y rechaza login.
- Destinos de retorno limitados a rutas internas conocidas.

Los tests usan un proveedor de identidad explícitamente limitado a `test/`.
No hay acceso simulado ni cuenta admin predeterminada en el APK. Las pruebas
de interfaz alternan el reloj simulado y eventos reales al cancelar streams.

## Pendiente externo confirmado

El usuario todavía no tiene proyecto Firebase. La autenticación con cuentas
reales, firmas SHA de Android y el claim administrador no están verificadas.
Seguir [firebase-setup.md](firebase-setup.md) cuando se cree el proyecto.
La aceptación completa de TASK-005 queda pendiente de esa configuración y
revisión en un teléfono. Las pantallas y repositorios sí están implementados.

El primer intento de compilación se interrumpió por espacio insuficiente al
instalar Android 34. La descarga posterior fue excesivamente lenta. La configuración
de compilación aplica la API pública `finalizeDsl` de AGP para compilar los módulos
FlutterFire con Android SDK 35, disponible en la herramienta actual; no cambia
el minSdk ni el targetSdk de la aplicación.

Rama: `feature/TASK-005-google-perfil`. El avance anterior ya estaba guardado en
`653a10d`; esta fase se guarda en un commit adicional local. Sin push al remoto.
