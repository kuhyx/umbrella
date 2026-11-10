/// Text-free SectionHeader replacement: icon + semantic label only.
library;

import 'package:flutter/material.dart';

/// A text-free section header using only an icon and semantic label.
///
/// The old [SectionHeader] from design_system carried a title text and
/// optional action. Here we keep only the icon (if provided) and expose
/// semantics for screen readers.
class SectionHeader extends StatelessWidget {
  /// Creates a text-free section header.
  const SectionHeader(this.semanticLabel, {this.icon, this.padding, super.key});

  /// Spoken label for accessibility.
  final String semanticLabel;

  /// Optional leading icon.
  final IconData? icon;

  /// Outer padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
        ],
        // No visible text - just semantic label
        const SizedBox(width: 0),
      ],
    );
    return Semantics(
      label: semanticLabel,
      header: true,
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: child,
      ),
    );
  }
}
