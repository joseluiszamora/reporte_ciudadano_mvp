import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/civic_feedback.dart';
import '../../../core/theme/theme_settings.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_pages.dart';
import '../../reports/domain/report_read_repository.dart';
import '../../reports/presentation/report_labels.dart';
import '../../reports/presentation/report_status_badge.dart';
import '../domain/my_reports_repository.dart';
import '../../reports/domain/report_policy.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.auth,
    required this.reports,
    required this.loadDemoReports,
    this.theme,
  });
  final AuthCubit auth;
  final MyReportsRepository reports;
  final Future<bool> Function() loadDemoReports;
  final ThemeSettings? theme;
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    bloc: auth,
    builder: (context, state) {
      if (state.initializing) {
        return const Center(child: CircularProgressIndicator());
      }
      final user = state.user;
      if (user == null) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: CivicState(
                icon: Icons.account_circle_rounded,
                title: 'Estás explorando como visitante.',
                description: 'Puedes consultar el mapa, los reportes y las estadísticas.',
                action: FilledButton.icon(
                  onPressed: () => context.go('/acceso?volver=/perfil'),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Continuar con Google'),
                ),
              ),
            ),
            if (state.issue != null)
              CivicNotice(icon: Icons.info_outline_rounded, text: state.issue!),
            if (state.message != null)
              CivicNotice(
                icon: Icons.error_outline_rounded,
                text: state.message!,
                isError: true,
              ),
            if (theme != null) _ThemeSelector(settings: theme!),
            _DemoReportsButton(load: loadDemoReports),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ProfileHeader(user: user, auth: auth),
            ),
          ),
          if (theme != null) _ThemeSelector(settings: theme!),
          if (ReportPolicy.canManage(user))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Informe de acciones'),
              onTap: () => context.push('/acciones'),
            ),
          const Divider(),
          Text('Mis reportes', style: Theme.of(context).textTheme.titleLarge),
          _MyReports(key: ValueKey(user.uid), reports: reports),
          _DemoReportsButton(load: loadDemoReports),
          const SizedBox(height: 16),
          const Text(
            'Tus reportes y fotografías permanecen en este teléfono al cerrar sesión. Borrar los datos de la app puede eliminarlos.',
          ),
        ],
      );
    },
  );
}

class _ThemeSelector extends StatefulWidget {
  const _ThemeSelector({required this.settings});
  final ThemeSettings settings;

  @override
  State<_ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<_ThemeSelector> {
  bool saving = false;
  bool failed = false;

  Future<void> change(ThemeMode? mode) async {
    if (mode == null || mode == widget.settings.mode || saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.settings.change(mode);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => DropdownButtonFormField<ThemeMode>(
        key: ValueKey((widget.settings.mode, failed)),
        initialValue: widget.settings.mode,
        decoration: InputDecoration(
          labelText: 'Apariencia',
          prefixIcon: const Icon(Icons.contrast_rounded),
          errorText: failed
              ? 'No se pudo guardar la preferencia. Intenta de nuevo.'
              : null,
        ),
        onChanged: saving ? null : change,
        items: const [
          DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
        ],
      ),
    ),
  );
}

class _DemoReportsButton extends StatefulWidget {
  const _DemoReportsButton({required this.load});
  final Future<bool> Function() load;

  @override
  State<_DemoReportsButton> createState() => _DemoReportsButtonState();
}

class _DemoReportsButtonState extends State<_DemoReportsButton> {
  bool busy = false;
  bool loaded = false;

  Future<void> load() async {
    if (busy || loaded) return;
    setState(() => busy = true);
    try {
      final added = await widget.load();
      if (!mounted) return;
      setState(() => loaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added
                ? 'Ejemplos agregados al mapa y al listado.'
                : 'Los ejemplos ya se cargaron en este teléfono.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron cargar los ejemplos. Intenta de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: busy || loaded ? null : load,
    child: Text(
      busy
          ? 'Cargando ejemplos…'
          : loaded
          ? 'Ejemplos cargados'
          : 'Cargar reportes de demostración',
    ),
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
              subtitle: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ReportStatusBadge(report.status),
                  Text(ReportLabels.date(report.createdAt)),
                ],
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
