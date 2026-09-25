/// Open-Meteo ensemble client. Free, no API key, no account.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:umbrella/core/settings.dart';

/// ICON is the only Open-Meteo ensemble with true hourly precipitation
/// (40 members). ECMWF and GFS ensembles spread each 3-hour total evenly over
/// three hours, which would hide a short shower from a per-hour threshold.
const String ensembleModel = 'icon_seamless';

/// Four days reach Monday from a Friday fetch, which is what the offline
/// fallback leans on after a weekend with no checks.
const int forecastDays = 4;

/// The request URL for [place].
Uri ensembleUri(Place place) =>
    Uri.https('ensemble-api.open-meteo.com', '/v1/ensemble', {
      'latitude': place.lat.toStringAsFixed(4),
      'longitude': place.lon.toStringAsFixed(4),
      'hourly': 'rain,showers',
      'models': ensembleModel,
      'timeformat': 'unixtime',
      'forecast_days': '$forecastDays',
    });

/// Fetches the raw JSON for [place]. Throws on any network/HTTP/JSON error;
/// the caller falls back to the cache.
Future<Map<String, dynamic>> fetchEnsemble(
  http.Client client,
  Place place,
) async {
  final res = await client
      .get(ensembleUri(place))
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw http.ClientException('HTTP ${res.statusCode}: ${res.body}');
  }
  return jsonDecode(res.body) as Map<String, dynamic>;
}
