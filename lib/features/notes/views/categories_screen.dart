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
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
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
                            AppSnackBar.success(title: 'Updated', message: 'Category renamed.');
                          } else {
                            await controller.createCategory(
                              name: name,
                              colorHex: selectedHex,
                            );
                            AppSnackBar.success(title: 'Created', message: '"$name" added.');
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      actions: [
        Obx(() {
          if (controller.categories.isEmpty) return const SizedBox.shrink();
          return AppButton.primary(
            text: 'Create',
            icon: Icons.add,
            onPressed: () => _showCategoryBottomSheet(context),
          );
        }),
        const AppGap.h16(),
      ],
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

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.s16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.s12,
            mainAxisSpacing: AppSpacing.s12,
            childAspectRatio: 1.25,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final cat = list[index];
            final color = _parseCategoryColor(context, cat.colorHex);
            final noteCount = controller.notes.where((n) => n.categoryId == cat.id).length;

            return AppCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () {
                  controller.setSelectedCategory(cat.id);
                  Get.back();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 20, color: theme.iconTheme.color?.withValues(alpha: 0.6)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showCategoryBottomSheet(context, category: cat);
                                    } else if (value == 'delete') {
                                      _confirmDelete(context, cat);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 16),
                                          AppGap.h8(),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                          AppGap.h8(),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$noteCount active',
                                style: AppTypography.bodySmall.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
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
