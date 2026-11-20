import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/features/auth/domain/app_user.dart';
import 'package:reporte_ciudadano_mvp/features/auth/presentation/auth_cubit.dart';
import 'package:reporte_ciudadano_mvp/features/auth/presentation/auth_route_guard.dart';

void main() {
  test('management returns through login/name; private audit route rejects citizen', () {
    final manage = Uri.parse('/gestionar/report-123');
    final redirect = Uri.parse(
      authRedirect(const AuthState(initializing: false), manage)!,
    );
    expect(redirect.path, '/acceso');
    expect(redirect.queryParameters['volver'], manage.path);
    const incomplete = AuthState(
      initializing: false,
      user: AppUser(uid: 'u', publicName: ''),
    );
    expect(Uri.parse(authRedirect(incomplete, manage)!).path, '/nombre');
    const citizen = AuthState(
      initializing: false,
      user: AppUser(uid: 'u', publicName: 'Vecina'),
    );
    expect(authRedirect(citizen, manage), isNull);
    expect(authRedirect(citizen, Uri.parse('/acciones')), '/perfil');
    const admin = AuthState(
      initializing: false,
      user: AppUser(uid: 'a', publicName: 'Admin', role: UserRole.admin),
    );
    expect(authRedirect(admin, Uri.parse('/acciones')), isNull);
  });
  test('return target accepts only known internal management paths and prevents external URLs and traversal', () {
    expect(safeAuthReturn('/gestionar/report-123'), '/gestionar/report-123');
    expect(safeAuthReturn('/acciones'), '/acciones');
    for (final target in [
      'https://example.test',
      '//example.test',
      '/gestionar/../../acciones',
      '/gestionar/a?x=1',
      '/gestionar/%2f',
    ]) {
      expect(safeAuthReturn(target), '/perfil');
    }
  });
}
