/// Settings: places, weekly plan, notify offset, rain threshold.
library;

import 'package:design_system/design_system.dart' hide SectionHeader;
import 'package:flutter/material.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/services/store.dart';
import 'package:umbrella/ui/place_tile.dart';
import 'package:umbrella/ui/section_header.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _hm(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:'
    '${(min % 60).toString().padLeft(2, '0')}';

/// The settings screen. Every change is saved immediately; the Today screen
/// re-arms the alarm when this one closes.
class SettingsScreen extends StatefulWidget {
  /// Creates the screen.
  const SettingsScreen({
    required this.store,
    this.locate = locateWithGps,
    super.key,
  });

  /// Persistent state.
  final Store store;

  /// GPS lookup (injectable for tests).
  final Locate locate;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings _s = widget.store.settings;

  Future<void> _save(Settings s) async {
    setState(() => _s = s);
    await widget.store.saveSettings(s);
  }

  Future<void> _setDay(int i, DayPlan plan) async {
    final days = [..._s.days]..[i] = plan;
    await _save(_s.copyWith(days: days));
  }

  Future<int?> _pickTime(int min) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: min ~/ 60, minute: min % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Widget _dayRow(int i) {
    final d = _s.days[i];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Semantics(
            label: _dayNames[i],
            child: SizedBox(width: 48, child: _WeekDots(index: i)),
          ),
          Switch(
            key: Key('day-$i'),
            value: d.enabled,
            onChanged: (v) => _setDay(i, d.copyWith(enabled: v)),
          ),
          const Spacer(),
          TextButton(
            onPressed: d.enabled
                ? () async {
                    final m = await _pickTime(d.leaveMin);
                    if (m != null) await _setDay(i, d.copyWith(leaveMin: m));
                  }
                : null,
            child: Text(_hm(d.leaveMin)),
          ),
          Icon(Icons.arrow_forward, size: 16, color: muted),
          TextButton(
            onPressed: d.enabled
                ? () async {
                    final m = await _pickTime(d.backMin);
                    if (m != null) await _setDay(i, d.copyWith(backMin: m));
                  }
                : null,
            child: Text(_hm(d.backMin)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          const SectionHeader('Places', icon: Icons.place_outlined),
          PlaceTile(
            title: 'Home',
            place: _s.home,
            locate: widget.locate,
            onChanged: (p) => _save(_s.copyWith(home: p)),
          ),
          PlaceTile(
            title: 'Destination (optional)',
            place: _s.destination,
            locate: widget.locate,
            onChanged: (p) => _save(_s.copyWith(destination: p)),
            onClear: () => _save(_s.copyWith(clearDestination: true)),
          ),
          const SectionHeader(
            'When you are out',
            icon: Icons.calendar_today_outlined,
          ),
          for (var i = 0; i < 7; i++) _dayRow(i),
          const SectionHeader(
            'Notification',
            icon: Icons.notifications_outlined,
          ),
          ListTile(
            title: Semantics(
              label: '${_s.notifyOffsetMin} min before leaving',
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  ExcludeSemantics(child: Text('${_s.notifyOffsetMin}')),
                ],
              ),
            ),
            subtitle: Slider(
              value: _s.notifyOffsetMin.toDouble(),
              min: 10,
              max: 120,
              divisions: 22,
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(notifyOffsetMin: v.round())),
              onChangeEnd: (v) =>
                  _save(_s.copyWith(notifyOffsetMin: v.round())),
            ),
          ),
          ListTile(
            title: Semantics(
              label: 'Umbrella from ${_s.thresholdPct}% chance of rain',
              child: Row(
                children: [
                  const Icon(Icons.water_drop_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  ExcludeSemantics(child: Text('${_s.thresholdPct}%')),
                ],
              ),
            ),
            subtitle: Slider(
              value: _s.thresholdPct.toDouble(),
              min: 10,
              max: 90,
              divisions: 16,
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(thresholdPct: v.round())),
              onChangeEnd: (v) => _save(_s.copyWith(thresholdPct: v.round())),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seven dots with the [index]-th one filled: a word-free weekday mark.
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var j = 0; j < 7; j++)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: j == index ? scheme.primary : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
