import '../../../core/database/app_database.dart';
import '../domain/category_repository.dart';

class SqliteCategoryRepository implements CategoryRepository {
  SqliteCategoryRepository(this.db);
  final AppDatabase db;
  @override
  Stream<List<ReportCategory>> watchCategories() =>
      db.watchQuery({'categories'}, () async {
        final rows = await db
            .customSelect(
              'SELECT id,name,is_active,icon_key FROM categories ORDER BY sort_order',
            )
            .get();
        return List.unmodifiable(
          rows.map(
            (row) => ReportCategory(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              iconKey: row.read<String>('icon_key'),
              isActive: row.read<int>('is_active') == 1,
            ),
          ),
        );
      });
}
