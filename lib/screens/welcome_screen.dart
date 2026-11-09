import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/dawa_brand_mark.dart';
import 'shell.dart';

/// Premium DAWA welcome screen. Replaces only the existing welcome screen.
/// Optional photo asset: assets/images/pharma_scene.png
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _featureGlow;
  late final AnimationController _taglineController;
  Timer? _homeTimer;
  Timer? _featureTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..forward();

    _featureGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Tagline timeline over 5800ms:
    // 0..2000ms: hidden
    // 2000..2600ms: English fades in and slides up
    // 2600..3600ms: English holds
    // 3600..4100ms: English fades out and slides up
    // 4100..4700ms: Urdu fades in and slides up
    // 4700..5800ms: Urdu holds
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5800),
    )..forward();

    _featureTimer = Timer(const Duration(milliseconds: 3900), () {
      if (mounted) _featureGlow.repeat();
    });

    _homeTimer = Timer(const Duration(milliseconds: 5800), _goHome);
  }

  void _goHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 650),
      pageBuilder: (_, __, ___) => const AppShell(),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ));
  }

  @override
  void dispose() {
    _homeTimer?.cancel();
    _featureTimer?.cancel();
    _intro.dispose();
    _featureGlow.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Animation<double> _interval(double start, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17134F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              final bgIn = _interval(0, .20).value;
              return Opacity(
                opacity: bgIn,
                child: const _PurpleAtmosphere(),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (context, boxConstraints) {
                  final size = MediaQuery.sizeOf(context);
                  final compact = size.height < 740;
                  final wide = size.width > 650;
                  final contentWidth = math.min(size.width, wide ? 560.0 : 520.0);

                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: boxConstraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 28 : 20,
                              compact ? 17 : 25,
                              wide ? 28 : 20,
                              compact ? 4 : 12,
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: compact ? 12 : 20),
                                AnimatedBuilder(
                                  animation: _intro,
                                  builder: (context, _) {
                                    final logoIn = _interval(.12, .40).value;
                                    return Opacity(
                                      opacity: logoIn,
                                      child: Transform.scale(
                                        scale: .88 + .12 * logoIn,
                                        child: DawaBrandMark(size: compact ? 86 : 94),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: compact ? 7 : 12),
                                AnimatedBuilder(
                                  animation: _intro,
                                  builder: (context, _) {
                                    final textIn = _interval(.28, .53).value;
                                    return Opacity(
                                      opacity: textIn,
                                      child: Column(
                                        children: [
                                          Text(
                                            'DAWA',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: compact ? 42 : 47,
                                              height: 1,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 5.5,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: C.a(C.lavender, .45),
                                                  blurRadius: 24,
                                                )
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              _brandRule(),
                                              const SizedBox(width: 12),
                                              Text(
                                                'دواء',
                                                textDirection: TextDirection.rtl,
                                                style: GoogleFonts.notoSansArabic(
                                                  fontSize: 27,
                                                  height: 1.35,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFFD9C5FF),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              _brandRule(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: compact ? 8 : 14),
                                SizedBox(
                                  height: compact ? 62 : 72,
                                  child: _AlternatingTaglines(
                                    controller: _taglineController,
                                    compact: compact,
                                  ),
                                ),
                                SizedBox(height: compact ? 8 : 13),
                                AnimatedBuilder(
                                  animation: _intro,
                                  builder: (context, _) {
                                    final panelIn = _interval(.55, .78).value;
                                    return Opacity(
                                      opacity: panelIn,
                                      child: _FeaturePanel(controller: _featureGlow),
                                    );
                                  },
                                ),
                                const Spacer(),
                                AnimatedBuilder(
                                  animation: _intro,
                                  builder: (context, _) {
                                    final artIn = _interval(.68, 1).value;
                                    return Opacity(
                                      opacity: artIn,
                                      child: Transform.translate(
                                        offset: Offset(0, 22 * (1 - artIn)),
                                        child: const _PharmaceuticalArtwork(),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: compact ? 0 : 5),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandRule() => Container(
        width: 52,
        height: 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFE9D5FF)]),
          boxShadow: [BoxShadow(color: C.a(C.lavender, .55), blurRadius: 8)],
        ),
      );
}

class _AlternatingTaglines extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AlternatingTaglines({
    required this.controller,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    // 5800 ms total timeline:
    // English In:  1900..2500ms (0.3276..0.4310) -> fades & slides up into view
    // English Hold: 2500..3500ms                 -> fully visible
    // English Out: 3500..3950ms (0.6034..0.6810) -> fades out & slides up away completely
    // Urdu In:     4050..4650ms (0.6983..0.8017) -> fades in & slides up with zero overlap
    // Urdu Hold:   4650..5800ms                 -> fully visible until navigation
    final enFadeIn = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.3276, 0.4310, curve: Curves.easeOutCubic),
    );
    final enFadeOut = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.6034, 0.6810, curve: Curves.easeInCubic),
    );
    final urFadeIn = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.6983, 0.8017, curve: Curves.easeOutCubic),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        // Responsive font scaling according to the display width and density
        final enFontSize = (screenWidth < 360)
            ? 13.5
            : (screenWidth < 400 ? 15.0 : (compact ? 15.5 : 17.0));
        final urFontSize = (screenWidth < 360)
            ? 16.5
            : (screenWidth < 400 ? 18.0 : (compact ? 19.5 : 22.0));

        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final enInVal = enFadeIn.value;
            final enOutVal = enFadeOut.value;
            final urInVal = urFadeIn.value;

            // Ensure English is 100% hidden before Urdu starts
            final enOpacity = (enInVal * (1.0 - enOutVal)).clamp(0.0, 1.0);
            final enSlide = 10.0 * (1.0 - enInVal) - 8.0 * enOutVal;

            final urOpacity = (controller.value >= 0.6983) ? urInVal.clamp(0.0, 1.0) : 0.0;
            final urSlide = 10.0 * (1.0 - urInVal);

            return Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                if (enOpacity > 0.005)
                  Center(
                    child: Opacity(
                      opacity: enOpacity,
                      child: Transform.translate(
                        offset: Offset(0, enSlide),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Connecting You to Better Healthcare.',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: GoogleFonts.inter(
                                fontSize: enFontSize,
                                color: Colors.white.withValues(alpha: .96),
                                fontWeight: FontWeight.w400,
                                letterSpacing: .1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (urOpacity > 0.005)
                  Center(
                    child: Opacity(
                      opacity: urOpacity,
                      child: Transform.translate(
                        offset: Offset(0, urSlide),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'بہتر صحت، آپ کی دسترس میں۔',
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: GoogleFonts.notoSansArabic(
                                fontSize: urFontSize,
                                height: 1.4,
                                color: const Color(0xFFE6D8FF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PurpleAtmosphere extends StatelessWidget {
  const _PurpleAtmosphere();
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF312078), Color(0xFF1B175D), Color(0xFF100E43)],
              stops: [0, .48, 1],
            ),
          ),
        ),
        Positioned(
            top: -170,
            left: -150,
            child: _glow(390, const Color(0xFFB77BFF), .62)),
        Positioned(
            top: 220,
            right: -230,
            child: _glow(440, const Color(0xFF6D28D9), .26)),
        Positioned(
            bottom: -260,
            left: -150,
            child: _glow(500, const Color(0xFF8B5CF6), .32)),
        Positioned.fill(child: CustomPaint(painter: _WavePainter())),
      ]);

  Widget _glow(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      );
}

class _FeaturePanel extends StatelessWidget {
  final AnimationController controller;
  const _FeaturePanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.description_outlined, 'Prescriptions'),
      (Icons.medication_outlined, 'Medicines'),
      (Icons.storefront_outlined, 'Pharmacies'),
      (Icons.monitor_heart_outlined, 'Healthcare'),
    ];
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final active = (controller.value * 4).floor() % 4;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: const Color(0xFF8B5CF6).withValues(alpha: .16),
            border: Border.all(color: C.a(const Color(0xFFD8B4FE), .42)),
            boxShadow: [
              BoxShadow(
                color: C.a(C.violet, .22),
                blurRadius: 24,
                spreadRadius: 1,
              )
            ],
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == active;
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(
                            left: BorderSide(
                              color: C.a(Colors.white, .24),
                            ),
                          ),
                    borderRadius: BorderRadius.circular(20),
                    gradient: selected
                        ? LinearGradient(
                            colors: [C.a(C.lavender, .26), C.a(C.violet, .03)],
                          )
                        : null,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].$1, color: Colors.white, size: 35),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].$2,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white
                                  .withValues(alpha: selected ? 1 : .88),
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// The optional PNG gives the most photorealistic result. The custom-painted
/// fallback keeps the screen runnable when that asset has not been added yet.
class _PharmaceuticalArtwork extends StatelessWidget {
  const _PharmaceuticalArtwork();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height < 740 ? 190 : 245,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CustomPaint(size: Size.infinite, painter: _PharmaFallbackPainter()),
            Positioned.fill(
              child: Image.asset(
                'assets/images/pharma_scene.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );
}

class _PharmaFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = const LinearGradient(
              colors: [Color(0x00C4B5FD), Color(0xFFE9D5FF), Color(0x008B5CF6)])
          .createShader(Rect.fromLTWH(0, 0, w, h));
    final path = Path()
      ..moveTo(0, h * .70)
      ..quadraticBezierTo(w * .35, h * .20, w * .72, h * .66)
      ..quadraticBezierTo(w * .90, h * .84, w, h * .28);
    canvas.drawPath(path, wave);
    final floor = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          C.a(const Color(0xFF8B5CF6), .02),
          C.a(const Color(0xFF8B5CF6), .24),
          C.a(const Color(0xFF21175E), .02)
        ],
      ).createShader(Rect.fromLTWH(0, h * .68, w, h * .32));
    canvas.drawRect(Rect.fromLTWH(0, h * .68, w, h * .32), floor);

    // Decorative prescription card (clean abstract mark: NO Rx, no letters, no fake signatures)
    canvas.save();
    canvas.translate(w * .49, h * .70);
    canvas.rotate(-.16);
    final card = RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * .17, -h * .43, w * .30, h * .48),
        const Radius.circular(9));
    canvas.drawRRect(card, Paint()..color = const Color(0xFFEDE9FE));
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = C.a(Colors.white, .8),
    );

    // Neutral abstract header: geometric medical cross mark + pill header bar
    final markPaint = Paint()..color = const Color(0xFF6D28D9);
    final crossX = -w * .115;
    final crossY = -h * .32;
    final crossSize = h * .065;
    final crossBar = crossSize * .32;

    // Vertical bar of cross
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(crossX, crossY), width: crossBar, height: crossSize),
        const Radius.circular(1.5),
      ),
      markPaint,
    );
    // Horizontal bar of cross
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(crossX, crossY), width: crossSize, height: crossBar),
        const Radius.circular(1.5),
      ),
      markPaint,
    );

    // Neutral abstract accent header bar next to cross
    final headerBarPaint = Paint()..color = const Color(0xFF8B5CF6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(crossX + crossSize * .9, crossY - crossBar * .5, w * .12, crossBar),
        const Radius.circular(2),
      ),
      headerBarPaint,
    );

    // Clean neutral note lines
    final linePaint = Paint()
      ..color = const Color(0xFF9A83D9)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(-w * .12, -h * (.20 - i * .055)),
        Offset(w * .075, -h * (.20 - i * .055)),
        linePaint,
      );
    }
    canvas.restore();

    // Medicine bottle
    final bx = w * .69, by = h * .26, bw = w * .22, bh = h * .67;
    final bottleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(22));
    canvas.drawRRect(
      bottleRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xAA9D79FF), Color(0xDD3E238C), Color(0xCCB99BFF)],
        ).createShader(Rect.fromLTWH(bx, by, bw, bh)),
    );
    canvas.drawRRect(
      bottleRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = C.a(Colors.white, .65),
    );
    final cap = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + bw * .12, by - h * .12, bw * .76, h * .15),
        const Radius.circular(8));
    canvas.drawRRect(
      cap,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE9D5FF), Color(0xFF8B5CF6), Color(0xFFD8B4FE)],
        ).createShader(cap.outerRect),
    );
    final capLine = Paint()
      ..color = C.a(Colors.white, .55)
      ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final x = bx + bw * (.18 + i * .08);
      canvas.drawLine(
          Offset(x, by - h * .105), Offset(x, by + h * .005), capLine);
    }
    // Capsules inside bottle and on the reflective surface
    _capsule(
        canvas, Offset(bx + bw * .48, by + bh * .70), bw * .64, h * .12, -.65);
    _capsule(
        canvas, Offset(bx + bw * .43, by + bh * .83), bw * .64, h * .12, .55);
    _capsule(canvas, Offset(w * .38, h * .91), w * .24, h * .12, -.08);
    _capsule(canvas, Offset(w * .58, h * .93), w * .22, h * .11, .03);
  }

  void _capsule(Canvas canvas, Offset center, double width, double height,
      double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final rect =
        Rect.fromCenter(center: Offset.zero, width: width, height: height);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF5F0FF), Color(0xFFBFA4FF), Color(0xFF6D28D9)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = C.a(Colors.white, .75),
    );
    canvas.drawLine(
      Offset.zero.translate(-width * .03, -height * .43),
      Offset(-width * .03, height * .43),
      Paint()
        ..color = C.a(Colors.white, .65)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = const LinearGradient(
        colors: [Color(0x00C4B5FD), Color(0x55C4B5FD), Color(0x008B5CF6)],
      ).createShader(Offset.zero & size);
    final path = Path()
      ..moveTo(0, size.height * .12)
      ..cubicTo(size.width * .16, size.height * .02, size.width * .18,
          size.height * .25, size.width * .40, size.height * .22)
      ..cubicTo(size.width * .62, size.height * .18, size.width * .75,
          size.height * .02, size.width, size.height * .15);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
