enum UserRole { citizen, admin }

class AppUser {
  const AppUser({
    required this.uid,
    required this.publicName,
    this.role = UserRole.citizen,
    this.googleName,
    this.photoUrl,
  });

  /// Firebase UID; exception to the UUID rule used for other entities.
  final String uid;
  final String publicName;
  final UserRole role;
  final String? googleName;
  final String? photoUrl;
}
