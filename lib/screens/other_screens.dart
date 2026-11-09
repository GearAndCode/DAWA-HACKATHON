import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'prescription_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Medicines',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Demo medicine list. Availability is not live.', style: t(13.5, c: C.sub)),
          const SizedBox(height: 14),
          ResponsiveGrid(minTileWidth: 300, children: [for (final m in medicines) MedicineTile(m)]),
        ]),
      );
}

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Healthcare Products',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Demo catalogue. Not available for purchase.', style: t(13.5, c: C.sub)),
          const SizedBox(height: 14),
          ResponsiveGrid(minTileWidth: 260, children: [
            for (final p in products)
              DawaCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  IconChip(p.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: t(15, w: FontWeight.w600)),
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
          Text('Fictional demo pharmacies. Distances and availability are not real.', style: t(13.5, c: C.sub)),
          const SizedBox(height: 14),
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
          DawaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconChip(p.icon, size: 60),
                const SizedBox(width: 14),
                Expanded(child: Text(p.name, style: t(21, w: FontWeight.w800, c: C.indigo))),
              ]),
              const SizedBox(height: 16),
              Text(p.description, style: t(14.5, c: C.sub, h: 1.5)),
              const SizedBox(height: 16),
              _info(Icons.location_on_outlined, p.area),
              _info(Icons.schedule_rounded, p.hours),
              _info(Icons.check_circle_outline_rounded, 'Demo availability: Available', color: C.green),
            ]),
          ),
          const SizedBox(height: 18),
          Text('Sample medicines (demo)', style: t(17, w: FontWeight.w700)),
          const SizedBox(height: 10),
          ResponsiveGrid(minTileWidth: 300, children: [for (final m in medicines.take(4)) MedicineTile(m)]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(14)),
            child: Text(
                'This is a fictional pharmacy with demo information. It has no real ratings, certifications, stock or distances.',
                style: t(13, c: C.indigo)),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => push(context, const PrescriptionScreen()),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload Prescription'),
          ),
        ]),
      );

  Widget _info(IconData i, String s, {Color color = C.sub}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(i, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(s, style: t(14, c: color == C.sub ? C.text : color))),
        ]),
      );
}

class MyPrescriptionsScreen extends StatelessWidget {
  const MyPrescriptionsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'My Prescriptions',
        child: ValueListenableBuilder<List<PrescriptionRecord>>(
          valueListenable: prescriptionRecords,
          builder: (context, list, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (list.isEmpty)
              const EmptyState(Icons.description_outlined, 'No prescriptions yet',
                  'Prescriptions you upload will be saved here on this device (demo).')
            else
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DawaCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (r.bytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(r.bytes!, width: 64, height: 64, fit: BoxFit.cover),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_fmt(r.date), style: t(13, c: C.sub)),
                          const SizedBox(height: 4),
                          Text(r.items.join(', '), style: t(14.5, w: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Saved on this device. Not sent to a pharmacy (demo).', style: t(12.5, c: C.sub)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            const SizedBox(height: 8),
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
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Explore', style: t(28, w: FontWeight.w800, c: C.indigo)),
          const SizedBox(height: 4),
          Text('Medicines, products and pharmacies (demo data).', style: t(14, c: C.sub)),
          const SizedBox(height: 22),
          const SectionHeader('Medicines', 'Browse the demo medicine list.'),
          ResponsiveGrid(minTileWidth: 300, children: [for (final m in medicines) MedicineTile(m)]),
          const SizedBox(height: 28),
          const SectionHeader('Pharmacies', 'Fictional demo pharmacies.'),
          ResponsiveGrid(minTileWidth: 280, children: [
            for (final p in pharmacies) PharmacyCard(p, onTap: () => push(context, PharmacyDetailScreen(p))),
          ]),
        ]),
      );
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Orders', style: t(28, w: FontWeight.w800, c: C.indigo)),
          const SizedBox(height: 4),
          Text('Your orders and prescription submissions.', style: t(14, c: C.sub)),
          const SizedBox(height: 10),
          const EmptyState(Icons.inventory_2_outlined, 'No orders yet',
              'Ordering and delivery tracking are not live in this demo version.'),
          Text('Prescription submissions', style: t(17, w: FontWeight.w700)),
          const SizedBox(height: 10),
          ValueListenableBuilder<List<PrescriptionRecord>>(
            valueListenable: prescriptionRecords,
            builder: (context, list, _) => list.isEmpty
                ? Text('None yet.', style: t(14, c: C.sub))
                : Column(children: [
                    for (final r in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DawaCard(
                          shadow: false,
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            const IconChip(Icons.description_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r.items.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: t(14.5, w: FontWeight.w600)),
                                Text('Saved on device (demo)', style: t(12.5, c: C.sub)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ]),
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
      DawaCard(
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [C.purple, C.violet])),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Guest User', style: t(19, w: FontWeight.w700)),
              Text('Demo profile - sign-in is not available yet', style: t(13, c: C.sub)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      ValueListenableBuilder<DemoLocation>(
        valueListenable: selectedLocation,
        builder: (_, l, __) => _tile(Icons.location_on_outlined, 'Delivery location', '${l.label}, ${l.address}', null),
      ),
      _tile(Icons.description_outlined, 'My Prescriptions', 'View saved prescriptions', () => push(context, const MyPrescriptionsScreen())),
      _tile(Icons.notifications_none_rounded, 'Notifications', 'View updates', () => push(context, const NotificationsScreen())),
      _tile(Icons.verified_user_outlined, 'Safety', 'Prescription orders should be reviewed by a qualified pharmacist.', null),
      _tile(Icons.info_outline_rounded, 'About DAWA', 'Connecting You to Better Healthcare. Demo version 1.0.0', null),
    ]);
    if (embedded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Profile', style: t(28, w: FontWeight.w800, c: C.indigo)),
          const SizedBox(height: 16),
          body,
        ]),
      );
    }
    return PageScaffold(title: 'Profile', child: body);
  }

  Widget _tile(IconData i, String title, String sub, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DawaCard(
          shadow: false,
          padding: const EdgeInsets.all(14),
          onTap: onTap,
          child: Row(children: [
            IconChip(i, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t(15, w: FontWeight.w600)),
                Text(sub, style: t(12.5, c: C.sub)),
              ]),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: C.sub),
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
              padding: const EdgeInsets.only(bottom: 10),
              child: DawaCard(
                shadow: false,
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconChip(Icons.notifications_none_rounded, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(n.title, style: t(15, w: FontWeight.w700))),
                        Text(n.time, style: t(12, c: C.sub)),
                      ]),
                      const SizedBox(height: 3),
                      Text(n.body, style: t(13.5, c: C.sub)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      );
}
