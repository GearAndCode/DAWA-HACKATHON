import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'order_tracking_screen.dart';

class FulfillmentSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final int prescriptionId;

  const FulfillmentSelectionScreen({
    super.key,
    required this.invoice,
    required this.prescriptionId,
  });

  @override
  State<FulfillmentSelectionScreen> createState() =>
      _FulfillmentSelectionScreenState();
}

class _FulfillmentSelectionScreenState
    extends State<FulfillmentSelectionScreen> {
  String _selectedFulfillment = 'pickup'; // 'pickup' or 'delivery'
  late final TextEditingController _addressCtrl;
  bool _creatingOrder = false;

  @override
  void initState() {
    super.initState();
    final loc = LocationService.instance.currentLocation.value;
    final defaultAddr = loc != null
        ? '${loc.label}, ${loc.address}'
        : 'Gulberg III, Main Boulevard, Lahore';
    _addressCtrl = TextEditingController(text: defaultAddr);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmOrder() async {
    final invoiceId = widget.invoice['id'] as int;
    final isDelivery = _selectedFulfillment == 'delivery';

    if (isDelivery && _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your delivery address.')),
      );
      return;
    }

    setState(() => _creatingOrder = true);

    try {
      final loc = LocationService.instance.currentLocation.value;
      final lat = loc?.latitude;
      final lon = loc?.longitude;

      final order = await ApiService.instance.createOrder(
        invoiceId: invoiceId,
        fulfillmentType: _selectedFulfillment,
        deliveryAddress: isDelivery ? _addressCtrl.text.trim() : null,
        lat: lat,
        lon: lon,
        paymentMethod: isDelivery
            ? 'Cash on Delivery (Demo)'
            : 'Pay at Pharmacy Pickup Counter (Demo)',
      );

      if (!mounted) return;
      setState(() => _creatingOrder = false);

      push(
        context,
        OrderTrackingScreen(order: order),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creatingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = (widget.invoice['subtotal'] as num?)?.toDouble() ?? 0.0;
    final isDelivery = _selectedFulfillment == 'delivery';
    final deliveryFee = isDelivery ? 150.0 : 0.0;
    final finalTotal = subtotal + deliveryFee;

    final pharmacyName = widget.invoice['pharmacy_name'] ?? 'DAWA Pharmacy';
    final pharmacyAddress = widget.invoice['pharmacy_address'] ?? 'Lahore';

    return PageScaffold(
      title: 'Fulfillment & Delivery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How Would You Like to Receive Your Medicines?',
            style: t(20, w: FontWeight.w800, c: C.indigo),
          ),
          const SizedBox(height: 6),
          Text(
            'Select whether you want to collect your medicines in person or have them delivered to your doorstep.',
            style: t(13.5, c: C.sub),
          ),
          const SizedBox(height: 20),

          // Choice 1: Pharmacy Pickup
          _buildFulfillmentOption(
            type: 'pickup',
            title: 'Pharmacy Pickup',
            subtitle: 'Free • Ready in ~30 minutes',
            icon: Icons.storefront_rounded,
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text('Collection Point:',
                    style: t(12, w: FontWeight.w600, c: C.sub)),
                Text(pharmacyName,
                    style: t(14.5, w: FontWeight.w700, c: C.text)),
                Text(pharmacyAddress,
                    style: t(12.5, c: C.sub)),
                const SizedBox(height: 8),
                Text(
                  'Instructions: Show your unique order number at the dispensing counter. A pharmacist will review original prescription.',
                  style: t(12, c: C.purple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Choice 2: Home Delivery
          _buildFulfillmentOption(
            type: 'delivery',
            title: 'Express Home Delivery',
            subtitle: 'Fee: PKR 150 • Estimated 45–60 mins',
            icon: Icons.delivery_dining_rounded,
            details: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text('Delivery Destination:',
                    style: t(12, w: FontWeight.w600, c: C.sub)),
                const SizedBox(height: 4),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    hintText: 'Enter complete street address, house #',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: C.border),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estimated Window: Today, within 45 to 60 minutes.',
                  style: t(12, c: C.purple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Cost Summary Card
          DawaCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Medicine Subtotal', style: t(13.5, c: C.sub)),
                    Text('PKR ${subtotal.toStringAsFixed(0)}',
                        style: t(13.5, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDelivery ? 'Delivery Fee' : 'Pickup Fee',
                      style: t(13.5, c: C.sub),
                    ),
                    Text(
                      isDelivery ? 'PKR 150' : 'FREE',
                      style: t(13.5,
                          w: FontWeight.w700,
                          c: isDelivery ? C.text : C.green),
                    ),
                  ],
                ),
                const Divider(height: 20, color: C.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Final Total',
                        style: t(16, w: FontWeight.w800, c: C.indigo)),
                    Text(
                      'PKR ${finalTotal.toStringAsFixed(0)}',
                      style: t(19, w: FontWeight.w800, c: C.purple),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isDelivery
                      ? 'Payment Method: Cash on Delivery (Demo confirmation)'
                      : 'Payment Method: Pay at Pharmacy Counter (Demo confirmation)',
                  style: t(11.5, c: C.sub),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          FilledButton.icon(
            onPressed: _creatingOrder ? null : _confirmOrder,
            icon: _creatingOrder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(_creatingOrder
                ? 'Placing Order...'
                : 'Confirm & Place Order'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFulfillmentOption({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget details,
  }) {
    final isSelected = _selectedFulfillment == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedFulfillment = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? C.light : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? C.purple : C.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconChip(icon,
                    bg: isSelected ? Colors.white : C.light,
                    fg: isSelected ? C.purple : C.indigo),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: t(16, w: FontWeight.w700, c: C.text)),
                      Text(subtitle,
                          style: t(12.5, c: C.sub)),
                    ],
                  ),
                ),
                Radio<String>(
                  value: type,
                  groupValue: _selectedFulfillment,
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedFulfillment = v);
                  },
                  activeColor: C.purple,
                ),
              ],
            ),
            if (isSelected) details,
          ],
        ),
      ),
    );
  }
}
