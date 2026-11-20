import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../reports/domain/report_policy.dart';
import 'auth_cubit.dart';

class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(AuthCubit auth) {
    subscription = auth.stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<AuthState> subscription;
  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }
}

String safeAuthReturn(String? value) {
  if (value == '/nuevo' || value == '/acciones') return value!;
  if (value != null &&
      RegExp(r'^/gestionar/[a-zA-Z0-9-]{1,80}$').hasMatch(value)) {
    return value;
  }
  return '/perfil';
}

String? authRedirect(AuthState auth, Uri uri) {
  final path = uri.path;
  final target = safeAuthReturn(uri.queryParameters['volver']);
  final complete = ReportPolicy.canCreate(auth.user);
  if (path == '/acceso') {
    if (auth.initializing || auth.busy || auth.user == null) return null;
    return complete
        ? target
        : Uri(path: '/nombre', queryParameters: {'volver': target}).toString();
  }
  if (path == '/nombre') {
    if (auth.initializing || auth.busy) return null;
    if (auth.user == null) {
      return Uri(
        path: '/acceso',
        queryParameters: {'volver': target},
      ).toString();
    }
    return complete ? target : null;
  }
  if (path == '/nuevo' ||
      path == '/acciones' ||
      path.startsWith('/gestionar/')) {
    if (auth.user == null) {
      return Uri(
        path: '/acceso',
        queryParameters: {'volver': safeAuthReturn(path)},
      ).toString();
    }
    if (!complete) {
      return Uri(
        path: '/nombre',
        queryParameters: {'volver': safeAuthReturn(path)},
      ).toString();
    }
    if (path == '/acciones' && !ReportPolicy.canManage(auth.user)) {
      return '/perfil';
    }
  }
  return null;
}
