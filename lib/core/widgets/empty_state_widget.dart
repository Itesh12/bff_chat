import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Decorative background for the icon
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : theme.primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : theme.primaryColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 40,
                  color: theme.primaryColor.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color?.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.55),
                  height: 1.4,
                ),
              ),
            ),
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onCtaTap,
                icon: const Icon(Icons.add, size: 18),
                label: Text(ctaLabel!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRadius.circular(24) as OutlinedBorder?, // wait, RoundedRectangleBorder is correct
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// RoundedRectangleBorder helper since RoundedRadius is not standard flutter class
class RoundedRadius {
  static ShapeBorder circular(double radius) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
