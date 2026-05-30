import 'package:flutter/material.dart';
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
      return Colors.grey.withOpacity(0.3);
    }
    try {
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return Colors.grey.withOpacity(0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final cardBorder = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final categoryColor = _parseCategoryColor(category?.colorHex);

    final titleWidget = Text(
      note.title.isEmpty ? 'Untitled' : note.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: note.title.isEmpty
            ? theme.textTheme.titleMedium?.color?.withOpacity(0.4)
            : theme.textTheme.titleMedium?.color,
      ),
    );

    final bodyWidget = Text(
      note.body.isEmpty ? 'No content' : note.body,
      maxLines: isGrid ? 4 : 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: note.body.isEmpty
            ? theme.textTheme.bodyMedium?.color?.withOpacity(0.4)
            : theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (category != null)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: categoryColor.withOpacity(0.3), width: 0.8),
              ),
              child: Text(
                category!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );

    final contentWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onFavoriteTap,
                icon: Icon(
                  note.isFavorite ? Icons.star : Icons.star_border,
                  size: 20,
                  color: note.isFavorite ? Colors.amber : theme.iconTheme.color?.withOpacity(0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          bodyWidget,
          const SizedBox(height: 12),
          footerWidget,
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: contentWidget,
          ),
        ),
      ),
    );
  }
}
