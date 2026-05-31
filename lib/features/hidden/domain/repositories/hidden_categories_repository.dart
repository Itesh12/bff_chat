import 'package:memovault/domain/notes/category_entity.dart';

abstract class HiddenCategoriesRepository {
  Future<List<CategoryEntity>> getAllCategories();
  Future<CategoryEntity> createCategory({required String name, required String colorHex});
  Future<CategoryEntity> updateCategory(CategoryEntity category);
  Future<void> deleteCategory(String id);
  Future<void> reorderCategories(List<String> orderedIds);
}
