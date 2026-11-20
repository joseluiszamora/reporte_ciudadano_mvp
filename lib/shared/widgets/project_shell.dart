import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProjectShell extends StatelessWidget {
  const ProjectShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  static const paths = [
    '/mapa',
    '/reportes',
    '/nuevo',
    '/estadisticas',
    '/perfil',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reportes ciudadanos · El Alto')),
    body: Column(
      children: [
        const MaterialBanner(
          content: Text(
            'Prototipo local en construcción. Los reportes se guardarán en este teléfono.',
          ),
          actions: [SizedBox.shrink()],
        ),
        Expanded(child: child),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: paths.indexOf(path),
      onDestinationSelected: (index) => context.go(paths[index]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Mapa'),
        NavigationDestination(icon: Icon(Icons.list_alt), label: 'Reportes'),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          label: 'Crear',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart),
          label: 'Estadísticas',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    ),
  );
}

class FoundationPage extends StatelessWidget {
  const FoundationPage({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });
  final String title;
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
