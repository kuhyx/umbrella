/// The Today screen's body: a huge umbrella (or a crossed-out one), the
/// sentence, and an hour-by-hour strip for the outing only.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:umbrella/core/schedule.dart';
import 'package:umbrella/core/verdict.dart';
import 'package:umbrella/ui/umbrella_glyph.dart';

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// Shows [verdict] for [outing].
class VerdictView extends StatelessWidget {
  /// Creates the view.
  const VerdictView({
    required this.verdict,
    required this.outing,
    required this.threshold,
    required this.footer,
    super.key,
  });

  /// The answer.
  final Verdict verdict;

  /// The outing it answers.
  final Outing outing;

  /// Share at which an hour counts as rainy (for the strip's colour).
  final double threshold;

  /// "Checked 07:30" / offline note.
  final String footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yes = verdict.umbrella;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Expanded(
            // At most 60% of the screen width; shrinks on short screens.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: UmbrellaGlyph(
                size: MediaQuery.sizeOf(context).width * 0.6,
                crossed: !yes,
                color: yes ? theme.colorScheme.primary : muted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            yes ? 'Take an umbrella' : 'No umbrella',
            key: const Key('verdict-title'),
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            yes
                ? '${verdict.rainPct}% chance of rain'
                : '${verdict.confidencePct}% sure it stays dry',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Out ${_hm(outing.leave)} – ${_hm(outing.back)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          HourStrip(hours: verdict.hours, threshold: threshold),
          const SizedBox(height: AppSpacing.md),
          Text(
            footer,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// One bar per hour of the outing, height = rain share.
class HourStrip extends StatelessWidget {
  /// Creates the strip.
  const HourStrip({required this.hours, required this.threshold, super.key});

  /// Per-hour shares.
  final List<HourChance> hours;

  /// Bars at or above this share use the accent colour.
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in hours)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 4 + 40 * h.share,
                      decoration: BoxDecoration(
                        color: h.share >= threshold
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.sm / 2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      h.start.toLocal().hour.toString(),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
