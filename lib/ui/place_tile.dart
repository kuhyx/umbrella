/// A settings row for one saved place: GPS button, manual entry, clear.
library;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:umbrella/core/settings.dart';

/// Returns the phone's current (coarse) position, or throws.
typedef Locate = Future<Place> Function();

/// Default [Locate]: coarse GPS through geolocator.
Future<Place> locateWithGps() async {
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    throw StateError('Location permission denied');
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
  );
  return Place(lat: pos.latitude, lon: pos.longitude);
}

/// Parses "52.2297, 21.0122" (comma and/or spaces). Null if invalid.
Place? parsePlace(String text) {
  final parts = text
      .split(RegExp(r'[,\s]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0]);
  final lon = double.tryParse(parts[1]);
  if (lat == null || lon == null) return null;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return Place(lat: lat, lon: lon);
}

/// One place row - text-free, uses icons and semantic labels.
class PlaceTile extends StatelessWidget {
  /// Creates the row.
  const PlaceTile({
    required this.title,
    required this.place,
    required this.onChanged,
    required this.locate,
    this.onClear,
    super.key,
  });

  /// "Home" / "Destination" - semantic label only.
  final String title;

  /// Current value.
  final Place? place;

  /// Called with the new place.
  final ValueChanged<Place> onChanged;

  /// GPS lookup.
  final Locate locate;

  /// If set, shows a clear button.
  final VoidCallback? onClear;

  Future<void> _useGps(BuildContext context) async {
    try {
      onChanged(await locate());
    } on Object catch (e) {
      if (context.mounted) _showError(context, "Couldn't get location: $e");
    }
  }

  Future<void> _type(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) =>
          _CoordsDialog(semanticLabel: title, initial: place?.label ?? ''),
    );
    if (text == null || !context.mounted) return;
    final p = parsePlace(text);
    if (p == null) {
      _showError(context, 'Use "latitude, longitude"');
    } else {
      onChanged(p);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          label: message,
          excludeSemantics: true,
          child: const Icon(Icons.error_outline),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final hasPlace = place != null;
    return Semantics(
      label: '$title${hasPlace ? ', ${place!.label}' : ', not set'}',
      child: ListTile(
        leading: Icon(
          title == 'Home' ? Icons.home_outlined : Icons.flag_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Semantics(
          label: title,
          child: hasPlace
              ? Text(place!.label, style: theme.textTheme.bodyMedium)
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Icon(Icons.remove, color: muted),
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _useGps(context),
              icon: const Icon(Icons.my_location),
              iconSize: 20,
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
              tooltip: '', // empty - semantic label on parent
            ),
            IconButton(
              onPressed: () => _type(context),
              icon: const Icon(Icons.edit_outlined),
              iconSize: 20,
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
            if (onClear != null && hasPlace)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close),
                iconSize: 20,
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Coordinates input dialog - text-free with semantic labels.
class _CoordsDialog extends StatefulWidget {
  const _CoordsDialog({required this.semanticLabel, required this.initial});

  final String semanticLabel;
  final String initial;

  @override
  State<_CoordsDialog> createState() => _CoordsDialogState();
}

class _CoordsDialogState extends State<_CoordsDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Semantics(
      label: widget.semanticLabel,
      child: const SizedBox.shrink(),
    ),
    content: TextField(
      key: const Key('coords-field'),
      controller: _ctrl,
      decoration: const InputDecoration(
        hintText: '52.2297, 21.0122', // format example - KEEP
        border: OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Semantics(label: 'Cancel', child: const Icon(Icons.close)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _ctrl.text),
        child: Semantics(label: 'Save', child: const Icon(Icons.check)),
      ),
    ],
  );
}
