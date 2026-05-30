import 'package:drift/drift.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/core/storage/tables/categories_table.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [CategoriesTable])
class CategoriesDao extends DatabaseAccessor<AppDatabase> with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  // Retrieve all categories sorted by displayOrder
  Future<List<CategoryRow>> getAllCategories() {
    final query = select(categoriesTable)
      ..orderBy([(t) => OrderingTerm(expression: t.displayOrder, mode: OrderingMode.asc)]);
    return query.get();
  }

  Future<CategoryRow?> getCategoryById(String id) {
    return (select(categoriesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCategory(CategoriesTableCompanion companion) {
    return into(categoriesTable).insert(companion);
  }

  Future<bool> updateCategory(CategoriesTableCompanion companion) {
    return update(categoriesTable).replace(companion);
  }

  Future<int> deleteCategory(String id) {
    return (delete(categoriesTable)..where((t) => t.id.equals(id))).go();
  }

  // Transaction for batch reordering
  Future<void> reorderCategories(List<String> orderedIds) async {
    await transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        final id = orderedIds[i];
        await (update(categoriesTable)..where((t) => t.id.equals(id)))
            .write(CategoriesTableCompanion(displayOrder: Value(i)));
      }
    });
  }
}
