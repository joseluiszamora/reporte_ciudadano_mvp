import 'package:flutter/material.dart';

import '../domain/category_repository.dart';
import 'category_icon.dart';

/// Small live view to verify the local catalog before the reporting form exists.
class CategoryCatalog extends StatelessWidget {
  const CategoryCatalog({super.key, required this.categories});
  final Stream<List<ReportCategory>> categories;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ReportCategory>>(
    stream: categories,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No se pudo abrir el catálogo local. Cierra y vuelve a abrir la aplicación para reintentar.',
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final active = snapshot.data!
          .where((category) => category.isActive)
          .toList();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Categorías', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Catálogo local de problemas urbanos disponibles en este teléfono.',
          ),
          const SizedBox(height: 24),
          Text(
            'Categorías disponibles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (active.isEmpty)
            const ListTile(title: Text('No hay categorías habilitadas.')),
          for (final category in active)
            ListTile(
              leading: Icon(categoryIcon(category.iconKey)),
              title: Text(category.name),
            ),
        ],
      );
    },
  );
}
