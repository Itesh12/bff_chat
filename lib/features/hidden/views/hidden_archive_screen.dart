import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:memovault/features/hidden/domain/entities/hidden_note_entity.dart';
import 'package:memovault/features/hidden/domain/repositories/hidden_notes_repository.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/hidden/controllers/hidden_home_controller.dart';

class HiddenArchiveScreen extends StatefulWidget {
  const HiddenArchiveScreen({super.key});

  @override
  State<HiddenArchiveScreen> createState() => _HiddenArchiveScreenState();
}

class _HiddenArchiveScreenState extends State<HiddenArchiveScreen> {
  final HiddenHomeController _controller = Get.find<HiddenHomeController>();
  final HiddenNotesRepository _notesRepository = Get.find<HiddenNotesRepository>();

  List<HiddenNoteEntity> _archivedNotes = [];
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
    await _controller.restoreNote(id);
    await _loadArchivedNotes();
  }

  Future<void> _deleteNotePermanently(String id) async {
    AppDialog.delete(
      context,
      title: 'Delete Permanently?',
      message: 'This secret note will be permanently purged from the secure SQLCipher database. This action is irreversible.',
      onDelete: () async {
        await _controller.permanentlyDeleteNote(id);
        await _loadArchivedNotes();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _controller.onUserInteraction,
      onPanDown: (_) => _controller.onUserInteraction(),
      child: AppScaffold(
        title: 'Secret Archive',
        body: _isLoading
            ? const Center(child: AppLoading.medium())
            : _archivedNotes.isEmpty
                ? const AppEmptyState(
                    icon: Icons.archive_outlined,
                    title: 'Archive is Empty',
                    message: 'Archived secret notes will appear here. They are fully encrypted and securely isolated.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                    itemCount: _archivedNotes.length,
                    itemBuilder: (context, index) {
                      final note = _archivedNotes[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: Dismissible(
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
                            _controller.onUserInteraction();
                            if (direction == DismissDirection.startToEnd) {
                              await _restoreNote(note.id);
                              return true;
                            } else {
                              await _deleteNotePermanently(note.id);
                              return false;
                            }
                          },
                          child: AppCard(
                            onTap: () {
                              _controller.onUserInteraction();
                              Get.to(() => AppScaffold(
                                    title: 'Archived Secret Note',
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title.isEmpty ? 'Untitled Note' : note.title,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const AppGap.v8(),
                                Text(
                                  note.body,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
