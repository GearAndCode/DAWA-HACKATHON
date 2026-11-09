import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class LocationPermissionModal extends StatefulWidget {
  final VoidCallback onResolved;
  const LocationPermissionModal({super.key, required this.onResolved});

  static Future<void> showIfNeeded(BuildContext context, VoidCallback onResolved) async {
    if (LocationService.instance.currentLocation.value == null &&
        !LocationService.instance.permissionRequested.value) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => LocationPermissionModal(onResolved: onResolved),
      );
    }
  }

  @override
  State<LocationPermissionModal> createState() => _LocationPermissionModalState();
}

class _LocationPermissionModalState extends State<LocationPermissionModal> {
  bool _loading = false;
  String? _statusMessage;
  bool _showManualSelection = false;

  Future<void> _request() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    final res = await LocationService.instance.requestRealLocation();

    if (!mounted) return;
    setState(() => _loading = false);

    switch (res) {
      case LocationPermissionResult.granted:
        Navigator.pop(context);
        widget.onResolved();
        break;
      case LocationPermissionResult.denied:
        setState(() {
          _statusMessage =
              'Location permission was denied. You can select your area manually below.';
          _showManualSelection = true;
        });
        break;
      case LocationPermissionResult.permanentlyDenied:
        setState(() {
          _statusMessage =
              'Location permission is permanently denied in browser/system settings. Please select your area manually.';
          _showManualSelection = true;
        });
        break;
      case LocationPermissionResult.serviceDisabled:
        setState(() {
          _statusMessage =
              'Device location services are turned off. Please enable GPS or select your area manually.';
          _showManualSelection = true;
        });
        break;
      case LocationPermissionResult.unavailable:
        setState(() {
          _statusMessage =
              'Unable to fetch GPS position. Please pick a demo location in Lahore.';
          _showManualSelection = true;
        });
        break;
    }
  }

  void _chooseManual(DawaLocation loc) {
    LocationService.instance.setManualLocation(loc);
    Navigator.pop(context);
    widget.onResolved();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: softShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: C.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: C.light,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.border),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: C.purple, size: 34),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Find Pharmacies Near You',
              textAlign: TextAlign.center,
              style: t(22, w: FontWeight.w800, c: C.indigo),
            ),
            const SizedBox(height: 8),
            Text(
              'Allow DAWA to access your location so we can show nearby pharmacies and help you find medicines more conveniently.',
              textAlign: TextAlign.center,
              style: t(14, c: C.sub, h: 1.5),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: t(13, c: const Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!_showManualSelection) ...[
              FilledButton(
                onPressed: _loading ? null : _request,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Allow Location Access'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  setState(() => _showManualSelection = true);
                },
                child: const Text('Not Now (Choose Manually)'),
              ),
            ] else ...[
              Text(
                'Select Your Area in Lahore (Demo)',
                style: t(15, w: FontWeight.w700, c: C.indigo),
              ),
              const SizedBox(height: 10),
              for (final loc in LocationService.manualLocations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DawaCard(
                    shadow: false,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    onTap: () => _chooseManual(loc),
                    child: Row(
                      children: [
                        const Icon(Icons.location_city_rounded,
                            color: C.purple, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc.label,
                                  style: t(14.5, w: FontWeight.w600)),
                              Text(loc.address,
                                  style: t(12, c: C.sub)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: C.sub),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
