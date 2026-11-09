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
  final Widget? trailing;
  final bool animate;

  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle = '',
    this.trailing,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t(19, w: FontWeight.w800, c: C.text, ls: -0.3),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: t(13.5, c: C.sub, h: 1.35),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (animate) {
      return FadeSlideEntrance(
        slideOffset: 12,
        child: content,
      );
    }
    return content;
  }
}

class DawaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final bool shadow;
  final double radius;
  final Border? border;

  const DawaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.color,
    this.gradient,
    this.onTap,
    this.shadow = true,
    this.radius = 20,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: const Color(0xFFE9E6F0), width: 1.0),
        boxShadow: shadow ? DawaShadows.card : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: card,
        ),
      );
    }
    return card;
  }
}

class IconChip extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? bg;
  final Color? fg;
  final double iconSize;

  const IconChip(
    this.icon, {
    super.key,
    this.size = 46,
    this.bg,
    this.fg,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? C.light,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: (fg ?? C.purple).withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: fg ?? C.purple,
      ),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 280,
    this.spacing = 14,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = (constraints.maxWidth / minTileWidth).floor().clamp(1, 4);
        final itemWidth = (constraints.maxWidth - (spacing * (crossCount - 1))) / crossCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in children)
              SizedBox(width: itemWidth, child: c),
          ],
        );
      },
    );
  }
}

class MedicineTile extends StatelessWidget {
  final Medicine m;
  const MedicineTile(this.m, {super.key});

  @override
  Widget build(BuildContext context) {
    return DawaSurface(
      onTap: () => showMedicineSheet(context, m),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const IconChip(Icons.medication_outlined, size: 42, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: t(14.5, w: FontWeight.w700)),
                Text('${m.strength} • ${m.form}', style: t(12, c: C.sub)),
              ],
            ),
          ),
          const DawaBadge(
            label: 'In Stock',
            bg: Color(0xFFDCFCE7),
            text: Color(0xFF15803D),
          ),
        ],
      ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(Icons.medication_outlined, size: 50, iconSize: 24),
              const SizedBox(width: 14),
              Expanded(child: Text(m.name, style: t(20, w: FontWeight.w800, c: C.indigo))),
            ],
          ),
          const SizedBox(height: 18),
          _detailRow('Strength', m.strength),
          _detailRow('Form', m.form),
          _detailRow('Category', m.category),
          _detailRow('Availability', 'Verified in demo catalogue'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(14)),
            child: Text(
              'This is clinical reference data. Always follow physician dosage instructions.',
              style: t(12.5, c: C.indigo, h: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _detailRow(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(k, style: t(13.5, c: C.sub))),
          Expanded(child: Text(v, style: t(13.5, w: FontWeight.w600, c: C.text))),
        ],
      ),
    );

class PharmacyCard extends StatelessWidget {
  final Pharmacy p;
  final VoidCallback onTap;
  const PharmacyCard(this.p, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DawaSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(p.icon, size: 46, iconSize: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(p.name,
                    maxLines: 2, style: t(15.5, w: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: C.sub),
              const SizedBox(width: 4),
              Expanded(child: Text(p.area, style: t(12.5, c: C.sub))),
            ],
          ),
          const SizedBox(height: 6),
          Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(12.5, c: C.sub)),
          const SizedBox(height: 12),
          Row(
            children: [
              const DawaBadge(
                label: 'Available',
                bg: Color(0xFFDCFCE7),
                text: Color(0xFF15803D),
              ),
              const Spacer(),
              Text('View Details', style: t(12.5, w: FontWeight.w700, c: C.purple)),
              const Icon(Icons.chevron_right_rounded, color: C.purple, size: 18),
            ],
          ),
        ],
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
          child: Column(
            children: [
              IconChip(icon, size: 64, iconSize: 30),
              const SizedBox(height: 16),
              Text(title, style: t(17, w: FontWeight.w700)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(message, textAlign: TextAlign.center, style: t(13.5, c: C.sub, h: 1.4)),
              ),
            ],
          ),
        ),
      );
}

class PageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final bool resizeToAvoidBottomInset;

  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottomBar,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        title: Text(
          title,
          style: t(19.5, w: FontWeight.w800, c: C.text, ls: -0.2),
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: child,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
