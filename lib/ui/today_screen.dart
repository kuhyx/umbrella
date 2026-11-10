/// Today: the one answer, big.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:umbrella/core/schedule.dart';
import 'package:umbrella/services/check_runner.dart';
import 'package:umbrella/services/store.dart';
import 'package:umbrella/ui/empty_state.dart';
import 'package:umbrella/ui/settings_screen.dart';
import 'package:umbrella/ui/verdict_view.dart';

/// Arms the next alarm; injected so widget tests need no platform channel.
typedef Arm = Future<void> Function(Store store);

/// The home screen.
class TodayScreen extends StatefulWidget {
  /// Creates the screen.
  const TodayScreen({
    required this.store,
    required this.fetch,
    required this.arm,
    super.key,
  });

  /// Persistent state.
  final Store store;

  /// Forecast fetcher.
  final Fetch fetch;

  /// Re-arms the daily alarm.
  final Arm arm;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    await widget.arm(widget.store);
    final s = widget.store.settings;
    final outing = currentOuting(s, DateTime.now());
    if (s.home == null || outing == null) return setState(() {});
    setState(() => _loading = true);
    final now = DateTime.now();
    final result = await evaluate(
      settings: s,
      outing: outing,
      now: now,
      fetch: widget.fetch,
      store: widget.store,
    );
    if (result != null) {
      await widget.store.saveVerdict(
        result.verdict,
        outing.leave,
        now,
        stale: result.staleness != null,
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(store: widget.store),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const Key('open-settings'),
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: _body(),
  );

  Widget _body() {
    final s = widget.store.settings;
    final outing = currentOuting(s, DateTime.now());
    if (s.home == null) {
      return const EmptyState(
        icon: Icons.home_outlined,
        semanticLabel: 'Where is home?',
      );
    }
    if (outing == null) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        semanticLabel: 'No days planned',
      );
    }
    final saved = widget.store.lastVerdict;
    if (saved == null || saved.leave != outing.leave) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return const EmptyState(
        icon: Icons.cloud_off_outlined,
        semanticLabel: '☂️❓',
      );
    }
    final at = saved.decidedAt;
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    return VerdictView(
      verdict: saved.verdict,
      outing: outing,
      threshold: s.thresholdPct / 100,
      footer: saved.stale ? '🕒 $hm · 📴' : '🕒 $hm · ${saved.verdict.members}',
      footerLabel: saved.stale
          ? 'Checked $hm · 📴 saved'
          : 'Checked $hm · ${saved.verdict.members} variants',
    );
  }
}
