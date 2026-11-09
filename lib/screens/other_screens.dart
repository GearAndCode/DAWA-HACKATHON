import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../navigation/nav.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'prescription_screen.dart';
import 'order_tracking_screen.dart';
import 'pharmacist_admin_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Medicines',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Lahore pharmacy inventory catalog.', style: t(14, c: C.sub)),
          const SizedBox(height: 16),
          ResponsiveGrid(minTileWidth: 300, children: [for (final m in medicines) MedicineTile(m)]),
        ]),
      );
}

class AllMedicinesScreen extends StatelessWidget {
  const AllMedicinesScreen({super.key});
  @override
  Widget build(BuildContext context) => const MedicinesScreen();
}

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Healthcare Products',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Available wellness essentials.', style: t(14, c: C.sub)),
          const SizedBox(height: 16),
          ResponsiveGrid(minTileWidth: 260, children: [
            for (final p in products)
              DawaSurface(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  IconChip(p.icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: t(15, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(p.category, style: t(12.5, c: C.sub)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ]),
      );
}

class PharmaciesScreen extends StatelessWidget {
  const PharmaciesScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Nearby Pharmacies',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Verified partner pharmacies in Lahore.', style: t(14, c: C.sub)),
          const SizedBox(height: 16),
          ResponsiveGrid(minTileWidth: 300, children: [
            for (final p in pharmacies) PharmacyCard(p, onTap: () => push(context, PharmacyDetailScreen(p))),
          ]),
        ]),
      );
}

class PharmacyDetailScreen extends StatelessWidget {
  final Pharmacy p;
  const PharmacyDetailScreen(this.p, {super.key});

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: p.name,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DawaSurface(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: C.light,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(p.icon, color: C.purple, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(p.name, style: t(20, w: FontWeight.w800, c: C.indigo))),
              ]),
              const SizedBox(height: 16),
              Text(p.description, style: t(14, c: C.sub, h: 1.5)),
              const SizedBox(height: 16),
              _info(Icons.location_on_outlined, p.area),
              _info(Icons.schedule_rounded, p.hours),
              _info(Icons.check_circle_outline_rounded, 'Verified partner: Open now', color: C.green),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Sample Inventory', subtitle: 'Frequently dispensed medicines'),
          ResponsiveGrid(minTileWidth: 300, children: [for (final m in medicines.take(4)) MedicineTile(m)]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.light,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: C.purple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Real stock availability is confirmed dynamically when you upload and submit your prescription.',
                    style: t(13, c: C.indigo, h: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => push(context, const PrescriptionScreen()),
            icon: const Icon(Icons.document_scanner_rounded),
            label: const Text('Scan Prescription for This Pharmacy'),
          ),
        ]),
      );

  Widget _info(IconData i, String s, {Color color = C.sub}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(i, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(s, style: t(13.5, c: color == C.sub ? C.text : color, w: FontWeight.w500))),
        ]),
      );
}

