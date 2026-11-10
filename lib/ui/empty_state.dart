/// Text-free EmptyState replacement: icon + semantic label only.
library;

import 'package:flutter/material.dart';

/// A text-free empty state using only an icon and semantic label.
///
/// The old [EmptyState] from design_system carried a title and message.
/// Here we keep only the icon and expose semantics for screen readers.
class EmptyState extends StatelessWidget {
  /// Creates a text-free empty state.
  const EmptyState({
    required this.icon,
    required this.semanticLabel,
    super.key,
  });

  /// Glyph shown centered.
  final IconData icon;

  /// Spoken label for accessibility (e.g. "Where is home?").
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        label: semanticLabel,
        child: Icon(icon, size: 120, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
