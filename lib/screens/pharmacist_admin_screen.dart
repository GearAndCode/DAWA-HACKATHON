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
  String? _error;
  String? _statusFilter;

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
        title: Text(approve ? 'Verify Prescription Order' : 'Reject Prescription Order'),
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
                  border: OutlineInputBorder(),
                ),
              )
            else
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'e.g. Unclear dosage / missing doctor registration number.',
                  border: OutlineInputBorder(),
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
              backgroundColor: approve ? C.green : Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Confirm Verification' : 'Reject Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.instance.verifyOrder(
        orderId,
        action: approve ? 'VERIFY' : 'REJECT',
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        rejectionReason:
            reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
      );

      _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? 'Prescription clinically verified!'
                : 'Order rejected with recorded notice.'),
            backgroundColor: approve ? C.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    }
  }

  Future<void> _updateStage(int orderId, String nextStatus) async {
    try {
      await ApiService.instance.updateOrderStatus(orderId, status: nextStatus);
      _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order moved to "$nextStatus"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status update error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Pharmacist Admin Portal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: C.lavender, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. Haris (Licensed Pharmacist)',
                          style: t(16,
                              w: FontWeight.w700, c: Colors.white)),
                      Text(
                        'DAWA Clinical Verification Portal • License #PH-2026-LHR',
                        style: t(12, c: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _fetchOrders,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text('Incoming Prescription Orders',
              style: t(18, w: FontWeight.w800, c: C.indigo)),
          const SizedBox(height: 8),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            DawaCard(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            )
          else if (_orders.isEmpty)
            const EmptyState(
              Icons.inbox_outlined,
              'No orders in queue',
              'Prescriptions submitted by patients will appear here for verification.',
            )
          else
            for (final o in _orders)
              _buildAdminOrderCard(o),
        ],
      ),
    );
  }

  Widget _buildAdminOrderCard(Map<String, dynamic> o) {
    final orderId = o['id'] as int;
    final orderNumber = o['order_number'] ?? 'DAWA-2026-0001';
    final status = o['status'] ?? 'Order Placed';
    final fulfillmentType = o['fulfillment_type'] ?? 'pickup';
    final isPickup = fulfillmentType == 'pickup';
    final totalAmount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
    final pharmacyName = o['pharmacy_name'] ?? 'DAWA Pharmacy';
    final invoice = o['invoice'] as Map<String, dynamic>?;
    final List items = invoice?['items'] ?? [];
    final isHighlight = widget.highlightOrderId == orderId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DawaCard(
        border: isHighlight ? Border.all(color: C.purple, width: 2) : null,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orderNumber,
                        style: t(16, w: FontWeight.w800, c: C.indigo)),
                    Text(
                      '$pharmacyName • ${fulfillmentType.toUpperCase()}',
                      style: t(12, c: C.sub),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.contains('Awaiting')
                        ? const Color(0xFFFEF3C7)
                        : (status.contains('Verified')
                            ? const Color(0xFFDCFCE7)
                            : C.light),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: t(11.5,
                        w: FontWeight.w700,
                        c: status.contains('Awaiting')
                            ? const Color(0xFFB45309)
                            : (status.contains('Verified')
                                ? const Color(0xFF15803D)
                                : C.purple)),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: C.border),

            // Medicines List
            Text('Prescribed Items (${items.length}):',
                style: t(13, w: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.medication_rounded,
                        size: 14, color: C.purple),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${it['medicine_name']} (${it['strength'] ?? 'Standard'}) x${it['quantity']}',
                        style: t(13, c: C.text),
                      ),
                    ),
                    Text('PKR ${it['line_total']}',
                        style: t(13, w: FontWeight.w600)),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Order Value:',
                    style: t(13, c: C.sub)),
                Text('PKR ${totalAmount.toStringAsFixed(0)}',
                    style: t(15.5, w: FontWeight.w800, c: C.indigo)),
              ],
            ),
            const Divider(height: 20, color: C.border),

            // Stage Action Buttons
            if (status == 'Awaiting Pharmacist Verification' || status == 'Order Placed') ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: C.green,
                        minimumSize: const Size(0, 42),
                      ),
                      onPressed: () => _verifyOrder(orderId, true),
                      icon: const Icon(Icons.verified_rounded, size: 18),
                      label: const Text('Verify & Approve'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        minimumSize: const Size(0, 42),
                      ),
                      onPressed: () => _verifyOrder(orderId, false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'Verified by Pharmacist') ...[
              FilledButton.icon(
                onPressed: () => _updateStage(orderId, 'Preparing Order'),
                icon: const Icon(Icons.hourglass_top_rounded, size: 18),
                label: const Text('Mark as Preparing Order'),
              ),
            ] else if (status == 'Preparing Order') ...[
              FilledButton.icon(
                onPressed: () => _updateStage(
                  orderId,
                  isPickup ? 'Ready for Pickup' : 'Out for Delivery',
                ),
                icon: Icon(
                  isPickup
                      ? Icons.storefront_rounded
                      : Icons.delivery_dining_rounded,
                  size: 18,
                ),
                label: Text(
                  isPickup
                      ? 'Mark as Ready for Pickup'
                      : 'Mark as Out for Delivery',
                ),
              ),
            ] else if (status == 'Ready for Pickup' || status == 'Out for Delivery') ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.green),
                onPressed: () => _updateStage(
                  orderId,
                  isPickup ? 'Collected' : 'Delivered',
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  isPickup ? 'Mark as Collected' : 'Mark as Delivered',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF15803D), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Fulfillment Complete',
                      style: t(13,
                          w: FontWeight.w700, c: const Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