class MyPrescriptionsScreen extends StatelessWidget {
  const MyPrescriptionsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Prescription Records',
        child: ValueListenableBuilder<List<PrescriptionRecord>>(
          valueListenable: prescriptionRecords,
          builder: (context, list, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (list.isEmpty)
              const EmptyState(Icons.description_outlined, 'No prescriptions yet',
                  'Prescriptions you upload will be safely organized here for your records.')
            else
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DawaSurface(
                    padding: const EdgeInsets.all(16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (r.bytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(r.bytes!, width: 68, height: 68, fit: BoxFit.cover),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_fmt(r.date), style: t(12, c: C.sub)),
                          const SizedBox(height: 4),
                          Text(r.items.join(', '), style: t(14.5, w: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('Prescription logged on this device.', style: t(12, c: C.sub)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => push(context, const PrescriptionScreen()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Upload New Prescription'),
            ),
          ]),
        ),
      );

  static String _fmt(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${m[d.month - 1]} ${d.year}, ${d.hour}:$mm';
  }
}

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FadeSlideEntrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore', style: t(28, w: FontWeight.w800, c: C.indigo, ls: -0.4)),
                const SizedBox(height: 4),
                Text('Browse medicines, pharmacies and wellness products across Lahore.', style: t(14, c: C.sub)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Catalogue Medicines', subtitle: 'Standard dosage formulations'),
          ResponsiveGrid(minTileWidth: 300, children: [for (final m in medicines) MedicineTile(m)]),
          const SizedBox(height: 30),
          const SectionHeader('Verified Pharmacies', subtitle: 'Demonstration partner branches'),
          ResponsiveGrid(minTileWidth: 280, children: [
            for (final p in pharmacies) PharmacyCard(p, onTap: () => push(context, PharmacyDetailScreen(p))),
          ]),
        ]),
      );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.instance.getOrders();
      if (mounted) {
        setState(() {
          _orders = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FadeSlideEntrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Orders', style: t(28, w: FontWeight.w800, c: C.indigo, ls: -0.4)),
                    const SizedBox(height: 4),
                    Text('Track live status and review fulfillment history.', style: t(14, c: C.sub)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: C.purple),
                tooltip: 'Refresh Orders',
                onPressed: _fetchOrders,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
              ),
            )
          else if (_orders.isEmpty)
            const EmptyState(Icons.inventory_2_outlined, 'No active orders',
                'When you upload a prescription and confirm an order, your live progress will be tracked here.')
          else
            for (int i = 0; i < _orders.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: FadeSlideEntrance(
                  delay: Duration(milliseconds: 80 * i),
                  child: DawaSurface(
                    padding: const EdgeInsets.all(18),
                    onTap: () => push(context, OrderTrackingScreen(order: _orders[i])),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _orders[i]['order_reference'] ?? _orders[i]['order_number'] ?? 'DAWA-ORDER',
                              style: t(16, w: FontWeight.w800, c: C.indigo),
                            ),
                            DawaBadge(
                              label: _orders[i]['order_status'] ?? _orders[i]['status'] ?? 'Order Placed',
                              bg: const Color(0xFFF1EDFF),
                              text: C.purple,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_orders[i]['pharmacy_name']} • ${_orders[i]['fulfillment_method'] ?? _orders[i]['fulfillment_type'] ?? 'Pickup'}',
                          style: t(13, c: C.sub),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PKR ${(_orders[i]['grand_total'] ?? _orders[i]['total_amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                              style: t(15.5, w: FontWeight.w800, c: C.text),
                            ),
                            Row(
                              children: [
                                Text('Track Order', style: t(13, w: FontWeight.w700, c: C.purple)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 16, color: C.purple),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ]),
      );
}

class ProfileScreen extends StatelessWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 1. Luxury Profile Header Card with Ambient Glow
      IlluminatedCard(
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, color: C.purple, size: 32),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ali Raza', style: t(19, w: FontWeight.w800, c: Colors.white)),
              const SizedBox(height: 2),
              Text('DAWA Patient • Lahore, Pakistan', style: t(13, c: const Color(0xFFDDD6FE))),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // 2. Settings Rows
      ValueListenableBuilder<DemoLocation>(
        valueListenable: selectedLocation,
        builder: (_, l, __) => _tile(Icons.location_on_outlined, 'Delivery Location', '${l.label}, ${l.address}', null),
      ),
      _tile(Icons.description_outlined, 'My Prescriptions', 'View uploaded prescription history', () => push(context, const MyPrescriptionsScreen())),
      _tile(Icons.admin_panel_settings_outlined, 'Pharmacist Operations Portal', 'Verify prescriptions and update order milestones', () => push(context, const PharmacistAdminScreen())),
      _tile(Icons.notifications_none_rounded, 'Notifications', 'Manage order and fulfillment alerts', () => push(context, const NotificationsScreen())),
      _tile(Icons.health_and_safety_outlined, 'Healthcare Safety Guarantee', 'Every prescription is verified by a qualified pharmacist.', null),
      _tile(Icons.info_outline_rounded, 'About DAWA', 'Connecting You to Better Healthcare • v1.0.0', null),
    ]);

    if (embedded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FadeSlideEntrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: t(28, w: FontWeight.w800, c: C.indigo, ls: -0.4)),
                const SizedBox(height: 4),
                Text('Account preferences, records, and operations.', style: t(14, c: C.sub)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          body,
        ]),
      );
    }
    return PageScaffold(title: 'Profile', child: body);
  }

  Widget _tile(IconData i, String title, String sub, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DawaSurface(
          padding: const EdgeInsets.all(16),
          onTap: onTap,
          child: Row(children: [
            IconChip(i, size: 42, iconSize: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t(15, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: t(12.5, c: C.sub)),
              ]),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: C.sub, size: 20),
          ]),
        ),
      );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Notifications',
        child: Column(children: [
          for (final n in notifications)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DawaSurface(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconChip(Icons.notifications_none_rounded, size: 42, iconSize: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(n.title, style: t(15, w: FontWeight.w700))),
                        Text(n.time, style: t(12, c: C.sub)),
                      ]),
                      const SizedBox(height: 4),
                      Text(n.body, style: t(13, c: C.sub, h: 1.4)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      );
}
