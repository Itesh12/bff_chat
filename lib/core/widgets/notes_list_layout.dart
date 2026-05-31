import 'package:flutter/material.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/category_entity.dart';
import 'package:memovault/core/widgets/note_card.dart';

class NotesListLayout extends StatelessWidget {
  final String title;
  final List<NoteEntity> notes;
  final List<CategoryEntity> categories;
  final bool isLoading;
  final IconData emptyStateIcon;
  final String emptyStateTitle;
  final String emptyStateMessage;
  
  final bool showEmptyTrashAction;
  final VoidCallback? onEmptyTrash;

  final bool enableSwipes;
  final IconData? swipeLeftIcon;
  final IconData? swipeRightIcon;
  final Future<void> Function(String noteId)? onSwipeLeft;
  final Future<void> Function(String noteId)? onSwipeRight;

  final ValueChanged<NoteEntity> onTapNote;
  final ValueChanged<NoteEntity>? onFavoriteTap;
  final VoidCallback? onUserInteraction;

  const NotesListLayout({
    super.key,
    required this.title,
    required this.notes,
    required this.categories,
    required this.isLoading,
    required this.emptyStateIcon,
    required this.emptyStateTitle,
    required this.emptyStateMessage,
    this.showEmptyTrashAction = false,
    this.onEmptyTrash,
    this.enableSwipes = false,
    this.swipeLeftIcon,
    this.swipeRightIcon,
    this.onSwipeLeft,
    this.onSwipeRight,
    required this.onTapNote,
    this.onFavoriteTap,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = isLoading
        ? const Center(child: AppLoading.medium())
        : notes.isEmpty
            ? AppEmptyState(
                icon: emptyStateIcon,
                title: emptyStateTitle,
                message: emptyStateMessage,
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final cat = categories.cast<CategoryEntity?>().firstWhere((c) => c?.id == note.categoryId, orElse: () => null);

                  final card = NoteCard(
                    key: ValueKey(note.id),
                    note: note,
                    category: cat,
                    isGrid: false,
                    onTap: () {
                      onUserInteraction?.call();
                      onTapNote(note);
                    },
                    onFavoriteTap: onFavoriteTap != null
                        ? () {
                            onUserInteraction?.call();
                            onFavoriteTap!(note);
                          }
                        : () {},
                  );

                  if (!enableSwipes) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                      child: card,
                    );
                  }

                  return Dismissible(
                    key: ValueKey(note.id),
                    background: Container(
                      color: context.colors.success.withValues(alpha: 0.8),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                      child: Icon(swipeRightIcon ?? Icons.restore, color: theme.colorScheme.onPrimary),
                    ),
                    secondaryBackground: Container(
                      color: context.colors.error.withValues(alpha: 0.8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                      child: Icon(swipeLeftIcon ?? Icons.delete_forever, color: theme.colorScheme.onError),
                    ),
                    confirmDismiss: (direction) async {
                      onUserInteraction?.call();
                      if (direction == DismissDirection.startToEnd) {
                        if (onSwipeRight != null) {
                          await onSwipeRight!(note.id);
                          return true;
                        }
                        return false;
                      } else {
                        if (onSwipeLeft != null) {
                          await onSwipeLeft!(note.id);
                          return false; // Confirmed actions inside the callbacks handle deletion dynamically
                        }
                        return false;
                      }
                    },
                    child: card,
                  );
                },
              );

    if (onUserInteraction != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onUserInteraction,
        onPanDown: (_) => onUserInteraction!(),
        child: content,
      );
    }

    return AppScaffold(
      title: title,
      actions: [
        if (showEmptyTrashAction && notes.isNotEmpty)
          AppIconButton.secondary(
            icon: Icons.delete_sweep,
            tooltip: 'Empty Trash',
            onPressed: () {
              onUserInteraction?.call();
              onEmptyTrash?.call();
            },
          ),
        const AppGap.h12(),
      ],
      body: content,
    );
  }
}
