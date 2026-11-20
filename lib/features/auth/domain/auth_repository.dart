import 'app_user.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;
  String? get configurationIssue;
  Future<void> initialize();
  Stream<AppUser?> watchUser();
  Future<AppUser> signInWithGoogle();
  Future<void> completeProfile(String publicName);
  Future<void> signOut();
  Future<void> close();
}
