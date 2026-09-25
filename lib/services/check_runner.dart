/// One check: fetch (or fall back to cache), decide, save, maybe notify.
library;

import 'package:umbrella/core/forecast.dart';
import 'package:umbrella/core/message.dart';
import 'package:umbrella/core/schedule.dart';
import 'package:umbrella/core/settings.dart';
import 'package:umbrella/core/verdict.dart';
import 'package:umbrella/services/store.dart';

/// Fetches the raw ensemble JSON for a place; throws on failure.
typedef Fetch = Future<Map<String, dynamic>> Function(Place place);

/// Posts a notification.
typedef Notify = Future<void> Function(Alert message);

/// A verdict plus how old its data is (null = live).
typedef Evaluation = ({Verdict verdict, Duration? staleness});

/// Decides [outing] from live data, falling back per place to the cache.
/// Returns null if neither live nor cached data covers the outing.
Future<Evaluation?> evaluate({
  required Settings settings,
  required Outing outing,
  required DateTime now,
  required Fetch fetch,
  required Store store,
}) async {
  final forecasts = <EnsembleForecast>[];
  Duration? staleness;
  for (final place in settings.places) {
    try {
      final json = await fetch(place);
      forecasts.add(EnsembleForecast.fromOpenMeteo(json));
      await store.saveForecast(place, json, now);
    } on Object {
      final cached = store.cachedForecast(place);
      if (cached == null) continue;
      forecasts.add(EnsembleForecast.fromOpenMeteo(cached.json));
      final age = now.difference(cached.fetchedAt);
      if (staleness == null || age > staleness) staleness = age;
    }
  }
  final verdict = decide(
    forecasts: forecasts,
    start: outing.leave,
    end: outing.back,
    threshold: settings.thresholdPct / 100,
  );
  if (verdict == null) return null;
  return (verdict: verdict, staleness: staleness);
}

/// Runs the alarm for [kind] at [now]. The main check always notifies (a
/// verdict, "couldn't check", or "set your home"); the re-check notifies only
/// when the answer flipped since the main one, or when the main one never
/// produced an answer.
Future<void> runCheck({
  required CheckKind kind,
  required DateTime now,
  required Store store,
  required Fetch fetch,
  required Notify notify,
}) async {
  final settings = store.settings;
  final outing = currentOuting(settings, now);
  if (outing == null) return;
  if (settings.home == null) {
    if (kind == CheckKind.main) await notify(noHome);
    return;
  }
  final prev = store.lastVerdict;
  final hadAnswer = prev != null && prev.leave == outing.leave;
  final result = await evaluate(
    settings: settings,
    outing: outing,
    now: now,
    fetch: fetch,
    store: store,
  );
  if (result == null) {
    if (kind == CheckKind.main || !hadAnswer) await notify(cannotCheck);
    return;
  }
  final v = result.verdict;
  await store.saveVerdict(
    v,
    outing.leave,
    now,
    stale: result.staleness != null,
  );
  final flipped = hadAnswer && prev.verdict.umbrella != v.umbrella;
  if (kind == CheckKind.recheck && hadAnswer && !flipped) return;
  await notify(
    verdictMessage(
      v,
      threshold: settings.thresholdPct / 100,
      staleness: result.staleness,
      flipped: kind == CheckKind.recheck && flipped,
    ),
  );
}
