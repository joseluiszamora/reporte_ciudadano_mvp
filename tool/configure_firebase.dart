import 'dart:convert';
import 'dart:io';

const _androidPackage = 'com.mvp.reporte_ciudadano_mvp';

Map<String, dynamic> _object(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

Iterable<Map<String, dynamic>> _entries(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>() : const [];

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('Falta el campo $field en la configuración.');
}

Map<String, String> _readConfig(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Se esperaba un objeto JSON de Firebase.');
  }

  final androidClients = _entries(data['client']).where(
    (client) =>
        _object(
          _object(client['client_info'])['android_client_info'],
        )['package_name'] ==
        _androidPackage,
  );
  if (androidClients.length != 1) {
    throw const FormatException(
      'Debe existir exactamente un cliente Android para $_androidPackage.',
    );
  }

  final client = androidClients.single;
  final webClient = _entries(client['oauth_client'])
      .where((entry) => entry['client_type'] == 3)
      .firstOrNull;
  if (webClient == null) {
    throw const FormatException(
      'Falta el cliente OAuth web (client_type 3). '
      'Habilita Google en Firebase Auth y vuelve a descargar google-services.json.',
    );
  }

  final project = _object(data['project_info']);
  return {
    'FIREBASE_API_KEY': _requiredString(
      _entries(client['api_key']).firstOrNull?['current_key'],
      'FIREBASE_API_KEY',
    ),
    'FIREBASE_APP_ID': _requiredString(
      _object(client['client_info'])['mobilesdk_app_id'],
      'FIREBASE_APP_ID',
    ),
    'FIREBASE_PROJECT_ID': _requiredString(
      project['project_id'],
      'FIREBASE_PROJECT_ID',
    ),
    'FIREBASE_MESSAGING_SENDER_ID': _requiredString(
      project['project_number'],
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    'GOOGLE_WEB_CLIENT_ID': _requiredString(
      webClient['client_id'],
      'GOOGLE_WEB_CLIENT_ID',
    ),
  };
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Uso: dart tool/configure_firebase.dart <google-services.json>',
    );
    exitCode = 64;
    return;
  }

  try {
    final input = File(arguments.single).readAsStringSync();
    final config = _readConfig(jsonDecode(input));
    final output = File.fromUri(
      Platform.script.resolve('../config/firebase.android.json'),
    );
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(config)}\n',
    );
    stdout.writeln('Configuración generada en config/firebase.android.json.');
  } on FormatException catch (error) {
    stderr.writeln(
      error.source == null
          ? error.message
          : 'El archivo no contiene JSON válido.',
    );
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln(
      'No se pudo leer o escribir la configuración. ${error.message}',
    );
    exitCode = 1;
  }
}
