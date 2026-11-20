import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_exception.dart';
import 'firebase_auth_config.dart';
import 'identity_gateway.dart';

class FirebaseGoogleGateway implements IdentityGateway {
  FirebaseGoogleGateway({this.config = const FirebaseAuthConfig.environment()});
  final FirebaseAuthConfig config;
  FirebaseAuth? _auth;
  Future<void>? _googleReady;
  @override
  String? get configurationIssue => config.isComplete
      ? null
      : const AuthException(AuthFailure.notConfigured).message;
  @override
  Future<void> initialize() async {
    if (!config.isComplete || _auth != null) return;
    try {
      final app =
          Firebase.apps
              .where((app) => app.name == 'citizen-reports')
              .firstOrNull ??
          await Firebase.initializeApp(
            name: 'citizen-reports',
            options: config.options,
          );
      _auth = FirebaseAuth.instanceFor(app: app);
    } catch (_) {
      throw const AuthException(AuthFailure.notConfigured);
    }
  }

  Future<VerifiedIdentity> identity(User user) async {
    var admin = false;
    try {
      final token = await user.getIdTokenResult().timeout(
        const Duration(seconds: 10),
      );
      admin = token.claims?['admin'] == true;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'network-request-failed') {
        throw const AuthException(AuthFailure.denied);
      }
      // A persisted SDK user can work locally offline, without granting admin
      // if claims cannot currently be read from its cached token.
    } on TimeoutException {
      /* Fail closed for admin; keep the persisted identity. */
    }
    return VerifiedIdentity(
      uid: user.uid,
      email: user.email,
      photoUrl: user.photoURL,
      isAdmin: admin,
    );
  }

  @override
  Stream<VerifiedIdentity?> watchIdentity() async* {
    final auth = _auth;
    if (auth == null) {
      yield null;
      return;
    }
    await for (final user in auth.idTokenChanges()) {
      if (user == null) {
        yield null;
      } else {
        final verified = await identity(user);
        if (auth.currentUser?.uid == user.uid) yield verified;
      }
    }
  }

  @override
  Future<VerifiedIdentity> signIn() async {
    if (_auth == null) throw const AuthException(AuthFailure.notConfigured);
    try {
      final google = GoogleSignIn.instance;
      await (_googleReady ??= google.initialize(
        serverClientId: config.webClientId,
      ));
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const AuthException(AuthFailure.denied);
      final result = await _auth!.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
      if (result.user == null) throw const AuthException(AuthFailure.denied);
      return await identity(result.user!);
    } on AuthException {
      rethrow;
    } on GoogleSignInException catch (error) {
      throw AuthException(
        error.code == GoogleSignInExceptionCode.canceled
            ? AuthFailure.cancelled
            : error.code == GoogleSignInExceptionCode.clientConfigurationError
            ? AuthFailure.notConfigured
            : AuthFailure.unknown,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(
        error.code == 'network-request-failed'
            ? AuthFailure.network
            : AuthFailure.denied,
      );
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth?.signOut();
    if (_googleReady != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        /* Firebase session already cleared. */
      }
    }
  }
}
