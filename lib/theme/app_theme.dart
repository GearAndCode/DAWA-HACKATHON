import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized DAWA Brand Color Tokens
class C {
  static const Color indigo = Color(0xFF312E81);     // Deep Royal Indigo
  static const Color purple = Color(0xFF6D28D9);     // Premium Purple
  static const Color violet = Color(0xFF8B5CF6);     // Electric Violet
  static const Color lavender = Color(0xFFA78BFA);   // Soft Lavender
  static const Color white = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFF8F7FC);         // Main Background
  static const Color light = Color(0xFFF1EDFF);      // Light Lavender
  static const Color text = Color(0xFF211E3B);       // Primary Text
  static const Color sub = Color(0xFF77758A);        // Secondary Text
  static const Color border = Color(0xFFE9E6F0);     // Subtle Border
  static const Color green = Color(0xFF24845A);      // Success Green
  static const Color amber = Color(0xFFD97706);      // Warning Amber
  static const Color red = Color(0xFFDC2626);        // Error Red
  static const Color surface = Color(0xFFFFFFFF);

  static Color a(Color c, double o) => c.withValues(alpha: o);
}

/// Centralized Typography helpers
TextStyle t(double size, {
  FontWeight w = FontWeight.w400,
  Color c = C.text,
  double h = 1.35,
  double? ls,
}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
      letterSpacing: ls,
    );

TextStyle ar(double size, {
  FontWeight w = FontWeight.w500,
  Color c = C.text,
  double h = 1.6,
}) =>
    GoogleFonts.notoSansArabic(
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
    );

/// Sophisticated Shadow Hierarchy
class DawaShadows {
  static final List<BoxShadow> subtle = [
    BoxShadow(
      color: const Color(0xFF312E81).withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static final List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF312E81).withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: const Color(0xFF6D28D9).withValues(alpha: 0.03),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> elevated = [
    BoxShadow(
      color: const Color(0xFF312E81).withValues(alpha: 0.10),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF6D28D9).withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> purpleGlow = [
    BoxShadow(
      color: const Color(0xFF6D28D9).withValues(alpha: 0.22),
      blurRadius: 24,
      spreadRadius: 1,
      offset: const Offset(0, 6),
    ),
  ];

  static final List<BoxShadow> navBar = [
    BoxShadow(
      color: const Color(0xFF211E3B).withValues(alpha: 0.08),
      blurRadius: 30,
      offset: const Offset(0, -6),
    ),
    BoxShadow(
      color: const Color(0xFF6D28D9).withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, -2),
    ),
  ];
}

const List<BoxShadow> softShadow = [
  BoxShadow(color: Color(0x14312E81), blurRadius: 24, offset: Offset(0, 8)),
];

/// Reusable Luxury Card Container
class DawaSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final Border? border;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final bool hasGlow;

  const DawaSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.color,
    this.gradient,
    this.radius = 20,
    this.border,
    this.shadows,
    this.onTap,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(
          color: hasGlow
              ? C.purple.withValues(alpha: 0.5)
              : const Color(0xFFE9E6F0),
          width: hasGlow ? 1.5 : 1.0,
        ),
        boxShadow: shadows ?? (hasGlow ? DawaShadows.purpleGlow : DawaShadows.card),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Illuminated Hero Card with gentle moving ambient glow
class IlluminatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const IlluminatedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
    this.radius = 24,
  });

  @override
  State<IlluminatedCard> createState() => _IlluminatedCardState();
}

class _IlluminatedCardState extends State<IlluminatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final val = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (val * 0.4), -1.0),
              end: Alignment(1.0 - (val * 0.4), 1.0),
              colors: const [
                Color(0xFF312E81),
                Color(0xFF4C1D95),
                Color(0xFF6D28D9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D28D9).withValues(alpha: 0.30 + (val * 0.12)),
                blurRadius: 26 + (val * 8),
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Color.lerp(
                const Color(0xFFA78BFA).withValues(alpha: 0.3),
                const Color(0xFFFFFFFF).withValues(alpha: 0.6),
                val,
              )!,
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.radius),
              onTap: widget.onTap,
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Subtle Animated Entrance Widget (Slide Up & Fade In)
class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double slideOffset;

  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slideOffset = 18.0,
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: widget.slideOffset, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Luxury Status Badge
class DawaBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color text;
  final IconData? icon;

  const DawaBadge({
    super.key,
    required this.label,
    required this.bg,
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: text.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: text),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme Builder
ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.purple,
      primary: C.purple,
      surface: C.white,
    ),
    scaffoldBackgroundColor: C.bg,
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: C.text),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: C.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE9E6F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE9E6F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.purple, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(fontSize: 13.5, color: C.sub),
      hintStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF9CA3AF)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.purple,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: Color(0xFFE9E6F0), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
