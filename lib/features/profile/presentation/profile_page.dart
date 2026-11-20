import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_pages.dart';
import '../../reports/domain/report_read_repository.dart';
import '../../reports/presentation/report_labels.dart';
import '../domain/my_reports_repository.dart';
import '../../reports/domain/report_policy.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.auth, required this.reports});
  final AuthCubit auth;
  final MyReportsRepository reports;
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    bloc: auth,
    builder: (context, state) {
      if (state.initializing) {
        return const Center(child: CircularProgressIndicator());
      }
      final user = state.user;
      if (user == null) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Estás explorando como visitante.'),
                const SizedBox(height: 12),
                if (state.issue != null) Text(state.issue!),
                FilledButton.icon(
                  onPressed: () => context.go('/acceso?volver=/perfil'),
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar sesión con Google'),
                ),
                if (state.message != null) Text(state.message!),
              ],
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ProfileHeader(user: user, auth: auth),
          if (ReportPolicy.canManage(user))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Informe de acciones'),
              onTap: () => context.push('/acciones'),
            ),
          const Divider(),
          Text('Mis reportes', style: Theme.of(context).textTheme.titleLarge),
          _MyReports(key: ValueKey(user.uid), reports: reports),
          const SizedBox(height: 16),
          const Text(
            'Tus reportes y fotografías permanecen en este teléfono al cerrar sesión. Borrar los datos de la app puede eliminarlos.',
          ),
        ],
      );
    },
  );
}

class _MyReports extends StatefulWidget {
  const _MyReports({super.key, required this.reports});
  final MyReportsRepository reports;
  @override
  State<_MyReports> createState() => _MyReportsState();
}

class _MyReportsState extends State<_MyReports> {
  late final stream = widget.reports.watchMine();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ReportListItem>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'No se pudieron cargar tus reportes. Vuelve a entrar al perfil para reintentar.',
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      if (snapshot.data!.isEmpty) {
        return const Text('Todavía no has creado reportes en este teléfono.');
      }
      return Column(
        children: [
          for (final report in snapshot.data!)
            ListTile(
              title: Text(report.title),
              subtitle: Text(
                '${ReportLabels.status(report.status)} · ${ReportLabels.date(report.createdAt)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/reporte/${Uri.encodeComponent(report.id)}'),
            ),
        ],
      );
    },
  );
}
