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

  Color _parseCategoryColor(String? hexString) {
    if (hexString == null || hexString.length != 6) {
      return Colors.grey.withValues(alpha: 0.3);
    }
    try {
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return Colors.grey.withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _parseCategoryColor(category?.colorHex);

    final titleWidget = Text(
      note.title.isEmpty ? 'Untitled' : note.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: note.title.isEmpty
            ? theme.textTheme.titleMedium?.color?.withValues(alpha: 0.4)
            : theme.textTheme.titleMedium?.color,
      ),
    );

    final bodyWidget = Text(
      note.body.isEmpty ? 'No content' : note.body,
      maxLines: isGrid ? 4 : 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyMedium.copyWith(
        color: note.body.isEmpty
            ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4)
            : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
      ),
    );

    final footerWidget = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _formatRelativeTime(note.updatedAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
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
      padding: EdgeInsets.zero, // Padding handles internal structure
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
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onFavoriteTap,
                  icon: Icon(
                    note.isFavorite ? Icons.star : Icons.star_border,
                    size: 20,
                    color: note.isFavorite ? Colors.amber : theme.iconTheme.color?.withValues(alpha: 0.4),
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
