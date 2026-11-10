/// Notification wording. Kept pure so the exact text is under test.
library;

import 'package:umbrella/core/verdict.dart';

/// A notification's title and body.
typedef Alert = ({String title, String body});

String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

/// Verdict pictogram — emoji + digits only, no English words.
///
/// [staleness] is set when the verdict came from a cached forecast because
/// the live fetch failed; the body then appends how old it is.
Alert verdictMessage(
  Verdict v, {
  required double threshold,
  Duration? staleness,
  bool flipped = false,
}) {
  final prefix = flipped ? '🔄 ' : '';
  final String title;
  final String body;
  if (v.umbrella) {
    title = '$prefix☂️';
    final span = v.wetSpan(threshold);
    final when = span == null
        ? ''
        : ' · ${_hh(span.$1.toLocal())}–${_hh(span.$2.toLocal())}';
    body = '💧 ${v.rainPct}%$when';
  } else {
    title = '$prefix🌤️';
    body = '✓ ${v.confidencePct}%';
  }
  if (staleness == null) return (title: title, body: body);
  final hours = staleness.inHours;
  final age = hours >= 1 ? '${hours}h' : '${staleness.inMinutes}m';
  return (title: title, body: '$body · 📴 $age');
}

/// Sent instead of a verdict when there is neither a live nor a cached
/// forecast -- silence would read as "no rain", which is the wrong default.
const Alert cannotCheck = (title: '☂️❓', body: '📴');

/// Sent when home is not set yet, so the user knows why nothing is decided.
const Alert noHome = (title: '🏠❓', body: '⚙️');
