import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pharmacist_admin_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic>? order;
  final int? orderId;

  const OrderTrackingScreen({super.key, this.order, this.orderId})
      : assert(order != null || orderId != null);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _currentOrder;
  List<Map<String, dynamic>> _allocations = [];
  Timer? _pollingTimer;
  bool _isRefreshing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _currentOrder = widget.order;
      _loading = false;
    }
    _loadOrder();
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _refreshOrder());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    final id = widget.orderId ?? (_currentOrder != null ? _currentOrder!['id'] as int : null);
    if (id == null) return;
    try {
      final updated = await ApiService.instance.getOrderDetails(id);
      List<Map<String, dynamic>> allocs = [];
      final rxId = updated['prescription_id'] as int?;
      if (rxId != null) {
        allocs = await ApiService.instance.getPrescriptionAllocations(rxId);
      }
      if (mounted) {
        setState(() {
          _currentOrder = updated;
          _allocations = allocs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshOrder() async {
    if (_currentOrder == null) return;
    final id = _currentOrder!['id'] as int;
    try {
      final updated = await ApiService.instance.getOrderDetails(id);
      List<Map<String, dynamic>> allocs = _allocations;
      final rxId = updated['prescription_id'] as int?;
      if (rxId != null && _allocations.isEmpty) {
        allocs = await ApiService.instance.getPrescriptionAllocations(rxId);
      }
      if (mounted) {
        setState(() {
          _currentOrder = updated;
          _allocations = allocs;
        });
      }
    } catch (_) {}
  }

  int _getStageIndex(String currentStatus, bool isPickup) {
    if (currentStatus.contains('Rejected')) return -1;
    if (currentStatus == 'Order Placed') return 0;
    if (currentStatus == 'Awaiting Pharmacist Verification') return 1;
    if (currentStatus == 'Verified by Pharmacist') return 2;
    if (currentStatus == 'Preparing Order') return 3;
    if (currentStatus.contains('Ready') || currentStatus.contains('Out for Delivery')) return 4;
    if (currentStatus.contains('Delivered') || currentStatus.contains('Collected')) return 5;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _currentOrder == null) {
      return const PageScaffold(
        title: 'Order Status Tracking',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
          ),
        ),
      );
    }

    final orderNumber = _currentOrder!['order_reference'] ?? _currentOrder!['order_number'] ?? 'DAWA-2026-0001';
    final status = _currentOrder!['order_status'] ?? _currentOrder!['status'] ?? 'Order Placed';
    final fulfillmentType = _currentOrder!['fulfillment_method'] ?? _currentOrder!['fulfillment_type'] ?? 'pickup';
    final isPickup = fulfillmentType == 'pickup';
    final pharmacyName = _currentOrder!['pharmacy_name'] ?? 'DAWA Partner Pharmacy';
    final isRejected = status.contains('Rejected');
    final activeStageIndex = _getStageIndex(status, isPickup);
    final List history = _currentOrder!['timeline'] ?? _currentOrder!['status_history'] ?? [];

    final deliveryStages = [
      ('Order Placed', 'Order received and logged in system'),
      ('Awaiting Pharmacist Verification', 'Pharmacist reviewing prescription details'),
      ('Prescription Verified', 'Prescription and dosage verified'),
      ('Preparing Order', 'Medicines packed and sealed with security tag'),
      ('Out for Delivery', 'Rider dispatched to your address in Lahore'),
      ('Delivered', 'Order safely received by patient'),
    ];

    final pickupStages = [
      ('Order Placed', 'Order received and logged in system'),
      ('Awaiting Pharmacist Verification', 'Pharmacist reviewing prescription details'),
      ('Prescription Verified', 'Prescription and dosage verified'),
      ('Preparing Order', 'Medicines packed and kept in pickup bay'),
      ('Ready for Pickup', 'Available at counter for immediate collection'),
      ('Collected', 'Order collected at pharmacy counter'),
    ];

    final stages = isPickup ? pickupStages : deliveryStages;

    return PageScaffold(
      title: 'Order Status Tracking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Order Meta Card with Ambient Glow
          DawaSurface(
            hasGlow: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ORDER REFERENCE',
                            style: t(11.5,
                                w: FontWeight.w800, c: C.purple, ls: 1.2)),
                        const SizedBox(height: 2),
                        Text(orderNumber,
                            style: t(18.5, w: FontWeight.w800, c: C.indigo)),
                      ],
                    ),
                    IconButton(
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: C.purple),
                            )
                          : const Icon(Icons.refresh_rounded, color: C.purple),
                      tooltip: 'Refresh Status',
                      onPressed: () async {
                        setState(() => _isRefreshing = true);
                        await _refreshOrder();
                        if (mounted) setState(() => _isRefreshing = false);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      isPickup
                          ? Icons.storefront_rounded
                          : Icons.local_shipping_rounded,
                      size: 16,
                      color: C.purple,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPickup
                          ? 'Pharmacy Pickup at $pharmacyName'
                          : 'Home Delivery in Lahore',
                      style: t(13, w: FontWeight.w600, c: C.text),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current Status:', style: t(12.5, c: C.sub)),
                    DawaBadge(
                      label: status,
                      bg: isRejected
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFF1EDFF),
                      text: isRejected ? const Color(0xFFDC2626) : C.purple,
                      icon: isRejected
                          ? Icons.cancel_rounded
                          : Icons.access_time_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Fair Resource Allocation & Clinical Urgency Card
          if (_allocations.isNotEmpty) ...[
            const SizedBox(height: 16),
            DawaSurface(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1EDFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.balance_rounded,
                            color: C.purple, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fair Resource Allocation Status',
                              style: t(14.5, w: FontWeight.w700, c: C.indigo),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pharmacist-verified medicine allocation',
                              style: t(11.5, c: C.sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final a in _allocations) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F7FC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE9E6F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                a['medicine_name'] ?? 'Prescribed Medicine',
                                style: t(13, w: FontWeight.w700),
                              ),
                              DawaBadge(
                                label:
                                    '${a["allocation_status"]} (${a["allocated_quantity"]} / ${a["requested_quantity"]})',
                                bg: a['allocation_status'] == 'Fully Allocated'
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                text: a['allocation_status'] == 'Fully Allocated'
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFD97706),
                                icon: Icons.verified_user_rounded,
                              ),
                            ],
                          ),
                          if (a['allocation_explanation'] != null &&
                              a['allocation_explanation'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              a['allocation_explanation'],
                              style: t(11.5, c: C.sub, h: 1.35),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 2. High-End Vertical Timeline
          DawaSurface(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fulfillment Timeline',
                        style: t(16, w: FontWeight.w800, c: C.text)),
                    Text(
                      'Live Updates',
                      style: t(12, w: FontWeight.w700, c: const Color(0xFF15803D)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                for (int i = 0; i < stages.length; i++) ...[
                  _buildTimelineTile(
                    index: i,
                    title: stages[i].$1,
                    subtitle: stages[i].$2,
                    isCompleted: activeStageIndex > i,
                    isCurrent: activeStageIndex == i,
                    isLast: i == stages.length - 1,
                    timestamp: _findTimestamp(history, stages[i].$1),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Pharmacist Admin Portal Shortcut Callout
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.light,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: C.indigo, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Demo Notice: Pharmacist verification controls are accessible via Profile > Pharmacist Portal.',
                    style: t(12, c: C.indigo, h: 1.4),
                  ),
                ),
                TextButton(
                  onPressed: () => push(context, const PharmacistAdminScreen()),
                  child: Text('Open Portal',
                      style: t(12, w: FontWeight.w700, c: C.purple)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTimelineTile({
    required int index,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    String? timestamp,
  }) {
    Color circleColor = const Color(0xFFE2E8F0);
    Widget centerWidget = Text(
      '${index + 1}',
      style: t(11, w: FontWeight.w700, c: const Color(0xFF64748B)),
    );

    if (isCompleted) {
      circleColor = const Color(0xFF24845A);
      centerWidget = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isCurrent) {
      circleColor = C.purple;
      centerWidget = Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle + Connecting Line
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent ? DawaShadows.purpleGlow : null,
                ),
                child: Center(child: centerWidget),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? const Color(0xFF24845A)
                        : const Color(0xFFE9E6F0),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Title & Description
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: t(
                          14.5,
                          w: isCurrent ? FontWeight.w800 : FontWeight.w600,
                          c: isCurrent ? C.purple : (isCompleted ? C.text : C.sub),
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          timestamp,
                          style: t(11, w: FontWeight.w500, c: C.sub),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: t(12, c: C.sub),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _findTimestamp(List history, String stageTitle) {
    for (final h in history) {
      final s = h['status'] as String? ?? '';
      if (s.toLowerCase().contains(stageTitle.toLowerCase()) ||
          stageTitle.toLowerCase().contains(s.toLowerCase())) {
        final dt = h['created_at'] as String?;
        if (dt != null && dt.length >= 16) {
          return dt.substring(11, 16); // Extract HH:MM
        }
      }
    }
    return null;
  }
}
