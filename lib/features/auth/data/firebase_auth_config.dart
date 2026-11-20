import 'package:firebase_core/firebase_core.dart';

class FirebaseAuthConfig {
  const FirebaseAuthConfig({
    this.apiKey = '',
    this.appId = '',
    this.projectId = '',
    this.senderId = '',
    this.webClientId = '',
  });
  const FirebaseAuthConfig.environment()
    : apiKey = const String.fromEnvironment('FIREBASE_API_KEY'),
      appId = const String.fromEnvironment('FIREBASE_APP_ID'),
      projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      senderId = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      webClientId = const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  final String apiKey;
  final String appId;
  final String projectId;
  final String senderId;
  final String webClientId;
  bool get isComplete => [
    apiKey,
    appId,
    projectId,
    senderId,
    webClientId,
  ].every((value) => value.trim().isNotEmpty);
  FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
  );
}
