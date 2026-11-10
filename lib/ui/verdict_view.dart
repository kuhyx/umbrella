/// The Today screen's body: a huge umbrella (or a crossed-out one), the
/// answer icon, and an hour-by-hour strip for the outing only.
library;

import 'package:flutter/material.dart';
import 'package:umbrella/core/schedule.dart';
import 'package:umbrella/core/verdict.dart';
import 'package:umbrella/ui/umbrella_glyph.dart';

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// Shows [verdict] for [outing] using icons and semantic labels.
class VerdictView extends StatelessWidget {
  /// Creates the view.
  const VerdictView({
    required this.verdict,
    required this.outing,
    required this.threshold,
    required this.footer,
    required this.footerLabel,
    super.key,
  });

  /// The answer.
  final Verdict verdict;

  /// The outing it answers.
  final Outing outing;

  /// Share at which an hour counts as rainy (for the strip's colour).
  final double threshold;

  /// Visible footer: check time plus variant count or the offline mark.
  final String footer;

  /// Spoken footer: the same facts in words, for screen readers only.
  final String footerLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yes = verdict.umbrella;
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: UmbrellaGlyph(
                size: MediaQuery.sizeOf(context).width * 0.6,
                crossed: !yes,
                color: yes ? primary : muted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Answer icon + semantic label
          Semantics(
            key: const Key('verdict-title'),
            label: yes ? '☂️' : '🌤️',
            child: Icon(
              yes ? Icons.wb_sunny_outlined : Icons.umbrella_outlined,
              size: 48,
              color: yes ? primary : muted,
            ),
          ),
          const SizedBox(height: 8),
          // Percentage as number + bar (second channel)
          _PercentageBar(
            value: yes ? verdict.rainPct : verdict.confidencePct,
            color: yes ? primary : muted,
            semanticLabel: yes
                ? '💧 ${verdict.rainPct}%'
                : '✓ ${verdict.confidencePct}%',
          ),
          const SizedBox(height: 8),
          // Time range
          Semantics(
            label: 'Out ${_hm(outing.leave)} to ${_hm(outing.back)}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 16, color: muted),
                const SizedBox(width: 8),
                Text(
                  // Numbers are KEEP per replacement catalogue
                  '${_hm(outing.leave)} – ${_hm(outing.back)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          HourStrip(hours: verdict.hours, threshold: threshold),
          const SizedBox(height: 16),
          // Footer: digits and icons shown, words spoken only.
          Semantics(
            label: footerLabel,
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: muted),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    footer,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Number + progress bar with semantic label (replacement catalogue row 28).
class _PercentageBar extends StatelessWidget {
  const _PercentageBar({
    required this.value,
    required this.color,
    required this.semanticLabel,
  });

  final int value;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: value / 100,
              color: color,
              backgroundColor: color.withValues(alpha: 0.2),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Hour numbers are KEEP per replacement catalogue row 33
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
