/// Notification wording. Kept pure so the exact text is under test.
library;

import 'package:umbrella/core/verdict.dart';

/// A notification's title and body.
typedef Alert = ({String title, String body});

String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

/// "☂️ Take umbrella" / "No umbrella" with the confidence line.
///
/// [staleness] is set when the verdict came from a cached forecast because
/// the live fetch failed; the body then says how old it is.
Alert verdictMessage(
  Verdict v, {
  required double threshold,
  Duration? staleness,
  bool flipped = false,
}) {
  final prefix = flipped ? 'Changed: ' : '';
  final String title;
  final String body;
  if (v.umbrella) {
    title = '$prefix☂️ Take umbrella';
    final span = v.wetSpan(threshold);
    final when = span == null
        ? ''
        : ', mostly ${_hh(span.$1.toLocal())}–${_hh(span.$2.toLocal())}';
    body = '${v.rainPct}% chance of rain$when';
  } else {
    title = '${prefix}No umbrella';
    body = '${v.confidencePct}% sure it stays dry';
  }
  if (staleness == null) return (title: title, body: body);
  final hours = staleness.inHours;
  final age = hours >= 1 ? '${hours}h' : '${staleness.inMinutes} min';
  return (title: title, body: '$body (offline: forecast from $age ago)');
}

/// Sent instead of a verdict when there is neither a live nor a cached
/// forecast -- silence would read as "no rain", which is the wrong default.
const Alert cannotCheck = (
  title: "Couldn't check the rain",
  body: 'No connection and no saved forecast. Look outside before leaving.',
);

/// Sent when home is not set yet, so the user knows why nothing is decided.
const Alert noHome = (
  title: 'Umbrella? needs your home',
  body: 'Open the app and set your home location.',
);
