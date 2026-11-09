import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/demo_data.dart' as demo;
import '../navigation/nav.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/location_permission_modal.dart';
import '../widgets/pharmacy_map_widget.dart';
import 'other_screens.dart';
import 'prescription_screen.dart';
import 'pharmacist_admin_screen.dart';
import 'order_tracking_screen.dart';

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good Morning!';
  if (h >= 12 && h < 17) return 'Good Afternoon!';
  if (h >= 17 && h < 21) return 'Good Evening!';
  return 'Good Night!';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late String _greeting = greetingFor(DateTime.now());
  Timer? _timer;
  final _search = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  List<Map<String, dynamic>> _nearbyPharmacies = [];
  List<Map<String, dynamic>> _searchedMedicines = [];
  List<Map<String, dynamic>> _recentOrders = [];
  bool _loadingPharmacies = true;
  bool _searchingMeds = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    _focus.addListener(() => setState(() {}));

    // Check location and prompt permission modal once if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationPermissionModal.showIfNeeded(context, () {
        _loadNearbyPharmacies();
      });
      _loadNearbyPharmacies();
      _loadRecentOrders();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _loadRecentOrders();
    }
  }

  void _refresh() {
    final g = greetingFor(DateTime.now());
    if (mounted && g != _greeting) setState(() => _greeting = g);
  }

  Future<void> _loadNearbyPharmacies() async {
    setState(() => _loadingPharmacies = true);
    final loc = LocationService.instance.currentLocation.value;
    final lat = loc?.latitude ?? 31.5204;
    final lon = loc?.longitude ?? 74.3587;

    try {
      final list = await ApiService.instance.getNearbyPharmacies(lat, lon);
      if (mounted) {
        setState(() {
          _nearbyPharmacies = list;
          _loadingPharmacies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPharmacies = false);
    }
  }

  Future<void> _loadRecentOrders() async {
    try {
      final orders = await ApiService.instance.getOrders();
      if (mounted) setState(() => _recentOrders = orders);
    } catch (_) {}
  }

  Future<void> _onSearchChanged(String val) async {
    setState(() => _query = val);
    if (val.trim().isEmpty) {
      setState(() => _searchedMedicines = []);
      return;
    }

    setState(() => _searchingMeds = true);
    try {
      final res = await ApiService.instance.searchMedicines(query: val.trim());
      if (mounted) {
        setState(() {
          _searchedMedicines = res;
          _searchingMeds = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searchingMeds = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(),
        const SizedBox(height: 24),
        _greetingBlock(),
        const SizedBox(height: 18),
        _locationSelector(),
        const SizedBox(height: 14),
        _searchBar(),
        if (_query.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _searchResults(),
        ],
        const SizedBox(height: 22),
        if (_recentOrders.isNotEmpty) ...[
          _activeOrderBanner(),
          const SizedBox(height: 22),
        ],
        _heroCard(),
        const SizedBox(height: 30),
        _quickAccess(),
        const SizedBox(height: 30),
        _mapAndPharmaciesSection(),
        const SizedBox(height: 30),
        _categories(),
        const SizedBox(height: 30),
        _recent(),
        const SizedBox(height: 30),
        _howItWorks(),
        const SizedBox(height: 30),
        _trustBanner(),
        const SizedBox(height: 30),
        _healthInfo(),
      ]),
    );
  }

  // ---------- Header ----------
  Widget _header() => Row(children: [
        const DawaLogo(size: 42),
        const SizedBox(width: 10),
        Text('DAWA', style: t(22, w: FontWeight.w800, c: C.indigo, ls: 2.5)),
        const SizedBox(width: 8),
        Text('دواء',
            textDirection: TextDirection.rtl,
            style: ar(20, w: FontWeight.w600, c: C.purple)),
        const Spacer(),
        // Pharmacist Demo Quick Switch Button
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: C.light,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => push(context, const PharmacistAdminScreen()),
            icon: const Icon(Icons.admin_panel_settings_rounded,
                size: 16, color: C.purple),
            label: Text('Admin',
                style: t(12, w: FontWeight.w700, c: C.purple)),
          ),
        ),
        _circleBtn(
            Icons.notifications_none_rounded,
            () => push(context, const NotificationsScreen()),
            dot: true),
        const SizedBox(width: 8),
        _circleBtn(
            Icons.person_outline_rounded,
            () => push(context, const ProfileScreen())),
      ]);

  Widget _circleBtn(IconData i, VoidCallback f, {bool dot = false}) =>
      GestureDetector(
        onTap: f,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: C.border),
            boxShadow: softShadow,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(i, color: C.text, size: 22),
              if (dot)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: C.purple, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      );

  // ---------- Greeting ----------
  Widget _greetingBlock() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(_greeting,
              key: ValueKey(_greeting),
              style: t(32, w: FontWeight.w800, c: C.indigo, h: 1.15)),
        ),
        const SizedBox(height: 6),
        Text('How can we help you feel better today?',
            style: t(17, w: FontWeight.w500)),
        const SizedBox(height: 2),
        Text('Your healthcare needs, made simpler.', style: t(14, c: C.sub)),
      ]);

  // ---------- Location ----------
  Widget _locationSelector() => ValueListenableBuilder<DawaLocation?>(
        valueListenable: LocationService.instance.currentLocation,
        builder: (context, loc, _) {
          final isGps = loc?.isActualGps ?? false;
          final title = loc?.label ?? 'Gulberg III (Tap to detect GPS)';
          final sub = loc?.address ?? 'Main Boulevard, Gulberg III, Lahore';

          return DawaCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shadow: false,
            onTap: () {
              LocationPermissionModal.showIfNeeded(context, () {
                _loadNearbyPharmacies();
              });
            },
            child: Row(children: [
              IconChip(
                isGps ? Icons.my_location_rounded : Icons.location_on_outlined,
                size: 40,
                fg: isGps ? C.green : C.purple,
                bg: isGps ? const Color(0xFFDCFCE7) : C.light,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Delivering to',
                              style: t(12, c: C.sub)),
                          if (isGps) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Live GPS',
                                  style: t(10,
                                      w: FontWeight.w700,
                                      c: const Color(0xFF15803D))),
                            ),
                          ],
                        ],
                      ),
                      Text(title, style: t(15, w: FontWeight.w700)),
                      Text(sub,
                          style: t(13, c: C.sub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: C.purple, size: 28),
            ]),
          );
        },
      );

  // ---------- Search ----------
  Widget _searchBar() => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _focus.hasFocus ? C.purple : C.border,
              width: _focus.hasFocus ? 1.6 : 1),
          boxShadow: softShadow,
        ),
        child: TextField(
          controller: _search,
          focusNode: _focus,
          onChanged: _onSearchChanged,
          style: t(15),
          decoration: InputDecoration(
            hintText: 'Search medicines, products or pharmacies...',
            hintStyle: t(14, c: C.sub),
            prefixIcon: const Icon(Icons.search_rounded, color: C.purple),
            suffixIcon: _searchingMeds
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: C.purple),
                    ),
                  )
                : (_query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: C.sub),
                        onPressed: () {
                          _search.clear();
                          _onSearchChanged('');
                        },
                      )),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );

  Widget _searchResults() {
    if (_searchedMedicines.isEmpty && !_searchingMeds) {
      return DawaCard(
        shadow: false,
        child: Row(children: [
          const IconChip(Icons.search_off_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No medicines found for "$_query". Try another brand or upload your prescription.',
              style: t(14, c: C.sub),
            ),
          ),
        ]),
      );
    }
    return Column(children: [
      for (final m in _searchedMedicines)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DawaCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const IconChip(Icons.medication_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m['brand_name']} (${m['strength']})',
                          style: t(15, w: FontWeight.w700)),
                      Text(
                        '${m['generic_name'] ?? ''} • ${m['category'] ?? 'Medicine'} • PKR ${m['default_price']}',
                        style: t(12.5, c: C.sub),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => push(context, const PrescriptionScreen()),
                  child: const Text('Prescribe', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  // ---------- Active Order Banner ----------
  Widget _activeOrderBanner() {
    final active = _recentOrders.first;
    final orderNum = active['order_number'] ?? 'DAWA-2026-0001';
    final status = active['status'] ?? 'Order Placed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.light,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.a(C.purple, 0.3)),
      ),
      child: Row(
        children: [
          const IconChip(Icons.local_shipping_outlined, bg: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Order: $orderNum',
                    style: t(14.5, w: FontWeight.w700, c: C.indigo)),
                Text('Status: $status',
                    style: t(13, w: FontWeight.w600, c: C.purple)),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () => push(context, OrderTrackingScreen(order: active)),
            child: const Text('Track', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ---------- Hero ----------
  Widget _heroCard() {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 640;
      final illus = _prescriptionIllustration(wide ? 170 : 96);
      final text =
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child:
              Text('Prescription', style: t(12, w: FontWeight.w700, c: C.purple)),
        ),
        const SizedBox(height: 12),
        Text('Your Prescription, Simplified.',
            style: t(wide ? 28 : 23, w: FontWeight.w800, c: C.indigo, h: 1.2)),
        const SizedBox(height: 10),
        Text(
            'Upload your prescription and let DAWA help you find pharmacies that can provide your required medicines.',
            style: t(14, c: C.text.withAlpha(200), h: 1.5)),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => push(context, const PrescriptionScreen()),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Upload Prescription'),
        ),
        const SizedBox(height: 10),
        Text('Take a photo or choose a file from your device.',
            style: t(12.5, c: C.sub)),
      ]);
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: C.light,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: C.a(C.lavender, .4)),
          boxShadow: [
            BoxShadow(
                color: C.a(C.purple, .14),
                blurRadius: 30,
                offset: const Offset(0, 12))
          ],
        ),
        child: wide
            ? Row(children: [
                Expanded(child: text),
                const SizedBox(width: 24),
                illus
              ])
            : Stack(children: [
                Padding(padding: const EdgeInsets.only(top: 0), child: text),
                Positioned(right: 0, top: 0, child: illus),
              ]),
      );
    });
  }

  // Refined illustration: NO "Rx" text! Clean cross medical seal!
  Widget _prescriptionIllustration(double s) => SizedBox(
        width: s,
        height: s,
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: .08,
                child: Container(
                  width: s * .66,
                  height: s * .82,
                  padding: EdgeInsets.all(s * .09),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(s * .1),
                    boxShadow: softShadow,
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: s * .18,
                          height: s * .18,
                          decoration: BoxDecoration(
                            color: C.light,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.local_hospital_rounded,
                              size: s * .12, color: C.purple),
                        ),
                        SizedBox(height: s * .06),
                        for (final f in const [1.0, .8, .9, .55])
                          Container(
                            margin: EdgeInsets.only(bottom: s * .045),
                            height: math.max(3, s * .035),
                            width: s * .48 * f,
                            decoration: BoxDecoration(
                                color: C.light,
                                borderRadius: BorderRadius.circular(4)),
                          ),
                      ]),
                ),
              ),
              Positioned(
                  right: -s * .02,
                  bottom: s * .04,
                  child: CapsuleShape(length: s * .5, thickness: s * .2)),
              Positioned(
                  left: 0,
                  top: s * .02,
                  child: Container(
                    padding: EdgeInsets.all(s * .04),
                    decoration: const BoxDecoration(
                        color: C.violet, shape: BoxShape.circle),
                    child: Icon(Icons.add_rounded,
                        color: Colors.white, size: s * .16),
                  )),
            ]),
      );

  // ---------- Quick access ----------
  Widget _quickAccess() {
    Widget q(IconData i, String l, VoidCallback f) => Expanded(
          child: DawaCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            shadow: false,
            onTap: f,
            child: Column(children: [
              Icon(i, color: C.purple, size: 26),
              const SizedBox(height: 8),
              Text(l,
                  textAlign: TextAlign.center,
                  style: t(12.5, w: FontWeight.w600)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Access', style: t(18, w: FontWeight.w700)),
      const SizedBox(height: 12),
      Row(children: [
        q(Icons.description_outlined, 'My\nPrescriptions',
            () => push(context, const MyPrescriptionsScreen())),
        const SizedBox(width: 12),
        q(Icons.receipt_long_outlined, 'My\nOrders',
            () => demo.tabIndex.value = 2),
        const SizedBox(width: 12),
        q(Icons.admin_panel_settings_rounded, 'Pharmacist\nAdmin',
            () => push(context, const PharmacistAdminScreen())),
      ]),
    ]);
  }

  // ---------- Interactive Map & Pharmacies ----------
  Widget _mapAndPharmaciesSection() {
    final loc = LocationService.instance.currentLocation.value;
    final lat = loc?.latitude ?? 31.5204;
    final lon = loc?.longitude ?? 74.3587;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Nearby Pharmacies & Geographic Radar',
          'Live distance calculation based on your coordinates.',
        ),
        const SizedBox(height: 12),
        PharmacyMapWidget(
          patientLat: lat,
          patientLon: lon,
          pharmacies: _nearbyPharmacies,
        ),
        const SizedBox(height: 16),
        if (_loadingPharmacies)
          const Center(child: CircularProgressIndicator())
        else if (_nearbyPharmacies.isNotEmpty)
          ResponsiveGrid(
            minTileWidth: 280,
            children: [
              for (final p in _nearbyPharmacies)
                _buildLivePharmacyCard(p),
            ],
          ),
      ],
    );
  }

  Widget _buildLivePharmacyCard(Map<String, dynamic> p) {
    final name = p['name'] ?? 'Pharmacy';
    final area = p['area'] ?? 'Lahore';
    final address = p['address'] ?? '';
    final dist = p['distance_km']?.toString() ?? '1.5';
    final rating = p['rating']?.toString() ?? '4.8';

    return DawaCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(Icons.local_pharmacy_outlined, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: t(15.5, w: FontWeight.w700)),
                    Text('$area • $dist km away',
                        style: t(12.5, c: C.purple, w: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 13, color: Color(0xFFD97706)),
                    const SizedBox(width: 2),
                    Text(rating,
                        style: t(11.5,
                            w: FontWeight.w700,
                            c: const Color(0xFFB45309))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(address, style: t(12.5, c: C.sub)),
        ],
      ),
    );
  }

  // ---------- Categories ----------
  Widget _categories() {
    Widget cat(IconData i, String title, Color bg, Widget page) => DawaCard(
          onTap: () => push(context, page),
          color: bg,
          shadow: false,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 96,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(i, color: C.purple, size: 24),
                  ),
                  Row(children: [
                    Expanded(
                        child: Text(title,
                            style: t(15, w: FontWeight.w700, c: C.indigo))),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: C.purple),
                  ]),
                ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(
          'Explore Healthcare', 'Everything you need, in one place.'),
      ResponsiveGrid(minTileWidth: 150, children: [
        cat(Icons.medication_outlined, 'Medicines', const Color(0xFFF1EDFF),
            const MedicinesScreen()),
        cat(Icons.spa_outlined, 'Healthcare Products', const Color(0xFFEDEBFF),
            const ProductsScreen()),
        cat(Icons.local_pharmacy_outlined, 'Nearby Pharmacies',
            const Color(0xFFF4EFFF), const PharmaciesScreen()),
        cat(Icons.description_outlined, 'My Prescriptions',
            const Color(0xFFEFEEFB), const MyPrescriptionsScreen()),
      ]),
    ]);
  }

  // ---------- Recently viewed ----------
  Widget _recent() => ValueListenableBuilder<List<demo.Medicine>>(
        valueListenable: demo.recentlyViewed,
        builder: (context, list, _) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recently Viewed', style: t(18, w: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => ActionChip(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: C.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                        avatar: const Icon(Icons.history_rounded,
                            size: 18, color: C.purple),
                        label: Text(list[i].name,
                            style: t(13.5, w: FontWeight.w600)),
                        onPressed: () => showMedicineSheet(context, list[i]),
                      ),
                    ),
                  ),
                ]),
          );
        },
      );

  // ---------- How it works ----------
  Widget _howItWorks() {
    const steps = [
      (
        Icons.description_outlined,
        'Upload Prescription',
        'Photograph or upload your prescription through the DAWA AI scanner.'
      ),
      (
        Icons.local_pharmacy_outlined,
        'Find a Pharmacy',
        'DAWA checks inventory and matches nearest pharmacies with your medicine in stock.'
      ),
      (
        Icons.inventory_2_outlined,
        'Get Your Medicines',
        'Approve itemized quotation and choose convenient pickup or express home delivery.'
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(
          'How DAWA Works', 'Healthcare, made easier in three simple steps.'),
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 700;
        Widget step(int i) =>
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [C.purple, C.violet]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(steps[i].$1, color: Colors.white, size: 26),
                ),
                if (!wide && i < 2)
                  Container(
                      width: 2, height: 40, color: C.a(C.lavender, .5)),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Step ${i + 1}',
                            style:
                                t(12, w: FontWeight.w700, c: C.violet)),
                        Text(steps[i].$2, style: t(16, w: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(steps[i].$3, style: t(13.5, c: C.sub)),
                      ]),
                ),
              ),
            ]);
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (int i = 0; i < 3; i++) ...[
              Expanded(child: step(i)),
              if (i < 2)
                const Padding(
                  padding: EdgeInsets.only(top: 25, left: 6, right: 6),
                  child: Icon(Icons.more_horiz_rounded,
                      color: C.lavender, size: 28),
                ),
            ],
          ]);
        }
        return Column(children: [for (int i = 0; i < 3; i++) step(i)]);
      }),
    ]);
  }

  // ---------- Trust ----------
  Widget _trustBanner() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: C.light,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: C.a(C.lavender, .4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.verified_user_outlined,
                color: C.purple, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Health Deserves Care.',
                      style: t(18, w: FontWeight.w800, c: C.indigo)),
                  const SizedBox(height: 6),
                  Text(
                      'Prescription orders should be reviewed by a qualified pharmacist before approval.',
                      style: t(14, c: C.text.withAlpha(200), h: 1.5)),
                ]),
          ),
        ]),
      );

  // ---------- Health info ----------
  Widget _healthInfo() {
    const tips = [
      (
        Icons.water_drop_outlined,
        'Stay hydrated',
        'Drinking enough water supports everyday wellbeing.'
      ),
      (
        Icons.menu_book_outlined,
        'Read the label',
        'Check instructions and expiry dates on all medicines.'
      ),
      (
        Icons.medical_information_outlined,
        'Ask a professional',
        'Talk to your doctor or pharmacist with any medicine questions.'
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(
          'Healthcare Information', 'General reminders. Not medical advice.'),
      ResponsiveGrid(minTileWidth: 240, children: [
        for (final tp in tips)
          DawaCard(
            shadow: false,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconChip(tp.$1, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tp.$2, style: t(14.5, w: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(tp.$3, style: t(13, c: C.sub)),
                    ]),
              ),
            ]),
          ),
      ]),
    ]);
  }
}
