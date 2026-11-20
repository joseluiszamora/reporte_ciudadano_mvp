# Verificación de TASK-006

- `flutter test --no-pub --concurrency=1 --reporter=expanded`: 80 pruebas aprobadas.
- `flutter analyze --no-pub`: sin problemas.
- `flutter build apk --debug --no-pub`: APK compilado correctamente.
- Formato Dart verificado.

## Funcionalidad

Formulario protegido con categoría, título, descripción, hasta cinco fotografías,
ubicación elegida/corregible, anonimato y vista previa. El reporte solo se guarda
tras confirmar; se abre el detalle y se puede regresar al listado.

Las fotos se copian en almacenamiento privado, normalizadas como JPEG, con
orientación corregida, lado máximo de 2048 px y sin metadatos transferidos. Se
validan formato real, tamaño y dimensiones antes de devolver una ruta relativa.

Los borradores pertenecen a una cuenta y se conservan al cambiar de pantalla o
reiniciar. El formulario se reconstruye al cambiar de UID; una cuenta no ve el
borrador de otra. Los resultados perdidos del selector se recuperan al arrancar
y solo se entregan al propietario del marcador de selección.

## Pruebas añadidas

- Campos obligatorios, mínimo de una foto y ubicación, revisión sin escribir SQL.
- Importación fallida o archivo ausente: aviso para adjuntar de nuevo y ningún
  reporte incompleto. Fallo de escritura: original intacto.
- Decodificación, orientación EXIF, retirada de metadatos y persistencia tras
  eliminar la fuente temporal. Reducción a 2048 px.
- Referencias actuales, evidencias y versiones históricas protegidas de limpieza,
  incluso después del borrado lógico del reporte.
- Serialización de borradores, recuperación por UID, límite de fotos y descarte.
- UUID estable: doble envío/reintento no duplica reporte, fotos, historial ni auditoría.
- Fallo SQL conserva borrador y fotos. Reinicio después del commit recupera el
  reporte creado aunque todavía no se haya podido eliminar el borrador.
- Flujo de interfaz: retomar formulario, elegir coordenadas, adjuntar foto, revisar,
  publicar anónimamente, abrir detalle y volver a lista.
- Cambio entre dos cuentas completas no expone los campos del usuario anterior.

Los proveedores de identidad y selección simulados existen solo en tests. El APK
exige Google/Firebase configurado y nombre público completo para entrar al formulario.

## Revisión manual pendiente

1. Configurar Firebase según `docs/firebase-setup.md` e iniciar sesión en Android.
2. Completar el formulario, tomar una foto, probar galería y cancelar selección.
3. Denegar cámara o GPS y verificar alternativa por galería/pin/coordenadas.
4. Revisar, volver a editar, publicar y comprobar foto y datos tras reiniciar.
5. Interrumpir la actividad durante la cámara; comprobar recuperación del borrador
   y resultado del selector para la misma cuenta.
6. Cerrar sesión/cambiar de cuenta y comprobar aislamiento; volver a la cuenta original.

Firebase real sigue pendiente por decisión confirmada del usuario. No se realizó
prueba manual de cámara/galería ni recuperación de actividad en un teléfono durante
esta entrega. Las pruebas automáticas no sustituyen esa aceptación final.

Rama: `feature/TASK-006-alta-fotografias`. Los avances anteriores ya estaban en
`3d4912d`; esta fase se guarda en otro commit local, sin push al remoto.
