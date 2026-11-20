/// Trusted result from Firebase, never populated by a profile form.
class VerifiedIdentity {
  const VerifiedIdentity({
    required this.uid,
    this.email,
    this.photoUrl,
    this.isAdmin = false,
  });
  final String uid;
  final String? email;
  final String? photoUrl;
  final bool isAdmin;
}

abstract interface class IdentityGateway {
  String? get configurationIssue;
  Future<void> initialize();
  Stream<VerifiedIdentity?> watchIdentity();
  Future<VerifiedIdentity> signIn();
  Future<void> signOut();
}
