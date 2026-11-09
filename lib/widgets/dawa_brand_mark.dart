import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Refined DAWA brand mark.
///
/// A deep-purple app-icon tile carrying a diagonal capsule. The capsule is
/// split by a hairline gap into two halves: a white half with the medical plus
/// cut out of it as true negative space, and a soft lavender half. Everything
/// is drawn from geometry, so it stays crisp at any size.
class DawaBrandMark extends StatelessWidget {
  final double size;
  const DawaBrandMark({super.key, this.size = 112});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  static const Color _ink = Color(0xFF0B0A2E);
  static const Color _lilac = Color(0xFFDDD6FE);
  static const Color _mist = Color(0xFFEDE9FE);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final tile = RRect.fromRectAndRadius(rect, Radius.circular(s * .27));

    // Soft contact shadow beneath the tile.
    canvas.drawRRect(
      tile.shift(Offset(0, s * .07)),
      Paint()
        ..color = _ink.withAlpha(120)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .10),
    );

    // Tile body.
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.violet, C.purple, C.indigo],
          stops: [0, .5, 1],
        ).createShader(rect),
    );

    // Gentle top sheen for a subtle dimensional quality.
    canvas.save();
    canvas.clipRRect(tile);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withAlpha(46), Colors.white.withAlpha(0)],
          stops: const [0, .55],
        ).createShader(rect),
    );
    canvas.restore();

    // Fine light-catching edge.
    canvas.drawRRect(
      tile.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, s * .008)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withAlpha(95), Colors.white.withAlpha(8)],
        ).createShader(rect),
    );

    // Capsule, drawn in a frame rotated -45 degrees about the tile centre.
    final len = s * .60;
    final thick = s * .27;
    final gap = s * .02;

    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate(-math.pi / 4);

    final capsule = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: len, height: thick),
        Radius.circular(thick / 2),
      ));

    // Shadow of the capsule (offset straight down in screen space).
    final d = s * .035;
    canvas.drawPath(
      capsule.shift(Offset(-d * .7071, d * .7071)),
      Paint()
        ..color = _ink.withAlpha(110)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .03),
    );

    final leftRect = Rect.fromLTRB(-len / 2, -thick / 2, -gap / 2, thick / 2);
    final rightRect = Rect.fromLTRB(gap / 2, -thick / 2, len / 2, thick / 2);

    var left = Path.combine(
        PathOperation.intersect, capsule, Path()..addRect(leftRect));
    final right = Path.combine(
        PathOperation.intersect, capsule, Path()..addRect(rightRect));

    // Medical plus as negative space inside the white half.
    final cx = (leftRect.left + leftRect.right) / 2;
    final arm = thick * .54;
    final bar = thick * .17;
    final r = Radius.circular(bar * .22);
    final plus = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 0), width: arm, height: bar), r))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 0), width: bar, height: arm), r));
    left = Path.combine(PathOperation.difference, left, plus);

    canvas.drawPath(
      left,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, _mist],
        ).createShader(leftRect),
    );
    canvas.drawPath(
      right,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lilac, C.lavender],
        ).createShader(rightRect),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}