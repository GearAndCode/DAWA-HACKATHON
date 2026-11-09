import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/dawa_brand_mark.dart';
import 'shell.dart';

/// DAWA welcome screen.
///
/// Luxury-minimal brand introduction: deep indigo/purple atmosphere, the DAWA
/// mark, a bilingual wordmark and an alternating English / Urdu tagline.
/// Runs for ~5.8 s and then fades into the app shell.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = 5800;

  late final AnimationController _c;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: _totalMs))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goHome();
      })
      ..forward();
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => const AppShell(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Eased 0..1 progress of the timeline segment [fromMs, toMs].
  double _p(int fromMs, int toMs, [Curve curve = Curves.easeOutCubic]) {
    final ms = _c.value * _totalMs;
    final t = ((ms - fromMs) / (toMs - fromMs)).clamp(0.0, 1.0).toDouble();
    return curve.transform(t);
  }

  Widget _fadeUp(double v, double rise, Widget child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, rise * (1 - v)), child: child),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Backdrop.deep,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final bg = _p(0, 900, Curves.easeInOut);
          final logo = _p(600, 1700);
          final wordEn = _p(1300, 2300);
          final wordAr = _p(1650, 2650);
          final sub = _p(2700, 3400, Curves.easeInOut);
          final exit = _p(5450, 5800, Curves.easeIn);

          // Taglines share one slot: English in -> out, then Urdu in.
          final enIn = _p(2500, 3050);
          final enOut = _p(3950, 4400, Curves.easeInOut);
          final urIn = _p(4400, 4950);

          return Stack(fit: StackFit.expand, children: [
            Opacity(opacity: bg, child: const _Backdrop()),
            SafeArea(
              child: Opacity(
                opacity: 1 - exit,
                child: LayoutBuilder(builder: (context, box) {
                  final base = math.min(box.maxWidth, box.maxHeight * .72);
                  final s = (base / 390).clamp(.78, 1.35).toDouble();
                  final ts = s.clamp(.85, 1.2).toDouble();
                  final w = math.max(200.0, math.min(box.maxWidth - 48, 520.0));

                  final enVis = enIn * (1 - enOut);
                  final enDy = 8 * ts * (1 - enIn) - 8 * ts * enOut;
                  final urDy = 8 * ts * (1 - urIn);

                  return Align(
                    alignment: const Alignment(0, -.06),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: w,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: logo,
                              child: Transform.scale(
                                scale: .9 + .1 * logo,
                                child: DawaBrandMark(size: 112 * s),
                              ),
                            ),
                            SizedBox(height: 34 * s),
                            _fadeUp(
                              wordEn,
                              10,
                              // Left padding balances the trailing letter-spacing
                              // so the word sits optically centred.
                              Padding(
                                padding: EdgeInsets.only(left: 7 * s),
                                child: Text(
                                  'DAWA',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 42 * s,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: 7 * s,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 4 * s),
                            _fadeUp(
                              wordAr,
                              8,
                              Text(
                                'دواء',
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: ar(26 * s,
                                    w: FontWeight.w500,
                                    c: C.a(const Color(0xFFDDD6FE), .92),
                                    h: 1.5),
                              ),
                            ),
                            SizedBox(height: 34 * s),
                            SizedBox(
                              width: w,
                              height: 52 * ts,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  _tagline(
                                    enVis,
                                    enDy,
                                    Text(
                                      'Connecting You to Better Healthcare.',
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.ltr,
                                      maxLines: 1,
                                      style: t(19 * ts,
                                          w: FontWeight.w500,
                                          c: Colors.white,
                                          ls: .2),
                                    ),
                                  ),
                                  _tagline(
                                    urIn,
                                    urDy,
                                    Text(
                                      'بہتر صحت، آپ کی دسترس میں۔',
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                      maxLines: 1,
                                      style: ar(22 * ts,
                                          w: FontWeight.w500,
                                          c: Colors.white,
                                          h: 1.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12 * ts),
                            Opacity(
                              opacity: sub,
                              child: SizedBox(
                                width: w,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Prescriptions • Medicines • Pharmacies • Healthcare',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: t(12.5 * ts,
                                        c: C.a(const Color(0xFFEDE9FE), .72),
                                        ls: .6),
                                  ),
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
            ),
          ]);
        },
      ),
    );
  }

  /// One tagline layer: fixed slot, scales down instead of wrapping.
  Widget _tagline(double vis, double dy, Widget text) => Opacity(
        opacity: vis.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(0, dy),
          child: FittedBox(fit: BoxFit.scaleDown, child: text),
        ),
      );
}

/// Layered purple atmosphere: dark-edged radial base, a restrained lavender
/// light behind the mark and a faint violet bloom in the upper corner.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  static const Color deep = Color(0xFF1B1950);
  static final Color _core = Color.lerp(C.purple, C.indigo, .45)!;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -.28),
            radius: 1.1,
            colors: [_core, C.indigo, deep],
            stops: const [0, .55, 1],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -.28),
            radius: .55,
            colors: [C.a(C.lavender, .16), C.a(C.lavender, 0)],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-.9, -1.0),
            radius: .9,
            colors: [C.a(C.violet, .12), C.a(C.violet, 0)],
          ),
        ),
      ),
    ]);
  }
}