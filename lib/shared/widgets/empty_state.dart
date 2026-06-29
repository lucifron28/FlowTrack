import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 36 : 48,
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: compact ? 6 : 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: compact
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.titleMedium,
            ),
            SizedBox(height: compact ? 2 : 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
