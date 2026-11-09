import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'other_screens.dart';
import 'prescription_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    final g = greetingFor(DateTime.now());
    if (mounted && g != _greeting) setState(() => _greeting = g);
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
        if (_query.trim().isNotEmpty) ...[const SizedBox(height: 12), _searchResults()],
        const SizedBox(height: 22),
        _heroCard(),
        const SizedBox(height: 30),
        _quickAccess(),
        const SizedBox(height: 30),
        _categories(),
        const SizedBox(height: 30),
        _recent(),
        _pharmacySection(),
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
        Text('دواء', textDirection: TextDirection.rtl, style: ar(20, w: FontWeight.w600, c: C.purple)),
        const Spacer(),
        _circleBtn(Icons.notifications_none_rounded, () => push(context, const NotificationsScreen()), dot: true),
        const SizedBox(width: 10),
        _circleBtn(Icons.person_outline_rounded, () => push(context, const ProfileScreen())),
      ]);

  Widget _circleBtn(IconData i, VoidCallback onTap, {bool dot = false}) => Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: C.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              Icon(i, color: C.indigo, size: 24),
              if (dot)
                Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: C.violet, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
            ]),
          ),
        ),
      );

  // ---------- Greeting ----------
  Widget _greetingBlock() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(_greeting, key: ValueKey(_greeting), style: t(32, w: FontWeight.w800, c: C.indigo, h: 1.15)),
        ),
        const SizedBox(height: 6),
        Text('How can we help you feel better today?', style: t(17, w: FontWeight.w500)),
        const SizedBox(height: 2),
        Text('Your healthcare needs, made simpler.', style: t(14, c: C.sub)),
      ]);

  // ---------- Location ----------
  Widget _locationSelector() => ValueListenableBuilder<DemoLocation>(
        valueListenable: selectedLocation,
        builder: (context, loc, _) => DawaCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shadow: false,
          onTap: _pickLocation,
          child: Row(children: [
            const IconChip(Icons.location_on_outlined, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Delivering to', style: t(12, c: C.sub)),
                Text(loc.label, style: t(15, w: FontWeight.w700)),
                Text(loc.address, style: t(13, c: C.sub)),
              ]),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: C.purple, size: 28),
          ]),
        ),
      );

  void _pickLocation() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Select delivery location', style: t(19, w: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text('Demo locations. DAWA does not use your GPS in this version.', style: t(13, c: C.sub)),
            ),
            for (final l in locations)
              ListTile(
                leading: const IconChip(Icons.location_on_outlined, size: 40),
                title: Text(l.label, style: t(15, w: FontWeight.w600)),
                subtitle: Text(l.address, style: t(13, c: C.sub)),
                trailing: selectedLocation.value == l
                    ? const Icon(Icons.check_circle_rounded, color: C.purple)
                    : null,
                onTap: () {
                  selectedLocation.value = l;
                  Navigator.pop(ctx);
                },
              ),
          ]),
        ),
      ),
    );
  }

  // ---------- Search ----------
  Widget _searchBar() => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _focus.hasFocus ? C.purple : C.border, width: _focus.hasFocus ? 1.6 : 1),
          boxShadow: softShadow,
        ),
        child: TextField(
          controller: _search,
          focusNode: _focus,
          onChanged: (v) => setState(() => _query = v),
          style: t(15),
          decoration: InputDecoration(
            hintText: 'Search medicines, products or pharmacies...',
            hintStyle: t(14, c: C.sub),
            prefixIcon: const Icon(Icons.search_rounded, color: C.purple),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: C.sub),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    }),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );

  Widget _searchResults() {
    final q = _query.trim().toLowerCase();
    final meds = medicines.where((m) => m.name.toLowerCase().contains(q) || m.category.toLowerCase().contains(q)).toList();
    final prods = products.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();
    final phs = pharmacies.where((p) => p.name.toLowerCase().contains(q)).toList();
    if (meds.isEmpty && prods.isEmpty && phs.isEmpty) {
      return DawaCard(
        shadow: false,
        child: Row(children: [
          const IconChip(Icons.search_off_rounded),
          const SizedBox(width: 12),
          Expanded(child: Text('No results for "${_query.trim()}". Try another name, or upload your prescription.', style: t(14, c: C.sub))),
        ]),
      );
    }
    return Column(children: [
      for (final m in meds) Padding(padding: const EdgeInsets.only(bottom: 10), child: MedicineTile(m)),
      for (final p in prods)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DawaCard(
            padding: const EdgeInsets.all(14),
            shadow: false,
            child: Row(children: [
              IconChip(p.icon),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: t(15, w: FontWeight.w600)),
                Text('${p.category} • Demo catalogue', style: t(12.5, c: C.sub)),
              ])),
            ]),
          ),
        ),
      for (final p in phs)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: PharmacyCard(p, onTap: () => push(context, PharmacyDetailScreen(p)))),
    ]);
  }

  // ---------- Hero ----------
  Widget _heroCard() {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 640;
      final illus = _prescriptionIllustration(wide ? 170 : 96);
      final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Text('Prescription', style: t(12, w: FontWeight.w700, c: C.purple)),
        ),
        const SizedBox(height: 12),
        Text('Your Prescription, Simplified.', style: t(wide ? 28 : 23, w: FontWeight.w800, c: C.indigo, h: 1.2)),
        const SizedBox(height: 10),
        Text('Upload your prescription and let DAWA help you find pharmacies that can provide your required medicines.',
            style: t(14, c: C.text.withAlpha(200), h: 1.5)),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => push(context, const PrescriptionScreen()),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Upload Prescription'),
        ),
        const SizedBox(height: 10),
        Text('Take a photo or choose a file from your device.', style: t(12.5, c: C.sub)),
      ]);
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: C.light,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: C.a(C.lavender, .4)),
          boxShadow: [BoxShadow(color: C.a(C.purple, .14), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: wide
            ? Row(children: [Expanded(child: text), const SizedBox(width: 24), illus])
            : Stack(children: [
                Padding(padding: const EdgeInsets.only(top: 0), child: text),
                Positioned(right: 0, top: 0, child: illus),
              ]),
      );
    });
  }

  Widget _prescriptionIllustration(double s) => SizedBox(
        width: s,
        height: s,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rx', style: t(s * .2, w: FontWeight.w800, c: C.purple, h: 1)),
                SizedBox(height: s * .06),
                for (final f in const [1.0, .8, .9, .55])
                  Container(
                    margin: EdgeInsets.only(bottom: s * .045),
                    height: math.max(3, s * .035),
                    width: s * .48 * f,
                    decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
            ),
          ),
          Positioned(right: -s * .02, bottom: s * .04, child: CapsuleShape(length: s * .5, thickness: s * .2)),
          Positioned(
              left: 0,
              top: s * .02,
              child: Container(
                padding: EdgeInsets.all(s * .04),
                decoration: const BoxDecoration(color: C.violet, shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, color: Colors.white, size: s * .16),
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
              Text(l, textAlign: TextAlign.center, style: t(12.5, w: FontWeight.w600)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Access', style: t(18, w: FontWeight.w700)),
      const SizedBox(height: 12),
      Row(children: [
        q(Icons.description_outlined, 'My\nPrescriptions', () => push(context, const MyPrescriptionsScreen())),
        const SizedBox(width: 12),
        q(Icons.receipt_long_outlined, 'My\nOrders', () => tabIndex.value = 2),
        const SizedBox(width: 12),
        q(Icons.local_pharmacy_outlined, 'Explore\nPharmacies', () => push(context, const PharmaciesScreen())),
      ]),
    ]);
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Icon(i, color: C.purple, size: 24),
              ),
              Row(children: [
                Expanded(child: Text(title, style: t(15, w: FontWeight.w700, c: C.indigo))),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: C.purple),
              ]),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Explore Healthcare', 'Everything you need, in one place.'),
      ResponsiveGrid(minTileWidth: 150, children: [
        cat(Icons.medication_outlined, 'Medicines', const Color(0xFFF1EDFF), const MedicinesScreen()),
        cat(Icons.spa_outlined, 'Healthcare Products', const Color(0xFFEDEBFF), const ProductsScreen()),
        cat(Icons.local_pharmacy_outlined, 'Nearby Pharmacies', const Color(0xFFF4EFFF), const PharmaciesScreen()),
        cat(Icons.description_outlined, 'My Prescriptions', const Color(0xFFEFEEFB), const MyPrescriptionsScreen()),
      ]),
    ]);
  }

  // ---------- Recently viewed ----------
  Widget _recent() => ValueListenableBuilder<List<Medicine>>(
        valueListenable: recentlyViewed,
        builder: (context, list, _) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    avatar: const Icon(Icons.history_rounded, size: 18, color: C.purple),
                    label: Text(list[i].name, style: t(13.5, w: FontWeight.w600)),
                    onPressed: () => showMedicineSheet(context, list[i]),
                  ),
                ),
              ),
            ]),
          );
        },
      );

  // ---------- Pharmacies ----------
  Widget _pharmacySection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Pharmacies for You', 'Explore pharmacies available through DAWA.'),
        ResponsiveGrid(minTileWidth: 280, children: [
          for (final p in pharmacies) PharmacyCard(p, onTap: () => push(context, PharmacyDetailScreen(p))),
        ]),
        const SizedBox(height: 8),
        Text('Fictional demo pharmacies. Details and availability are not real.', style: t(12, c: C.sub)),
      ]);

  // ---------- How it works ----------
  Widget _howItWorks() {
    final steps = const [
      (Icons.description_outlined, 'Upload Prescription', 'Upload a picture of your prescription through the DAWA app.'),
      (Icons.local_pharmacy_outlined, 'Find a Pharmacy', 'DAWA helps match your required medicines with available demo pharmacy inventory.'),
      (Icons.inventory_2_outlined, 'Get Your Medicines', 'Confirm your order and follow its progress through the application.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('How DAWA Works', 'Healthcare, made easier in three simple steps.'),
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 700;
        Widget step(int i) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.purple, C.violet]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(steps[i].$1, color: Colors.white, size: 26),
                ),
                if (!wide && i < 2) Container(width: 2, height: 40, color: C.a(C.lavender, .5)),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Step ${i + 1}', style: t(12, w: FontWeight.w700, c: C.violet)),
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
                Padding(
                  padding: const EdgeInsets.only(top: 25, left: 6, right: 6),
                  child: Icon(Icons.more_horiz_rounded, color: C.lavender, size: 28),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.verified_user_outlined, color: C.purple, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your Health Deserves Care.', style: t(18, w: FontWeight.w800, c: C.indigo)),
              const SizedBox(height: 6),
              Text('Prescription orders should be reviewed by a qualified pharmacist before approval.',
                  style: t(14, c: C.text.withAlpha(200), h: 1.5)),
            ]),
          ),
        ]),
      );

  // ---------- Health info ----------
  Widget _healthInfo() {
    const tips = [
      (Icons.water_drop_outlined, 'Stay hydrated', 'Drinking enough water supports everyday wellbeing.'),
      (Icons.menu_book_outlined, 'Read the label', 'Check instructions and expiry dates on all medicines.'),
      (Icons.medical_information_outlined, 'Ask a professional', 'Talk to your doctor or pharmacist with any medicine questions.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Healthcare Information', 'General reminders. Not medical advice.'),
      ResponsiveGrid(minTileWidth: 240, children: [
        for (final tp in tips)
          DawaCard(
            shadow: false,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconChip(tp.$1, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
