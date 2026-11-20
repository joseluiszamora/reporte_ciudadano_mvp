enum AuthFailure { cancelled, notConfigured, network, denied, storage, unknown }

class AuthException implements Exception {
  const AuthException(this.failure);
  final AuthFailure failure;
  String get message => switch (failure) {
    AuthFailure.cancelled => 'Se canceló el inicio de sesión.',
    AuthFailure.notConfigured => 'El acceso con Google aún no está configurado en esta versión. Puedes seguir explorando sin sesión.',
    AuthFailure.network => 'No se pudo conectar con Google. Revisa tu conexión y vuelve a intentarlo.',
    AuthFailure.denied =>
      'No se pudo validar tu sesión. Vuelve a iniciar sesión.',
    AuthFailure.storage =>
      'No se pudo guardar tu sesión en este teléfono. Vuelve a intentarlo.',
    AuthFailure.unknown =>
      'No se pudo completar la operación. Vuelve a intentarlo.',
  };
  @override
  String toString() => message;
}
