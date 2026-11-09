import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'invoice_approval_screen.dart';

class PharmacyMatchingScreen extends StatefulWidget {
  final int prescriptionId;
  final List<Map<String, dynamic>> confirmedItems;
  final List<Map<String, dynamic>> matchingPharmacies;

  const PharmacyMatchingScreen({
    super.key,
    required this.prescriptionId,
    required this.confirmedItems,
    required this.matchingPharmacies,
  });

  @override
  State<PharmacyMatchingScreen> createState() => _PharmacyMatchingScreenState();
}

class _PharmacyMatchingScreenState extends State<PharmacyMatchingScreen> {
  int? _generatingPharmacyId;

  Future<void> _selectPharmacy(Map<String, dynamic> pharmacy) async {
    final pharmacyId = pharmacy['pharmacy_id'] as int;

    setState(() => _generatingPharmacyId = pharmacyId);

    try {
      final invoice = await ApiService.instance.generateInvoice(
        prescriptionId: widget.prescriptionId,
        pharmacyId: pharmacyId,
        delivery: false, // Default to pickup estimate initially
      );

      if (!mounted) return;
      setState(() => _generatingPharmacyId = null);

      push(
        context,
        InvoiceApprovalScreen(
          invoice: invoice,
          prescriptionId: widget.prescriptionId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingPharmacyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate invoice: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Pharmacy Inventory Match',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.light,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.border),
            ),
            child: Row(
              children: [
                const IconChip(Icons.inventory_rounded, bg: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Searching for ${widget.confirmedItems.length} Medicines',
                        style: t(15.5, w: FontWeight.w700, c: C.indigo),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.confirmedItems
                            .map((e) => e['medicine_name'])
                            .join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t(13, c: C.sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Available Nearby Pharmacies',
              style: t(18, w: FontWeight.w800, c: C.indigo)),
          const SizedBox(height: 4),
          Text(
            'Sorted by complete stock availability and nearest distance to you.',
            style: t(13, c: C.sub),
          ),
          const SizedBox(height: 14),

          if (widget.matchingPharmacies.isEmpty)
            const EmptyState(
              Icons.search_off_rounded,
              'No matching pharmacies found',
              'None of the demo pharmacies carry these items. Please edit medicines or try another query.',
            )
          else
            for (final p in widget.matchingPharmacies)
              _buildPharmacyMatchCard(p),
        ],
      ),
    );
  }

  Widget _buildPharmacyMatchCard(Map<String, dynamic> p) {
    final bool hasAll = p['has_all_medicines'] == true;
    final int availableCount = p['available_items_count'] ?? 0;
    final int totalRequested = p['total_items_requested'] ?? 0;
    final double dist = (p['distance_km'] as num?)?.toDouble() ?? 0.0;
    final double subtotal = (p['estimated_subtotal'] as num?)?.toDouble() ?? 0.0;
    final List availableItems = p['available_items'] ?? [];
    final List missingItems = p['missing_items'] ?? [];
    final pharmacyId = p['pharmacy_id'] as int;
    final isGenerating = _generatingPharmacyId == pharmacyId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DawaCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p['pharmacy_name'] ?? 'Pharmacy',
                              style: t(17, w: FontWeight.w700, c: C.indigo),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (hasAll)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Full Stock',
                                style: t(11,
                                    w: FontWeight.w700,
                                    c: const Color(0xFF15803D)),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Partial ($availableCount/$totalRequested)',
                                style: t(11,
                                    w: FontWeight.w700,
                                    c: const Color(0xFFB45309)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p['area']} • ${p['address']}',
                        style: t(12.5, c: C.sub),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: C.light,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_rounded,
                          size: 13, color: C.purple),
                      const SizedBox(width: 4),
                      Text(
                        '${dist.toStringAsFixed(1)} km',
                        style: t(12, w: FontWeight.w700, c: C.purple),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: C.border),

            // In Stock Items
            Text('Stock Status', style: t(13, w: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final it in availableItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: C.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${it['medicine_name']} (${it['strength']}) x${it['requested_quantity']}',
                        style: t(13, c: C.text),
                      ),
                    ),
                    Text('PKR ${it['line_total']}',
                        style: t(13, w: FontWeight.w600)),
                  ],
                ),
              ),

            // Missing Items
            for (final m in missingItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded,
                        color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${m['medicine_name']} (Out of Stock)',
                        style: t(13, c: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estimated Subtotal',
                        style: t(11.5, c: C.sub)),
                    Text(
                      'PKR ${subtotal.toStringAsFixed(0)}',
                      style: t(18, w: FontWeight.w800, c: C.indigo),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: isGenerating ? null : () => _selectPharmacy(p),
                  icon: isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_rounded, size: 18),
                  label: Text(isGenerating
                      ? 'Generating...'
                      : (hasAll ? 'Select & Invoice' : 'Select Available')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
