class ReportCategory {
  const ReportCategory({
    required this.id,
    required this.name,
    required this.isActive,
  });
  final String id;
  final String name;
  final bool isActive;
}

abstract interface class CategoryRepository {
  Stream<List<ReportCategory>> watchCategories();
}
