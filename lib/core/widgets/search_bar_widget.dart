import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const SearchBarWidget({
    super.key,
    this.hintText = 'Search your notes...',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.controller,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final barBg = isDark ? Colors.grey[900]! : Colors.grey[100]!;
    final barBorder = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: barBorder, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search,
                  color: theme.iconTheme.color?.withOpacity(0.5) ?? Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: readOnly
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            hintText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                            ),
                          ),
                        )
                      : TextField(
                          controller: controller,
                          focusNode: focusNode,
                          readOnly: readOnly,
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                          style: theme.textTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                ),
                if (!readOnly && controller != null)
                  AnimatedBuilder(
                    animation: controller!,
                    builder: (context, _) {
                      if (controller!.text.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          controller!.clear();
                          onChanged?.call('');
                        },
                      );
                    },
                  ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
