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
  String _selectedFilter = 'all'; // all, full, partial, nearest

  List<Map<String, dynamic>> get _filteredPharmacies {
    var list = List<Map<String, dynamic>>.from(widget.matchingPharmacies);
    if (_selectedFilter == 'full') {
      list = list.where((p) => p['fully_available'] == true).toList();
    } else if (_selectedFilter == 'partial') {
      list = list.where((p) => p['fully_available'] == false).toList();
    } else if (_selectedFilter == 'nearest') {
      list.sort((a, b) => ((a['distance_km'] ?? 0) as num)
          .compareTo((b['distance_km'] ?? 0) as num));
    }
    return list;
  }

  Future<void> _selectPharmacy(Map<String, dynamic> pharmacy) async {
    final pharmacyId = pharmacy['pharmacy_id'] as int;
    setState(() => _generatingPharmacyId = pharmacyId);

    try {
      final invoice = await ApiService.instance.generateInvoice(
        prescriptionId: widget.prescriptionId,
        pharmacyId: pharmacyId,
        delivery: false,
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
    final pharmacies = _filteredPharmacies;

    return PageScaffold(
      title: 'Available Pharmacies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtitle
          Text(
            'Compare medicine availability and choose where to order.',
            style: t(14, c: C.sub),
          ),
          const SizedBox(height: 16),

          // 1. Requested Prescription Summary Banner
          FadeSlideEntrance(
            child: DawaSurface(
              color: const Color(0xFFF1EDFF),
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
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Matching ${widget.confirmedItems.length} Prescription Items',
                          style: t(15, w: FontWeight.w700, c: C.indigo),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.confirmedItems
                              .map((e) => e['medicine_name'])
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(12.5, c: C.sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Refined Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Stores', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('100% In Stock', 'full'),
                const SizedBox(width: 8),
                _buildFilterChip('Partial Stock', 'partial'),
                const SizedBox(width: 8),
                _buildFilterChip('Nearest First', 'nearest'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Empty State if no pharmacies match filter
          if (pharmacies.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.store_mall_directory_outlined,
                        size: 48, color: C.sub),
                    const SizedBox(height: 12),
                    Text('No pharmacies match this filter',
                        style: t(16, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'Try switching to "All Stores" to review availability.',
                      style: t(13, c: C.sub),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 4. Pharmacy Results Cards
          for (int i = 0; i < pharmacies.length; i++) ...[
            FadeSlideEntrance(
              delay: Duration(milliseconds: 100 * i),
              slideOffset: 16,
              child: _buildPharmacyCard(pharmacies[i]),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? C.purple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? C.purple : const Color(0xFFE9E6F0),
            width: 1.0,
          ),
          boxShadow: isSelected ? DawaShadows.purpleGlow : DawaShadows.subtle,
        ),
        child: Text(
          label,
          style: t(
            12.5,
            w: isSelected ? FontWeight.w700 : FontWeight.w500,
            c: isSelected ? Colors.white : C.text,
          ),
        ),
      ),
    );
  }

  Widget _buildPharmacyCard(Map<String, dynamic> p) {
    final name = p['pharmacy_name'] ?? 'Pharmacy';
    final address = p['address'] ?? 'Lahore';
    final dist = p['distance_km'] ?? '0.0';
    final isFull = p['fully_available'] as bool? ?? false;
    final total = p['total_estimated_cost_pkr'] ?? 0;
    final pharmacyId = p['pharmacy_id'] as int;
    final isGenerating = _generatingPharmacyId == pharmacyId;
    final List items = p['items'] ?? [];

    final availableCount = items.where((it) => it['available'] == true).length;
    final totalCount = items.length;

    return DawaSurface(
      hasGlow: isFull,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isFull ? const Color(0xFFDCFCE7) : C.light,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_pharmacy_rounded,
                  color: isFull ? const Color(0xFF15803D) : C.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: t(16.5, w: FontWeight.w800, c: C.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$address • $dist km away',
                      style: t(12.5, c: C.sub),
                    ),
                  ],
                ),
              ),
              DawaBadge(
                label: isFull
                    ? '$availableCount/$totalCount In Stock'
                    : '$availableCount/$totalCount Partial',
                bg: isFull ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                text: isFull ? const Color(0xFF15803D) : const Color(0xFFB45309),
                icon: isFull ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Medicine availability pill list
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9E6F0)),
            ),
            child: Column(
              children: [
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          it['available'] == true
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 15,
                          color: it['available'] == true
                              ? const Color(0xFF15803D)
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${it['medicine_name']} (${it['strength']})',
                            style: t(13, w: FontWeight.w600),
                          ),
                        ),
                        Text(
                          it['available'] == true
                              ? 'PKR ${it['unit_price']}'
                              : 'Out of Stock',
                          style: t(
                            12.5,
                            c: it['available'] == true ? C.text : const Color(0xFFDC2626),
                            w: it['available'] == true ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Footer Row with Estimated Total & Select Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated Subtotal', style: t(11.5, c: C.sub)),
                  Text(
                    'PKR $total',
                    style: t(17.5, w: FontWeight.w800, c: C.indigo),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: isGenerating ? null : () => _selectPharmacy(p),
                icon: isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(isGenerating ? 'Calculating...' : 'Select Pharmacy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
