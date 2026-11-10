import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../navigation/nav.dart';
import '../screens/other_screens.dart';
import '../data/demo_data.dart' as demo;

class PharmacyMapWidget extends StatefulWidget {
  final double patientLat;
  final double patientLon;
  final List<Map<String, dynamic>> pharmacies;
  final Function(Map<String, dynamic>)? onSelectPharmacy;

  const PharmacyMapWidget({
    super.key,
    required this.patientLat,
    required this.patientLon,
    required this.pharmacies,
    this.onSelectPharmacy,
  });

  @override
  State<PharmacyMapWidget> createState() => _PharmacyMapWidgetState();
}

class _PharmacyMapWidgetState extends State<PharmacyMapWidget>
    with SingleTickerProviderStateMixin {
  int? _selectedPharmacyIndex;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 310,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B), // Deep Indigo night map style
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.border),
        boxShadow: softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. Grid & Compass Vector Radar
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _MapCanvasPainter(
                        pulse: _pulseController.value,
                        patientLat: widget.patientLat,
                        patientLon: widget.patientLon,
                        pharmacies: widget.pharmacies,
                        selectedIndex: _selectedPharmacyIndex,
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. Interactive Pharmacy Markers
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      // Patient Marker (Center)
                      Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: C.purple,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.my_location_rounded,
                                    color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text('You',
                                    style: t(11,
                                        w: FontWeight.w700,
                                        c: Colors.white)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: C.violet, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.white38,
                                    blurRadius: 8,
                                    spreadRadius: 2)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pharmacy Markers around center
                    for (int i = 0; i < widget.pharmacies.length; i++)
                      _buildPharmacyPin(
                          i, widget.pharmacies[i], w, h),
                  ],
                );
              },
            ),
          ),

          // 3. Top Banner
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.explore_outlined,
                            size: 14, color: C.lavender),
                        const SizedBox(width: 6),
                        Text(
                          'DAWA Geographic Radar (Lahore Demo)',
                          style: t(11.5,
                              w: FontWeight.w600, c: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.green.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.pharmacies.length} nearby',
                      style: t(11, w: FontWeight.w700, c: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Bottom Selected Pharmacy Quick Preview Card
            if (_selectedPharmacyIndex != null &&
                _selectedPharmacyIndex! < widget.pharmacies.length)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: _buildSelectedCard(
                    widget.pharmacies[_selectedPharmacyIndex!]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPharmacyPin(
      int index, Map<String, dynamic> p, double w, double h) {
    // Relative coordinates offset from center based on index
    // Angles distributed around the compass
    final angles = [0.8, 2.3, 3.7, 5.1];
    final radii = [70.0, 95.0, 85.0, 105.0];

    final angle = angles[index % angles.length];
    final radius = radii[index % radii.length];

    final cx = w / 2;
    final cy = h / 2 - 10;

    final px = cx + radius * math.cos(angle);
    final py = cy + radius * math.sin(angle);

    final isSelected = _selectedPharmacyIndex == index;
    final dist = p['distance_km']?.toString() ?? '1.5';

    return Positioned(
      left: px - 40,
      top: py - 20,
      child: SizedBox(
        width: 80,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedPharmacyIndex = index);
            widget.onSelectPharmacy?.call(p);
          },
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFF312E81),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? C.purple : C.lavender,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black45,
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_pharmacy_rounded,
                    size: 13,
                    color: isSelected ? C.purple : C.lavender,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$dist km',
                    style: t(11,
                        w: FontWeight.w700,
                        c: isSelected ? C.text : Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Icon(
              Icons.location_on_rounded,
              size: isSelected ? 26 : 22,
              color: isSelected ? C.violet : Colors.white70,
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSelectedCard(Map<String, dynamic> p) {
    final name = p['name'] ?? 'Pharmacy';
    final area = p['area'] ?? 'Lahore';
    final dist = p['distance_km']?.toString() ?? '0.0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.light,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_pharmacy_rounded,
                color: C.purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: t(14, w: FontWeight.w700, c: C.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$area • $dist km away',
                    style: t(12, c: C.sub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () {
              push(
                context,
                PharmacyDetailScreen(
                  demo.Pharmacy(
                    name,
                    area,
                    p['description'] ?? 'Demo pharmacy in Lahore.',
                    p['opening_hours'] ?? '9:00 AM – 11:00 PM',
                    Icons.local_pharmacy_outlined,
                  ),
                ),
              );
            },
            child: const Text('View', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  final double pulse;
  final double patientLat;
  final double patientLon;
  final List<Map<String, dynamic>> pharmacies;
  final int? selectedIndex;

  _MapCanvasPainter({
    required this.pulse,
    required this.patientLat,
    required this.patientLon,
    required this.pharmacies,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 10;
    final center = Offset(cx, cy);

    // Subtle concentric radar range rings
    final ringPaint = Paint()
      ..color = const Color(0xFF4338CA).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final r in [45.0, 85.0, 125.0]) {
      canvas.drawCircle(center, r, ringPaint);
    }

    // Glowing pulsing range wave
    final pulseRadius = 30.0 + (pulse * 90.0);
    final pulsePaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: (1.0 - pulse) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Crosshairs
    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), crosshairPaint);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), crosshairPaint);
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.patientLat != patientLat ||
      oldDelegate.patientLon != patientLon;
}


