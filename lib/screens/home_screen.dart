import 'dart:async';
import 'package:flutter/material.dart';
import '../data/demo_data.dart' as demo;
import '../navigation/nav.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/pharmacy_map_widget.dart';
import 'other_screens.dart';
import 'prescription_screen.dart';
import 'pharmacist_admin_screen.dart';
import 'order_tracking_screen.dart';

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good Morning';
  if (h >= 12 && h < 17) return 'Good Afternoon';
  if (h >= 17 && h < 21) return 'Good Evening';
  return 'Good Night';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late String _greeting = greetingFor(DateTime.now());
  Timer? _timer;
  Timer? _searchDebounce;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentOrders();
      _loadNearbyPharmacies();
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

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _searchedMedicines = [];
        _searchingMeds = false;
      });
      return;
    }

    setState(() {
      _query = trimmed;
      _searchingMeds = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 320), () async {
      try {
        final results = await ApiService.instance.searchMedicines(query: trimmed);
        if (mounted && _query == trimmed) {
          setState(() {
            _searchedMedicines = results;
            _searchingMeds = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searchingMeds = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _searchDebounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      children: [
        // 1. Top Header with Logo, Greeting, Notification & Profile
        _buildHeader(),
        const SizedBox(height: 18),

        // 2. Search Field with Real Catalog Querying
        _buildSearchBar(),
        const SizedBox(height: 20),

        if (_query.isNotEmpty) ...[
          _buildSearchResults(),
          const SizedBox(height: 24),
        ],

        // 3. Active Order Live Tracking Banner (if any active order in DB)
        if (_recentOrders.isNotEmpty &&
            _recentOrders.first['order_status'] != 'Delivered' &&
            _recentOrders.first['order_status'] != 'Collected') ...[
          _buildActiveOrderBanner(_recentOrders.first),
          const SizedBox(height: 20),
        ],

        // 4. Hero Section: Illuminated Card with Animated Ambient Glow
        _buildHeroBanner(),
        const SizedBox(height: 24),

        // 5. Quick Actions Grid (Refined, no cartoon icons)
        _buildQuickActions(),
        const SizedBox(height: 26),

        // 6. Live Location & Interactive Radar Map Widget
        _buildLocationAndRadar(),
        const SizedBox(height: 28),

        // 7. Nearby Pharmacies Cards
        _buildNearbyPharmaciesSection(),
        const SizedBox(height: 28),

        // 8. Healthcare Features & Verification Safety Callout
        _buildTrustSection(),
      ],
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year}';

    return FadeSlideEntrance(
      slideOffset: 10,
      child: Row(
        children: [
          const DawaLogo(size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting, Ali',
                  style: t(19.5, w: FontWeight.w800, c: C.indigo, ls: -0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your healthcare, simplified • $dateStr',
                  style: t(12.5, c: C.sub),
                ),
              ],
            ),
          ),
          // Pharmacist Portal Shortcut
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE9E6F0)),
              boxShadow: DawaShadows.subtle,
            ),
            child: IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined,
                  color: C.purple, size: 21),
              tooltip: 'Pharmacist Portal',
              onPressed: () => push(context, const PharmacistAdminScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return FadeSlideEntrance(
      delay: const Duration(milliseconds: 100),
      slideOffset: 12,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _focus.hasFocus ? C.purple : const Color(0xFFE9E6F0),
            width: _focus.hasFocus ? 1.5 : 1.0,
          ),
          boxShadow: _focus.hasFocus ? DawaShadows.purpleGlow : DawaShadows.card,
        ),
        child: TextField(
          controller: _search,
          focusNode: _focus,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search medicines (e.g. Panadol, Augmentin)...',
            hintStyle: t(14, c: const Color(0xFF9CA3AF)),
            prefixIcon: const Icon(Icons.search_rounded, color: C.purple, size: 22),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: C.sub),
                    onPressed: () {
                      _search.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchingMeds) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
        ),
      );
    }

    if (_searchedMedicines.isEmpty) {
      return DawaSurface(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No catalog medicines match "$_query".',
            style: t(14, c: C.sub),
          ),
        ),
      );
    }

    return DawaSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              'Found ${_searchedMedicines.length} medicines in Lahore inventory:',
              style: t(13, w: FontWeight.w700, c: C.indigo),
            ),
          ),
          const Divider(height: 12),
          for (final med in _searchedMedicines.take(4))
            ListTile(
              dense: true,
              leading: const IconChip(Icons.medication_outlined, size: 36, iconSize: 18),
              title: Text(
                '${med['name']} (${med['strength']})',
                style: t(14, w: FontWeight.w700),
              ),
              subtitle: Text(
                '${med['generic_name']} • PKR ${med['standard_price_pkr']}',
                style: t(12, c: C.sub),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: C.sub, size: 18),
              onTap: () {
                push(context, const PrescriptionScreen());
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderBanner(Map<String, dynamic> order) {
    final ref = order['order_reference'] ?? 'DAWA-ORDER';
    final status = order['order_status'] ?? 'Order Placed';
    final total = order['grand_total'] ?? 0;
    final orderId = order['id'] as int;

    return FadeSlideEntrance(
      delay: const Duration(milliseconds: 150),
      child: DawaSurface(
        color: const Color(0xFFF5F3FF),
        border: Border.all(color: const Color(0xFFDDD6FE)),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: C.purple,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: C.purple.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Order: $ref', style: t(14, w: FontWeight.w700, c: C.indigo)),
                  const SizedBox(height: 2),
                  Text('$status • PKR $total', style: t(12.5, c: C.purple, w: FontWeight.w600)),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => push(context, OrderTrackingScreen(orderId: orderId)),
              child: const Text('Track', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return FadeSlideEntrance(
      delay: const Duration(milliseconds: 200),
      slideOffset: 16,
      child: IlluminatedCard(
        onTap: () => push(context, const PrescriptionScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFFDDD6FE), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'AI Medicine Intelligence',
                        style: t(12, w: FontWeight.w600, c: Colors.white),
                      ),
                    ],
                  ),
                ),
                Text(
                  'دواء',
                  style: ar(22, w: FontWeight.w700, c: const Color(0xFFDDD6FE)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Your Health, One Step Closer.',
              style: t(22, w: FontWeight.w800, c: Colors.white, h: 1.25, ls: -0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your prescription securely to identify required medicines and discover real-time inventory at nearby Lahore pharmacies.',
              style: t(13.5, c: Colors.white.withValues(alpha: 0.88), h: 1.45),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.document_scanner_rounded, color: C.purple, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Scan Prescription',
                        style: t(14, w: FontWeight.w700, c: C.purple),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Quick 5-sec scan',
                  style: t(12.5, c: Colors.white70, w: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (
        'Upload Rx',
        'Identify medicines',
        Icons.document_scanner_outlined,
        () => push(context, const PrescriptionScreen()),
      ),
      (
        'Catalog',
        'Search medicines',
        Icons.medication_liquid_outlined,
        () => push(context, const AllMedicinesScreen()),
      ),
      (
        'Pharmacies',
        '4 demo stores',
        Icons.local_pharmacy_outlined,
        () => push(context, const ExploreScreen()),
      ),
      (
        'My Orders',
        'Track deliveries',
        Icons.receipt_long_outlined,
        () => push(context, const OrdersScreen()),
      ),
    ];

    return FadeSlideEntrance(
      delay: const Duration(milliseconds: 250),
      slideOffset: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Quick Actions', subtitle: 'Essential healthcare services'),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildActionTile(actions[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildActionTile(actions[1])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildActionTile(actions[2])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildActionTile(actions[3])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile((String, String, IconData, VoidCallback) a) {
    return DawaSurface(
      padding: const EdgeInsets.all(14),
      onTap: a.$4,
      child: Row(
        children: [
          IconChip(a.$3, size: 42, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(a.$1, style: t(14, w: FontWeight.w700, c: C.text)),
                const SizedBox(height: 2),
                Text(a.$2, style: t(11.5, c: C.sub), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndRadar() {
    return FadeSlideEntrance(
      delay: const Duration(milliseconds: 300),
      slideOffset: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(
                'Nearby Pharmacies Radar',
                subtitle: 'Real-time distance projection in Lahore',
              ),
              IconButton(
                icon: const Icon(Icons.my_location_rounded, color: C.purple, size: 20),
                tooltip: 'Refresh GPS',
                onPressed: _loadNearbyPharmacies,
              ),
            ],
          ),
          PharmacyMapWidget(
            patientLat: 31.5204,
            patientLon: 74.3587,
            pharmacies: _nearbyPharmacies,
            onSelectPharmacy: (p) {
              push(
                context,
                PharmacyDetailScreen(
                  demo.Pharmacy(
                    p['name'] ?? 'Pharmacy',
                    p['area'] ?? 'Lahore',
                    p['description'] ?? 'Demo pharmacy in Lahore.',
                    p['opening_hours'] ?? '9:00 AM – 11:00 PM',
                    Icons.local_pharmacy_outlined,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPharmaciesSection() {
    if (_loadingPharmacies) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
        ),
      );
    }

    return FadeSlideEntrance(
      delay: const Duration(milliseconds: 350),
      slideOffset: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(
                'Available Pharmacies',
                subtitle: 'Compare availability and proximity',
              ),
              TextButton(
                onPressed: () => push(context, const ExploreScreen()),
                child: Text('View All', style: t(13, w: FontWeight.w700, c: C.purple)),
              ),
            ],
          ),
          for (final p in _nearbyPharmacies.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DawaSurface(
                padding: const EdgeInsets.all(16),
                onTap: () {
                  push(
                    context,
                    PharmacyDetailScreen(
                      demo.Pharmacy(
                        p['name'] ?? 'Pharmacy',
                        p['area'] ?? 'Lahore',
                        p['description'] ?? 'Demo pharmacy in Lahore.',
                        p['opening_hours'] ?? '9:00 AM – 11:00 PM',
                        Icons.local_pharmacy_outlined,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: C.light,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded, color: C.purple, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['name'] ?? 'Pharmacy', style: t(15.5, w: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                            '${p['address']} • ${p['distance_km']} km away',
                            style: t(12.5, c: C.sub),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const DawaBadge(
                          label: 'Open',
                          bg: Color(0xFFDCFCE7),
                          text: Color(0xFF15803D),
                          icon: Icons.check_circle_rounded,
                        ),
                        const SizedBox(height: 6),
                        Text('Pickup & Delivery', style: t(11, c: C.sub)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrustSection() {
    return FadeSlideEntrance(
      delay: const Duration(milliseconds: 400),
      slideOffset: 16,
      child: DawaSurface(
        color: const Color(0xFFF1EDFF),
        border: Border.all(color: const Color(0xFFDDD6FE)),
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.health_and_safety_outlined, color: C.purple, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Licensed Pharmacist Verification',
                      style: t(14.5, w: FontWeight.w700, c: C.indigo)),
                  const SizedBox(height: 4),
                  Text(
                    'DAWA provides intelligent assistance for reading prescriptions and checking inventory. Every medicine order is verified by a qualified pharmacist before dispensing.',
                    style: t(12.5, c: C.indigo.withValues(alpha: 0.8), h: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
