import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/domain/notes/categories_repository.dart';
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

  Color _parseCategoryColor(String hexString) {
    try {
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  void _showCategoryBottomSheet(BuildContext context, {CategoryEntity? category}) {
    final theme = Theme.of(context);
    final isEdit = category != null;

    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedHex = category?.colorHex ?? _presets[0]['hex']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                24,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit Category' : 'Create Category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Personal, Work, Finance',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Theme Color',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Presets grid (4x3)
                  SizedBox(
                    height: 140,
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
                        final color = _parseCategoryColor(hex);
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
                                    color: Colors.black.withOpacity(0.3),
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
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            Get.snackbar('Validation', 'Category name cannot be empty.');
                            return;
                          }

                          if (isEdit) {
                            final updated = category.copyWith(
                              name: name,
                              colorHex: selectedHex,
                            );
                            // Update logic in repository
                            await updateCategory(updated);
                          } else {
                            await controller.createCategory(
                              name: name,
                              colorHex: selectedHex,
                            );
                          }
                          Navigator.pop(context);
                        },
                        child: Text(isEdit ? 'Save Changes' : 'Create'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Deletion logic with confirm dialog
  void _confirmDelete(BuildContext context, CategoryEntity category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Delete "${category.name}"? Notes assigned to this category will not be deleted, they will become uncategorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.deleteCategory(category.id);
              Navigator.pop(context);
              Get.snackbar('Deleted', 'Category removed successfully.');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Helper method inside categories repository wrapper
  Future<void> updateCategory(CategoryEntity category) async {
    // In our implementation plan, CategoriesRepository has updateCategory(CategoryEntity).
    // Let's call the repository through controller
    final CategoriesControllerShim shim = CategoriesControllerShim(controller);
    await shim.updateCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: Obx(() {
        final list = controller.categories;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.style_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No Categories Created',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Organize your notes into folders by adding your first category.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCategoryBottomSheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Category'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final cat = list[index];
            final color = _parseCategoryColor(cat.colorHex);
            
            // Count number of active notes in this category
            final noteCount = controller.notes.where((n) => n.categoryId == cat.id).length;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color,
                  radius: 12,
                ),
                title: Text(
                  cat.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$noteCount active ${noteCount == 1 ? 'note' : 'notes'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showCategoryBottomSheet(context, category: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, cat),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryBottomSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
    );
  }
}

// Controller helper shim to support updating category until controller integrates category editing
class CategoriesControllerShim {
  final NotesController controller;
  CategoriesControllerShim(this.controller);

  Future<void> updateCategory(CategoryEntity category) async {
    // Access CategoriesRepository and perform direct update
    final repo = Get.find<CategoriesRepository>();
    await repo.updateCategory(category);
    await controller.refreshCategories();
  }
}
