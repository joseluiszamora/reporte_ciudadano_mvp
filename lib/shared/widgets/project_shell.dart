import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProjectShell extends StatelessWidget {
  const ProjectShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;

  static const paths = ['/mapa', '/reportes', '/estadisticas', '/perfil'];

  @override
  Widget build(BuildContext context) {
    final creating = path == '/nuevo';
    final insets = MediaQuery.viewInsetsOf(context);
    final keyboard = insets.bottom > 0;
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 17;
    final showReport = path == '/mapa' || path == '/reportes';
    final title = switch (path) {
      '/mapa' => 'Reportes Ciudadanos',
      '/reportes' => 'Reportes',
      '/estadisticas' => 'Estadísticas',
      '/nuevo' => 'Nuevo reporte',
      _ => 'Perfil',
    };
    return Scaffold(
      appBar: AppBar(
        leading: creating
            ? BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/mapa');
                  }
                },
              )
            : null,
        title: Text(title),
      ),
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(viewInsets: insets),
          child: SafeArea(top: false, bottom: creating, child: child),
        ),
      ),
      bottomNavigationBar: creating || keyboard
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showReport)
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => context.push('/nuevo'),
                          icon: const Icon(Icons.add_location_alt_rounded),
                          label: const Text('Reportar'),
                        ),
                      ),
                    ),
                  ),
                NavigationBar(
                  labelBehavior: largeText
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : null,
                  height: largeText ? 96 : null,
                  selectedIndex: paths.indexOf(path),
                  onDestinationSelected: (index) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    context.go(paths[index]);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.map_rounded),
                      label: 'Mapa',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list_alt_rounded),
                      label: 'Reportes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_rounded),
                      label: 'Estadísticas',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      label: 'Perfil',
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
