class ReportCategory {
  const ReportCategory({
    required this.id,
    required this.name,
    required this.isActive,
    this.iconKey = 'category',
  });
  final String id;
  final String name;
  final bool isActive;
  final String iconKey;
}

abstract interface class CategoryRepository {
  Stream<List<ReportCategory>> watchCategories();
}
