import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/domain/notes/categories_repository.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class CategoriesScreen extends GetView<NotesController> {
  const CategoriesScreen({super.key});

  static const List<Map<String, String>> _presets = [
    {'name': 'Emerald Red', 'hex': 'E74C3C'},
    {'name': 'Amber Orange', 'hex': 'E67E22'},
    {'name': 'Gold Yellow', 'hex': 'F1C40F'},
    {'name': 'Forest Green', 'hex': '2ECC71'},
    {'name': 'Ocean Teal', 'hex': '1ABC9C'},
    {'name': 'Sky Blue', 'hex': '3498DB'},
    {'name': 'Royal Indigo', 'hex': '3F51B5'},
    {'name': 'Amethyst Purple', 'hex': '9B59B6'},
    {'name': 'Blossom Pink', 'hex': 'E91E63'},
    {'name': 'Sand Brown', 'hex': '795548'},
    {'name': 'Slate Grey', 'hex': '9E9E9E'},
    {'name': 'Midnight Teal', 'hex': '006064'},
  ];

  Color _parseCategoryColor(BuildContext context, String hexString) {
    try {
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return context.colors.disabled;
    }
  }

  void _showCategoryBottomSheet(BuildContext context, {CategoryEntity? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedHex = category?.colorHex ?? _presets[0]['hex']!;

    AppBottomSheet.show(
      context,
      isScrollControlled: true,
      title: isEdit ? 'Edit Category' : 'Create Category',
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          final theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: nameController,
                labelText: 'Category Name',
                hintText: 'e.g. Personal, Work, Finance',
              ),
              const AppGap.v16(),
              const AppSectionHeader(title: 'Select Theme Color'),
              const AppGap.v8(),
              // Presets grid (4x3)
              Container(
                height: 140,
                color: Colors.transparent,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _presets.length,
                  itemBuilder: (context, index) {
                    final preset = _presets[index];
                    final hex = preset['hex']!;
                    final color = _parseCategoryColor(context, hex);
                    final isSelected = selectedHex == hex;

                    return GestureDetector(
                      onTap: () {
                        setLocalState(() {
                          selectedHex = hex;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: theme.shadowColor.withValues(alpha: 0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const AppGap.v24(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.text(
                    text: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const AppGap.h8(),
                  AppButton.primary(
                    text: isEdit ? 'Save Changes' : 'Create',
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        AppSnackBar.error(title: 'Validation', message: 'Category name cannot be empty.');
                        return;
                      }

                      if (isEdit) {
                        final updated = category.copyWith(
                          name: name,
                          colorHex: selectedHex,
                        );
                        await updateCategory(updated);
                      } else {
                        await controller.createCategory(
                          name: name,
                          colorHex: selectedHex,
                        );
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, CategoryEntity category) {
    AppDialog.delete(
      context,
      title: 'Delete Category?',
      message: 'Delete "${category.name}"? Notes assigned to this category will not be deleted, they will become uncategorized.',
      onDelete: () {
        controller.deleteCategory(category.id);
        AppSnackBar.success(title: 'Deleted', message: 'Category removed successfully.');
      },
    );
  }

  Future<void> updateCategory(CategoryEntity category) async {
    final CategoriesControllerShim shim = CategoriesControllerShim(controller);
    await shim.updateCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Manage Categories',
      body: Obx(() {
        final list = controller.categories;
        if (list.isEmpty) {
          return AppEmptyState(
            icon: Icons.style_outlined,
            title: 'No Categories Created',
            message: 'Organize your notes into folders by adding your first category.',
            ctaLabel: 'Create Category',
            onCtaTap: () => _showCategoryBottomSheet(context),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final cat = list[index];
            final color = _parseCategoryColor(context, cat.colorHex);
            final noteCount = controller.notes.where((n) => n.categoryId == cat.id).length;

            return AppCard(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color,
                    radius: 12,
                  ),
                  const AppGap.h16(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const AppGap.v4(),
                        Text(
                          '$noteCount active ${noteCount == 1 ? 'note' : 'notes'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIconButton.secondary(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit Category',
                        onPressed: () => _showCategoryBottomSheet(context, category: cat),
                      ),
                      const AppGap.h8(),
                      AppIconButton.danger(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete Category',
                        onPressed: () => _confirmDelete(context, cat),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      }),
      floatingActionButton: AppButton.primary(
        text: 'Category',
        icon: Icons.add,
        onPressed: () => _showCategoryBottomSheet(context),
      ),
    );
  }
}

class CategoriesControllerShim {
  final NotesController controller;
  CategoriesControllerShim(this.controller);

  Future<void> updateCategory(CategoryEntity category) async {
    final repo = Get.find<CategoriesRepository>();
    await repo.updateCategory(category);
    await controller.refreshCategories();
  }
}
