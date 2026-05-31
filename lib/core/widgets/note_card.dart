import 'package:flutter/material.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/domain/notes/note_entity.dart';
import 'package:memovault/domain/notes/category_entity.dart';

class NoteCard extends StatelessWidget {
  final NoteEntity note;
  final CategoryEntity? category;
  final bool isGrid;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  const NoteCard({
    super.key,
    required this.note,
    this.category,
    required this.isGrid,
    required this.onTap,
    required this.onFavoriteTap,
  });

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final difference = now.difference(dateTime.toUtc());

    if (difference.inSeconds < 5) {
      return 'Just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    }
  }

  Color _parseCategoryColor(BuildContext context, String? hexString) {
    if (hexString == null || hexString.length != 6) {
      return context.colors.disabled.withValues(alpha: 0.3);
    }
    try {
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return context.colors.disabled.withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _parseCategoryColor(context, category?.colorHex);

    final titleWidget = Text(
      note.title.isEmpty ? 'Untitled' : note.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.titleMedium.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: note.title.isEmpty
            ? theme.textTheme.titleMedium?.color?.withValues(alpha: 0.35)
            : theme.textTheme.titleMedium?.color,
      ),
    );

    final bodyWidget = Text(
      note.body.isEmpty ? 'No content' : note.body,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyMedium.copyWith(
        fontSize: 14,
        height: 1.4,
        color: note.body.isEmpty
            ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.35)
            : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
      ),
    );

    final footerWidget = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
              ),
              const AppGap.h4(),
              Text(
                _formatRelativeTime(note.updatedAt),
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ),
              if (note.isArchived) ...[
                const AppGap.h8(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.archive_outlined, size: 10, color: theme.colorScheme.primary),
                      const AppGap.h4(),
                      Text(
                        'Archived',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const AppGap.h8(),
        if (category != null)
          Flexible(
            child: AppChip(
              label: category!.name,
              color: categoryColor,
            ),
          ),
      ],
    );

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4, horizontal: AppSpacing.s4),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: titleWidget),
                const AppGap.h8(),
                GestureDetector(
                  onTap: onFavoriteTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: Icon(
                      note.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 20,
                      color: note.isFavorite ? Colors.amber : theme.iconTheme.color?.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
            const AppGap.v8(),
            bodyWidget,
            const AppGap.v12(),
            footerWidget,
          ],
        ),
      ),
    );
  }
}
