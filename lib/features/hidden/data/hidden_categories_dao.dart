import 'package:drift/drift.dart';
import 'package:memovault/features/hidden/data/hidden_vault_database.dart';
import 'package:memovault/features/hidden/data/tables/hidden_categories_table.dart';

part 'hidden_categories_dao.g.dart';

@DriftAccessor(tables: [HiddenCategoriesTable])
class HiddenCategoriesDao extends DatabaseAccessor<HiddenVaultDatabase>
    with _$HiddenCategoriesDaoMixin {
  HiddenCategoriesDao(super.db);

  Future<List<HiddenCategoryRow>> getAllCategories() {
    final query = select(hiddenCategoriesTable)
      ..orderBy([(t) => OrderingTerm(expression: t.displayOrder, mode: OrderingMode.asc)]);
    return query.get();
  }

  Future<HiddenCategoryRow?> getCategoryById(String id) {
    return (select(hiddenCategoriesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCategory(HiddenCategoriesTableCompanion companion) {
    return into(hiddenCategoriesTable).insert(companion);
  }

  Future<bool> updateCategory(HiddenCategoriesTableCompanion companion) {
    return update(hiddenCategoriesTable).replace(companion);
  }

  Future<int> deleteCategory(String id) {
    return (delete(hiddenCategoriesTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorderCategories(List<String> orderedIds) async {
    await transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        final id = orderedIds[i];
        await (update(hiddenCategoriesTable)..where((t) => t.id.equals(id)))
            .write(HiddenCategoriesTableCompanion(displayOrder: Value(i)));
      }
    });
  }
}
