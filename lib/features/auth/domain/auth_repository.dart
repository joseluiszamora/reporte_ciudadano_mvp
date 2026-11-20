import 'app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<AppUser> signInWithGoogle();
  Future<void> completeProfile(String publicName);
  Future<void> signOut();
}
