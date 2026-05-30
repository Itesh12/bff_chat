import 'dart:math';
import 'package:drift/drift.dart';
import 'package:memovault/core/storage/app_database.dart';
import 'package:memovault/data/notes/categories_dao.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/domain/notes/categories_repository.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  final CategoriesDao _categoriesDao;

  CategoriesRepositoryImpl(this._categoriesDao);

  // Cryptographically secure UUID v4 generator in pure Dart
  String _generateUuid() {
    final random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC4122
    
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  CategoryEntity _toEntity(CategoryRow row) {
    return CategoryEntity(
      id: row.id,
      name: row.name,
      colorHex: row.colorHex,
      displayOrder: row.displayOrder,
      createdAt: row.createdAt,
    );
  }

  @override
  Future<List<CategoryEntity>> getAllCategories() async {
    final rows = await _categoriesDao.getAllCategories();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<CategoryEntity> createCategory({required String name, required String colorHex}) async {
    final id = _generateUuid();
    final now = DateTime.now().toUtc();
    
    // Determine the next displayOrder (largest + 1)
    final existing = await _categoriesDao.getAllCategories();
    final nextOrder = existing.isEmpty ? 0 : existing.map((c) => c.displayOrder).reduce(max) + 1;

    final companion = CategoriesTableCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: Value(colorHex),
      displayOrder: Value(nextOrder),
      createdAt: Value(now),
    );

    await _categoriesDao.insertCategory(companion);
    final row = await _categoriesDao.getCategoryById(id);
    return _toEntity(row!);
  }

  @override
  Future<CategoryEntity> updateCategory(CategoryEntity category) async {
    final companion = CategoriesTableCompanion(
      id: Value(category.id),
      name: Value(category.name),
      colorHex: Value(category.colorHex),
      displayOrder: Value(category.displayOrder),
      createdAt: Value(category.createdAt),
    );

    await _categoriesDao.updateCategory(companion);
    final row = await _categoriesDao.getCategoryById(category.id);
    return _toEntity(row!);
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _categoriesDao.deleteCategory(id);
  }

  @override
  Future<void> reorderCategories(List<String> orderedIds) async {
    await _categoriesDao.reorderCategories(orderedIds);
  }
}
