import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class PharmacistAdminScreen extends StatefulWidget {
  final int? highlightOrderId;

  const PharmacistAdminScreen({super.key, this.highlightOrderId});

  @override
  State<PharmacistAdminScreen> createState() => _PharmacistAdminScreenState();
}

class _PharmacistAdminScreenState extends State<PharmacistAdminScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _statusFilter;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orders = await ApiService.instance.getAdminOrders(
        statusFilter: _statusFilter,
      );
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load pharmacist orders: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyOrder(int orderId, bool approve) async {
    final notesCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(approve ? 'Verify Prescription Order' : 'Reject Prescription Order',
            style: t(17, w: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                  ? 'Confirm that you have reviewed the prescription document, validated dosages, and verified inventory stock.'
                  : 'State the medical or regulatory reason for rejecting this prescription.',
              style: t(13.5, c: C.sub),
            ),
            const SizedBox(height: 14),
            if (approve)
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pharmacist Verification Notes',
                  hintText: 'e.g. Valid doctor signature verified. Stock confirmed.',
                ),
              )
            else
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'e.g. Unclear dosage / missing doctor registration number.',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approve ? const Color(0xFF24845A) : const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Confirm & Verify' : 'Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.instance.verifyOrder(
        orderId,
        action: approve ? "VERIFY" : "REJECT",
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        rejectionReason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
      );
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update verification: $e')),
      );
    }
  }

  Future<void> _advanceStatus(int orderId, String nextStatus) async {
    try {
      await ApiService.instance.updateOrderStatus(
        orderId,
        status: nextStatus,
        notes: 'Status advanced by pharmacist in portal: $nextStatus',
      );
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Pharmacist Operations',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: C.purple),
          tooltip: 'Refresh',
          onPressed: _fetchOrders,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Operations Header Card with Ambient Glow
          IlluminatedCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.verified_user_rounded,
                        color: C.purple, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Licensed Pharmacist Console',
                        style: t(16.5, w: FontWeight.w800, c: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Verify incoming prescription orders and update fulfillment milestones in real-time.',
                        style: t(12.5, c: const Color(0xFFDDD6FE), h: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Metrics Bar
          Row(
            children: [
              _metricBox(
                'Total Orders',
                '${_orders.length}',
                const Color(0xFF312E81),
                Icons.receipt_long_rounded,
              ),
              const SizedBox(width: 10),
              _metricBox(
                'Pending Review',
                '${_orders.where((o) => (o['order_status'] ?? o['status']) == 'Awaiting Pharmacist Verification').length}',
                const Color(0xFFD97706),
                Icons.pending_actions_rounded,
              ),
              const SizedBox(width: 10),
              _metricBox(
                'Ready / Active',
                '${_orders.where((o) => (o['order_status'] ?? o['status']) != 'Delivered' && (o['order_status'] ?? o['status']) != 'Collected').length}',
                const Color(0xFF24845A),
                Icons.local_shipping_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Filter Segment
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterBtn('All Orders', null),
                const SizedBox(width: 8),
                _filterBtn('Pending Verification', 'Awaiting Pharmacist Verification'),
                const SizedBox(width: 8),
                _filterBtn('Verified', 'Verified by Pharmacist'),
                const SizedBox(width: 8),
                _filterBtn('Preparing', 'Preparing Order'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. Order List
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 12),
                    Text(_error!, style: t(13.5, c: C.sub), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _fetchOrders,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (_orders.isEmpty)
            const EmptyState(Icons.task_alt_rounded, 'No orders matching filter',
                'All prescription orders are processed or none match the selected status filter.')
          else
            for (final o in _orders) ...[
              _buildAdminOrderCard(o),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: DawaSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 16, color: color),
                Text(value, style: t(18, w: FontWeight.w900, c: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: t(11.5, c: C.sub, w: FontWeight.w500), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _filterBtn(String label, String? filter) {
    final active = _statusFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = filter);
        _fetchOrders();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? C.purple : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? C.purple : const Color(0xFFE9E6F0),
          ),
          boxShadow: active ? DawaShadows.purpleGlow : DawaShadows.subtle,
        ),
        child: Text(
          label,
          style: t(12,
              w: active ? FontWeight.w700 : FontWeight.w500,
              c: active ? Colors.white : C.text),
        ),
      ),
    );
  }

  Widget _buildAdminOrderCard(Map<String, dynamic> o) {
    final id = o['id'] as int;
    final ref = o['order_reference'] ?? o['order_number'] ?? 'DAWA-ORDER';
    final status = o['order_status'] ?? o['status'] ?? 'Order Placed';
    final fulfillment = o['fulfillment_method'] ?? o['fulfillment_type'] ?? 'pickup';
    final isPickup = fulfillment == 'pickup';
    final isAwaiting = status == 'Awaiting Pharmacist Verification';
    final total = (o['grand_total'] ?? o['total_amount'] as num?)?.toDouble() ?? 0.0;
    final pharmacyName = o['pharmacy_name'] ?? 'Pharmacy';
    final List items = o['items'] ?? [];

    return DawaSurface(
      hasGlow: isAwaiting,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ref, style: t(16, w: FontWeight.w800, c: C.indigo)),
              DawaBadge(
                label: status,
                bg: isAwaiting ? const Color(0xFFFEF3C7) : const Color(0xFFF1EDFF),
                text: isAwaiting ? const Color(0xFFB45309) : C.purple,
                icon: isAwaiting ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$pharmacyName • ${isPickup ? "Counter Pickup" : "Home Delivery"}',
            style: t(13, c: C.sub),
          ),
          const SizedBox(height: 12),

          // Medicine Items List
          if (items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE9E6F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.medication_outlined, size: 14, color: C.purple),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${it['medicine_name']} (${it['strength'] ?? ''})',
                              style: t(12.5, w: FontWeight.w600),
                            ),
                          ),
                          Text('x${it['quantity']}', style: t(12, w: FontWeight.w700, c: C.sub)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Total: PKR ${total.toStringAsFixed(0)}',
                  style: t(14, w: FontWeight.w700)),
              Text('ID: #$id', style: t(12, c: C.sub)),
            ],
          ),
          const SizedBox(height: 14),

          // Pharmacist Action Buttons
          if (isAwaiting) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF24845A),
                      minimumSize: const Size(0, 42),
                    ),
                    onPressed: () => _verifyOrder(id, true),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Verify Order', style: TextStyle(fontSize: 13.5)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    minimumSize: const Size(0, 42),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  onPressed: () => _verifyOrder(id, false),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Reject', style: TextStyle(fontSize: 13.5)),
                ),
              ],
            ),
          ] else if (status == 'Verified by Pharmacist') ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () => _advanceStatus(id, 'Preparing Order'),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Advance to "Preparing Order"', style: TextStyle(fontSize: 13.5)),
            ),
          ] else if (status == 'Preparing Order') ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () => _advanceStatus(
                  id, isPickup ? 'Ready for Pickup' : 'Out for Delivery'),
              icon: Icon(isPickup ? Icons.storefront_outlined : Icons.local_shipping_outlined, size: 18),
              label: Text(
                  isPickup ? 'Mark "Ready for Pickup"' : 'Mark "Out for Delivery"',
                  style: const TextStyle(fontSize: 13.5)),
            ),
          ] else if (status == 'Ready for Pickup' || status == 'Out for Delivery') ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF24845A),
                minimumSize: const Size(0, 42),
              ),
              onPressed: () =>
                  _advanceStatus(id, isPickup ? 'Collected' : 'Delivered'),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(isPickup ? 'Mark "Collected"' : 'Mark "Delivered"',
                  style: const TextStyle(fontSize: 13.5)),
            ),
          ],
        ],
      ),
    );
  }
}
