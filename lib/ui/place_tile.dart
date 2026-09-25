/// A settings row for one saved place: GPS button, manual entry, clear.
library;

import 'package:design_system/design_system.dart';
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

/// One place row.
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

  /// "Home" / "Destination".
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
      if (context.mounted) showError(context, "Couldn't get location: $e");
    }
  }

  Future<void> _type(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _CoordsDialog(title: title, initial: place?.label ?? ''),
    );
    if (text == null || !context.mounted) return;
    final p = parsePlace(text);
    if (p == null) {
      showError(context, 'Use "latitude, longitude"');
    } else {
      onChanged(p);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Text(place?.label ?? 'Not set'),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '$title: use current location',
          onPressed: () => _useGps(context),
          icon: const Icon(Icons.my_location),
        ),
        IconButton(
          tooltip: '$title: type coordinates',
          onPressed: () => _type(context),
          icon: const Icon(Icons.edit_outlined),
        ),
        if (onClear != null && place != null)
          IconButton(
            tooltip: '$title: clear',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
      ],
    ),
  );
}

/// Owns its controller, so it is disposed only after the dialog's exit
/// animation (disposing it right after `showDialog` returns crashes it).
class _CoordsDialog extends StatefulWidget {
  const _CoordsDialog({required this.title, required this.initial});

  final String title;
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
    title: Text(widget.title),
    content: TextField(
      key: const Key('coords-field'),
      controller: _ctrl,
      decoration: const InputDecoration(hintText: '52.2297, 21.0122'),
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _ctrl.text),
        child: const Text('Save'),
      ),
    ],
  );
}
