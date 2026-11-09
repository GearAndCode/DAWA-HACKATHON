import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';

/// DAWA logo: gradient tile with a capsule carrying a medical plus.
class DawaLogo extends StatelessWidget {
  final double size;
  const DawaLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.indigo, C.purple, C.violet],
        ),
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: [
          BoxShadow(
              color: C.a(C.purple, .35),
              blurRadius: size * .4,
              offset: Offset(0, size * .12)),
        ],
      ),
      child: CustomPaint(painter: _CapsulePainter()),
    );
  }
}

class _CapsulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = size.width * .62, h = size.width * .30;
    final cap = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Radius.circular(h / 2));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-math.pi / 4);
    canvas.save();
    canvas.clipRRect(cap);
    canvas.drawRect(Rect.fromLTWH(-w / 2, -h / 2, w / 2, h),
        Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(0, -h / 2, w / 2, h),
        Paint()..color = const Color(0xFFDDD6FE));
    canvas.restore();
    final p = Paint()
      ..color = C.indigo
      ..strokeWidth = h * .15
      ..strokeCap = StrokeCap.round;
    final pc = Offset(-w / 4, 0);
    final s = h * .22;
    canvas.drawLine(pc + Offset(-s, 0), pc + Offset(s, 0), p);
    canvas.drawLine(pc + Offset(0, -s), pc + Offset(0, s), p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple two-tone capsule used in illustrations.
class CapsuleShape extends StatelessWidget {
  final double length, thickness, angle;
  final Color a, b;
  const CapsuleShape(
      {super.key,
      this.length = 60,
      this.thickness = 24,
      this.angle = -math.pi / 4,
      this.a = C.purple,
      this.b = C.lavender});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(thickness / 2),
        child: SizedBox(
          width: length,
          height: thickness,
          child: Row(children: [
            Expanded(child: Container(color: a)),
            Expanded(child: Container(color: b)),
          ]),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const SectionHeader(this.title, this.subtitle, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: t(22, w: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(subtitle, style: t(14, c: C.sub)),
      const SizedBox(height: 16),
    ]);
  }
}

class DawaCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsets padding;
  final bool shadow;
  final BoxBorder? border;
  const DawaCard(
      {super.key,
      required this.child,
      this.onTap,
      this.color = Colors.white,
      this.padding = const EdgeInsets.all(18),
      this.shadow = true,
      this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: border ?? Border.all(color: C.border),
        boxShadow: shadow ? softShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class IconChip extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color bg, fg;
  const IconChip(this.icon,
      {super.key, this.size = 44, this.bg = C.light, this.fg = C.purple});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: fg, size: size * .52),
      );
}

/// Wrap-based responsive grid with equal tile widths.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth, spacing;
  const ResponsiveGrid(
      {super.key,
      required this.children,
      this.minTileWidth = 160,
      this.spacing = 14});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = math.max(1, ((c.maxWidth + spacing) / (minTileWidth + spacing)).floor());
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class MedicineTile extends StatelessWidget {
  final Medicine m;
  const MedicineTile(this.m, {super.key});

  @override
  Widget build(BuildContext context) {
    return DawaCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showMedicineSheet(context, m),
      child: Row(children: [
        const IconChip(Icons.medication_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m.name} ${m.strength}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(15, w: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${m.category} • ${m.form}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t(12.5, c: C.sub)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: C.a(C.green, .1), borderRadius: BorderRadius.circular(8)),
          child: Text('Demo', style: t(11, w: FontWeight.w600, c: C.green)),
        ),
      ]),
    );
  }
}

void showMedicineSheet(BuildContext context, Medicine m) {
  markViewed(m);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconChip(Icons.medication_outlined, size: 52),
          const SizedBox(width: 14),
          Expanded(child: Text(m.name, style: t(22, w: FontWeight.w700))),
        ]),
        const SizedBox(height: 18),
        _row('Strength', m.strength),
        _row('Form', m.form),
        _row('Category', m.category),
        _row('Availability', 'Demo data only - not live pharmacy stock'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(14)),
          child: Text(
              'This is general product information, not medical advice. Ask a doctor or pharmacist before using any medicine.',
              style: t(13, c: C.indigo)),
        ),
      ]),
    ),
  );
}

Widget _row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(k, style: t(14, c: C.sub))),
        Expanded(child: Text(v, style: t(14, w: FontWeight.w600))),
      ]),
    );

class PharmacyCard extends StatelessWidget {
  final Pharmacy p;
  final VoidCallback onTap;
  const PharmacyCard(this.p, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DawaCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconChip(p.icon, size: 50),
          const SizedBox(width: 12),
          Expanded(
              child: Text(p.name,
                  maxLines: 2, style: t(16, w: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 16, color: C.sub),
          const SizedBox(width: 4),
          Expanded(child: Text(p.area, style: t(13, c: C.sub))),
        ]),
        const SizedBox(height: 8),
        Text(p.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: t(13.5, c: C.sub)),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: C.a(C.green, .1), borderRadius: BorderRadius.circular(10)),
            child: Text('Demo: Available',
                style: t(12, w: FontWeight.w600, c: C.green)),
          ),
          const Spacer(),
          Text('View Pharmacy', style: t(13, w: FontWeight.w600, c: C.purple)),
          const Icon(Icons.chevron_right_rounded, color: C.purple, size: 20),
        ]),
      ]),
    );
  }
}

/// Standard inner-page scaffold with centered max-width body.
class PageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const PageScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const EmptyState(this.icon, this.title, this.message, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Column(children: [
            IconChip(icon, size: 64),
            const SizedBox(height: 16),
            Text(title, style: t(17, w: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: t(14, c: C.sub)),
          ]),
        ),
      );
}
