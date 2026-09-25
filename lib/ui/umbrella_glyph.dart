/// The open umbrella from the launcher icon, drawn at any size, optionally
/// struck through for "no umbrella".
library;

import 'package:flutter/material.dart';

/// Paints the icon-family umbrella: filled scalloped canopy + J handle.
///
/// Geometry mirrors the `umbrella` glyph in testsAndMisc's app_icons (1024
/// canvas), cropped to its ink box 272..752 x 272..792 -> 480 x 520.
class UmbrellaGlyph extends StatelessWidget {
  /// Creates the glyph.
  const UmbrellaGlyph({
    required this.color,
    this.crossed = false,
    this.size = 240,
    super.key,
  });

  /// Ink colour.
  final Color color;

  /// Draws a diagonal strike when true.
  final bool crossed;

  /// Height in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size * 480 / 520, size),
    painter: _UmbrellaPainter(
      color: color,
      crossed: crossed,
      gap: Theme.of(context).scaffoldBackgroundColor,
    ),
  );
}

class _UmbrellaPainter extends CustomPainter {
  _UmbrellaPainter({
    required this.color,
    required this.crossed,
    required this.gap,
  });

  final Color color;
  final bool crossed;

  /// Background colour, used to cut a clean gap either side of the strike
  /// so it stays visible across the filled canopy.
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    // Work in the glyph's own units, origin at the ink box's top-left.
    final k = size.height / 520;
    canvas
      ..save()
      ..scale(k)
      ..translate(-272, -272);
    final fill = Paint()..color = color;
    final canopy = Path()
      ..moveTo(272, 512)
      ..arcToPoint(const Offset(752, 512), radius: const Radius.circular(240));
    for (final x in [592.0, 432.0, 272.0]) {
      canopy.arcToPoint(
        Offset(x, 512),
        radius: const Radius.circular(80),
        clockwise: false,
      );
    }
    canvas.drawPath(canopy..close(), fill);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 72
      ..strokeCap = StrokeCap.round;
    final handle = Path()
      ..moveTo(512, 440)
      ..lineTo(512, 700)
      ..arcToPoint(const Offset(400, 700), radius: const Radius.circular(56));
    canvas.drawPath(handle, stroke);
    if (crossed) {
      const a = Offset(250, 250);
      const b = Offset(774, 774);
      canvas
        ..drawLine(
          a,
          b,
          Paint()
            ..color = gap
            ..strokeWidth = 112
            ..strokeCap = StrokeCap.round,
        )
        ..drawLine(a, b, stroke..strokeWidth = 48);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_UmbrellaPainter old) =>
      old.color != color || old.crossed != crossed || old.gap != gap;
}
