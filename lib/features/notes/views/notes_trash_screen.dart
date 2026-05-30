import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class NotesTrashScreen extends StatefulWidget {
  const NotesTrashScreen({super.key});

  @override
  State<NotesTrashScreen> createState() => _NotesTrashScreenState();
}

class _NotesTrashScreenState extends State<NotesTrashScreen> {
  final NotesController _notesController = Get.find<NotesController>();
  final NotesRepository _notesRepository = Get.find<NotesRepository>();

  List<NoteEntity> _trashedNotes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTrashedNotes();
  }

  Future<void> _loadTrashedNotes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await _notesRepository.getTrashedNotes();
      setState(() {
        _trashedNotes = list;
      });
    } catch (_) {
      setState(() {
        _trashedNotes = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreNote(String id) async {
    await _notesController.restoreNote(id);
    await _loadTrashedNotes();
    AppSnackBar.success(title: 'Restored', message: 'Restored to dashboard.');
  }

  Future<void> _deleteNotePermanently(String id) async {
    AppDialog.delete(
      context,
      title: 'Delete Permanently?',
      message: 'This action is irreversible. The note contents will be permanently purged from the secure database.',
      onDelete: () async {
        await _notesController.permanentlyDeleteNote(id);
        await _loadTrashedNotes();
        AppSnackBar.success(title: 'Purged', message: 'Note permanently deleted.');
      },
    );
  }

  Future<void> _emptyTrash() async {
    AppDialog.delete(
      context,
      title: 'Empty Trash?',
      message: 'Are you sure you want to permanently delete all items in the Trash? This action is irreversible.',
      deleteLabel: 'Empty Trash',
      onDelete: () async {
        await _notesController.emptyTrash();
        await _loadTrashedNotes();
        AppSnackBar.success(title: 'Cleared', message: 'All trashed notes permanently purged.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Trash',
      actions: [
        if (_trashedNotes.isNotEmpty)
          AppIconButton.secondary(
            icon: Icons.delete_sweep,
            tooltip: 'Empty Trash',
            onPressed: _emptyTrash,
          ),
        const AppGap.h12(),
      ],
      body: _isLoading
          ? const Center(child: AppLoading.medium())
          : _trashedNotes.isEmpty
              ? const AppEmptyState(
                  icon: Icons.delete_outline,
                  title: 'Trash is Empty',
                  message: 'Trashed notes will appear here. You can restore them or permanently delete them.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                  itemCount: _trashedNotes.length,
                  itemBuilder: (context, index) {
                    final note = _trashedNotes[index];
                    final cat = _notesController.categories.firstWhereOrNull((c) => c.id == note.categoryId);

                    return Dismissible(
                      key: ValueKey(note.id),
                      background: Container(
                        color: context.colors.success.withValues(alpha: 0.8),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                        child: Icon(Icons.restore, color: theme.colorScheme.onPrimary),
                      ),
                      secondaryBackground: Container(
                        color: context.colors.error.withValues(alpha: 0.8),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                        child: Icon(Icons.delete_forever, color: theme.colorScheme.onError),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _restoreNote(note.id);
                          return true;
                        } else {
                          await _deleteNotePermanently(note.id);
                          return false;
                        }
                      },
                      child: NoteCard(
                        note: note,
                        category: cat,
                        isGrid: false,
                        onTap: () {
                          // Allow read-only viewing of trashed notes using AppScaffold
                          Get.to(() => AppScaffold(
                                title: 'Trashed Note',
                                actions: [
                                  AppIconButton.secondary(
                                    icon: Icons.restore,
                                    tooltip: 'Restore Note',
                                    onPressed: () async {
                                      await _restoreNote(note.id);
                                      Get.back();
                                    },
                                  ),
                                  const AppGap.h12(),
                                ],
                                body: SingleChildScrollView(
                                  padding: const EdgeInsets.all(AppSpacing.s24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        note.title.isEmpty ? 'Untitled' : note.title,
                                        style: AppTypography.displayLarge.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const AppGap.v16(),
                                      Container(height: 1, color: theme.dividerColor),
                                      const AppGap.v16(),
                                      Text(
                                        note.body.isEmpty ? 'No content' : note.body,
                                        style: AppTypography.bodyLarge.copyWith(height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ));
                        },
                        onFavoriteTap: () {}, // Favorite disabled in trash
                      ),
                    );
                  },
                ),
    );
  }
}
