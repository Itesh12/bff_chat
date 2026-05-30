import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/notes_repository.dart';
import 'package:memovault/core/widgets/note_card.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/notes/controllers/notes_controller.dart';

class NotesArchiveScreen extends StatefulWidget {
  const NotesArchiveScreen({super.key});

  @override
  State<NotesArchiveScreen> createState() => _NotesArchiveScreenState();
}

class _NotesArchiveScreenState extends State<NotesArchiveScreen> {
  final NotesController _notesController = Get.find<NotesController>();
  final NotesRepository _notesRepository = Get.find<NotesRepository>();

  List<NoteEntity> _archivedNotes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadArchivedNotes();
  }

  Future<void> _loadArchivedNotes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await _notesRepository.getArchivedNotes();
      setState(() {
        _archivedNotes = list;
      });
    } catch (_) {
      setState(() {
        _archivedNotes = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreNote(String id) async {
    await _notesController.restoreNote(id);
    await _loadArchivedNotes();
    AppSnackBar.success(title: 'Restored', message: 'Note returned to your dashboard.');
  }

  Future<void> _deleteNotePermanently(String id) async {
    AppDialog.delete(
      context,
      title: 'Delete Permanently?',
      message: 'This action is irreversible. The note contents will be permanently purged from the secure database.',
      onDelete: () async {
        await _notesController.permanentlyDeleteNote(id);
        await _loadArchivedNotes();
        AppSnackBar.success(title: 'Purged', message: 'Note permanently deleted.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Archive & Trash',
      body: _isLoading
          ? const Center(child: AppLoading.medium())
          : _archivedNotes.isEmpty
              ? const AppEmptyState(
                  icon: Icons.archive_outlined,
                  title: 'Archive is Empty',
                  message: 'Archived notes or soft-deleted items will appear here for secure storage or purging.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                  itemCount: _archivedNotes.length,
                  itemBuilder: (context, index) {
                    final note = _archivedNotes[index];
                    final cat = _notesController.categories.firstWhereOrNull((c) => c.id == note.categoryId);

                    return Dismissible(
                      key: ValueKey(note.id),
                      background: Container(
                        color: context.colors.success.withValues(alpha: 0.8),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                        child: Icon(Icons.unarchive, color: theme.colorScheme.onPrimary),
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
                          // Allow read-only viewing of archived notes using AppScaffold
                          Get.to(() => AppScaffold(
                                title: 'Archived Note',
                                actions: [
                                  AppIconButton.secondary(
                                    icon: Icons.unarchive,
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
                        onFavoriteTap: () {}, // Favorite disabled in archive
                      ),
                    );
                  },
                ),
    );
  }
}
