import 'dart:async';

import 'package:reporte_ciudadano_mvp/features/auth/data/identity_gateway.dart';
import 'package:reporte_ciudadano_mvp/features/auth/domain/auth_exception.dart';

/// Test-only identity provider; never wired into a production build.
class TestIdentityGateway implements IdentityGateway {
  TestIdentityGateway({
    this.current,
    this.next = const VerifiedIdentity(uid: 'google-user'),
    this.configured = true,
  });
  VerifiedIdentity? current;
  VerifiedIdentity next;
  bool configured;
  AuthFailure? failure;
  int signIns = 0;
  int signOuts = 0;
  Future<VerifiedIdentity>? pending;
  final events = StreamController<VerifiedIdentity?>.broadcast(sync: true);
  @override
  String? get configurationIssue => configured
      ? null
      : const AuthException(AuthFailure.notConfigured).message;
  @override
  Future<void> initialize() async {}
  @override
  Stream<VerifiedIdentity?> watchIdentity() => Stream.multi((controller) {
    final sub = events.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.add(current);
    controller.onCancel = sub.cancel;
  });
  @override
  Future<VerifiedIdentity> signIn() async {
    signIns++;
    if (failure != null) throw AuthException(failure!);
    final identity = await (pending ?? Future.value(next));
    current = identity;
    events.add(identity);
    return identity;
  }

  void change(VerifiedIdentity? identity) {
    current = identity;
    events.add(identity);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    change(null);
  }
}
