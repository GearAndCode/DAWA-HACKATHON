import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pharmacist_admin_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Map<String, dynamic> _currentOrder;
  Timer? _pollingTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    // Auto-poll order updates from backend every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshOrder());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    final orderId = _currentOrder['id'] as int;
    try {
      final updated = await ApiService.instance.getOrderDetails(orderId);
      if (mounted) {
        setState(() => _currentOrder = updated);
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
    final orderNumber = _currentOrder['order_number'] ?? 'DAWA-2026-0001';
    final status = _currentOrder['status'] ?? 'Order Placed';
    final fulfillmentType = _currentOrder['fulfillment_type'] ?? 'pickup';
    final isPickup = fulfillmentType == 'pickup';
    final totalAmount = (_currentOrder['total_amount'] as num?)?.toDouble() ?? 0.0;
    final pharmacyName = _currentOrder['pharmacy_name'] ?? 'DAWA Pharmacy';
    final pharmacyAddress = _currentOrder['pharmacy_address'] ?? 'Lahore';
    final deliveryAddress = _currentOrder['delivery_address'];
    final isRejected = status.contains('Rejected');
    final activeStageIndex = _getStageIndex(status, isPickup);

    return PageScaffold(
      title: 'Order Status Tracking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order Header Card
          DawaCard(
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
                        Text('ORDER NUMBER',
                            style: t(11.5,
                                w: FontWeight.w800,
                                c: C.purple,
                                ls: 1.5)),
                        const SizedBox(height: 2),
                        Text(orderNumber,
                            style: t(18,
                                w: FontWeight.w800, c: C.indigo)),
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
                      onPressed: () async {
                        setState(() => _isRefreshing = true);
                        await _refreshOrder();
                        if (mounted) setState(() => _isRefreshing = false);
                      },
                    ),
                  ],
                ),
                const Divider(height: 22, color: C.border),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isRejected
                            ? const Color(0xFFFEE2E2)
                            : (status.contains('Delivered') || status.contains('Collected')
                                ? const Color(0xFFDCFCE7)
                                : C.light),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: t(11.5,
                            w: FontWeight.w700,
                            c: isRejected
                                ? const Color(0xFFDC2626)
                                : (status.contains('Delivered') || status.contains('Collected')
                                    ? const Color(0xFF15803D)
                                    : C.purple)),
                      ),
                    ),
                    const Spacer(),
                    Text('PKR ${totalAmount.toStringAsFixed(0)}',
                        style: t(17, w: FontWeight.w800, c: C.indigo)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Pharmacist Demo Action Switcher for Judges & Reviewers
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF312E81), Color(0xFF4C1D95)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pharmacist Demo Portal',
                          style: t(14,
                              w: FontWeight.w700, c: Colors.white)),
                      Text(
                        'Review, verify, and update order statuses as the licensed pharmacist.',
                        style: t(11.5, c: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: C.purple,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () {
                    push(
                      context,
                      PharmacistAdminScreen(highlightOrderId: _currentOrder['id']),
                    );
                  },
                  child: const Text('Open Admin',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tracking Timeline
          Text('Order Progress Timeline',
              style: t(17, w: FontWeight.w800, c: C.indigo)),
          const SizedBox(height: 12),

          DawaCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildTimelineStep(
                  stepIndex: 0,
                  title: 'Order Placed',
                  description: 'Prescription received and registered in DAWA system.',
                  activeStageIndex: activeStageIndex,
                  isRejected: isRejected,
                ),
                _buildTimelineStep(
                  stepIndex: 1,
                  title: 'Awaiting Pharmacist Verification',
                  description: 'A licensed pharmacist is reviewing prescription legality and dosages.',
                  activeStageIndex: activeStageIndex,
                  isRejected: isRejected,
                ),
                _buildTimelineStep(
                  stepIndex: 2,
                  title: 'Verified by Pharmacist',
                  description: 'Prescription clinically verified and medicines approved for dispensing.',
                  activeStageIndex: activeStageIndex,
                  isRejected: isRejected,
                ),
                _buildTimelineStep(
                  stepIndex: 3,
                  title: 'Preparing Order',
                  description: 'Pharmacy staff is packaging and labelling your prescribed medicines.',
                  activeStageIndex: activeStageIndex,
                  isRejected: isRejected,
                ),
                _buildTimelineStep(
                  stepIndex: 4,
                  title: isPickup ? 'Ready for Pickup' : 'Out for Delivery',
                  description: isPickup
                      ? 'Packaged and waiting at $pharmacyName counter.'
                      : 'Handed over to delivery courier for transit.',
                  activeStageIndex: activeStageIndex,
                  isRejected: isRejected,
                ),
                _buildTimelineStep(
                  stepIndex: 5,
                  title: isPickup ? 'Collected' : 'Delivered',
                  description: isPickup
                      ? 'Medicines collected by patient from pharmacy.'
                      : 'Delivered securely to your designated address.',
                  activeStageIndex: activeStageIndex,
                  isRejected: isRejected,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Fulfillment Details Card
          DawaCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPickup ? 'Pharmacy Pickup Location' : 'Home Delivery Destination',
                  style: t(14.5, w: FontWeight.w700, c: C.indigo),
                ),
                const SizedBox(height: 6),
                Text(
                  isPickup ? pharmacyName : 'Patient Address',
                  style: t(14, w: FontWeight.w600),
                ),
                Text(
                  isPickup ? pharmacyAddress : (deliveryAddress ?? 'Gulberg III, Lahore'),
                  style: t(13, c: C.sub),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pharmacist Verification Notes if any
          if (_currentOrder['pharmacist_notes'] != null &&
              (_currentOrder['pharmacist_notes'] as String).isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.light,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_information_outlined,
                      color: C.purple, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Licensed Pharmacist Notes',
                            style: t(13, w: FontWeight.w700, c: C.purple)),
                        const SizedBox(height: 2),
                        Text(
                          _currentOrder['pharmacist_notes'],
                          style: t(12.5, c: C.indigo),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Return to Home'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required int stepIndex,
    required String title,
    required String description,
    required int activeStageIndex,
    required bool isRejected,
    bool isLast = false,
  }) {
    final bool isCompleted = !isRejected && stepIndex < activeStageIndex;
    final bool isCurrent = !isRejected && stepIndex == activeStageIndex;

    Color circleColor = C.border;
    Widget centerWidget = Text(
      '${stepIndex + 1}',
      style: t(12, w: FontWeight.w600, c: C.sub),
    );

    if (isCompleted) {
      circleColor = C.green;
      centerWidget = const Icon(Icons.check_rounded, color: Colors.white, size: 16);
    } else if (isCurrent) {
      circleColor = C.purple;
      centerWidget = Text(
        '${stepIndex + 1}',
        style: t(12, w: FontWeight.w700, c: Colors.white),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Icon & Vertical Line
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                              color: C.purple.withValues(alpha: 0.35),
                              blurRadius: 8,
                              spreadRadius: 2)
                        ]
                      : null,
                ),
                child: Center(child: centerWidget),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? C.green : C.border,
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
                  Text(
                    title,
                    style: t(14.5,
                        w: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        c: isCurrent ? C.purple : (isCompleted ? C.text : C.sub)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: t(12.5, c: C.sub, h: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
