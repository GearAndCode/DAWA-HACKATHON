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
  final _instructionsCtrl = TextEditingController();
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
    _instructionsCtrl.dispose();
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
      title: 'Choose Fulfillment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How would you like to receive your medicines?',
            style: t(14, c: C.sub),
          ),
          const SizedBox(height: 18),

          // 1. Pharmacy Storefront Card
          DawaSurface(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: C.light,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store_mall_directory_rounded,
                      color: C.purple, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pharmacyName,
                          style: t(15.5, w: FontWeight.w700, c: C.indigo)),
                      const SizedBox(height: 2),
                      Text(pharmacyAddress,
                          style: t(12.5, c: C.sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Fulfillment Options
          _buildOptionCard(
            type: 'pickup',
            title: 'Pharmacy Pickup',
            subtitle: 'Ready in ~30 mins • Free preparation',
            icon: Icons.storefront_outlined,
            fee: 'Free',
            isSelected: !isDelivery,
            details: _buildPickupDetails(pharmacyAddress),
          ),
          const SizedBox(height: 14),

          _buildOptionCard(
            type: 'delivery',
            title: 'Home Delivery',
            subtitle: 'Standard delivery across Lahore • PKR 150',
            icon: Icons.local_shipping_outlined,
            fee: 'PKR 150',
            isSelected: isDelivery,
            details: _buildDeliveryDetails(),
          ),
          const SizedBox(height: 24),

          // 3. Cost Summary Card
          DawaSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Medicine Subtotal', style: t(13.5, c: C.sub)),
                    Text('PKR ${subtotal.toStringAsFixed(0)}',
                        style: t(14, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fulfillment Fee', style: t(13.5, c: C.sub)),
                    Text(
                      deliveryFee > 0
                          ? 'PKR ${deliveryFee.toStringAsFixed(0)}'
                          : 'FREE',
                      style: t(14,
                          w: FontWeight.w700,
                          c: deliveryFee > 0 ? C.text : const Color(0xFF15803D)),
                    ),
                  ],
                ),
                const Divider(height: 20),
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
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 4. Submit Order Button
          FilledButton.icon(
            onPressed: _creatingOrder ? null : _confirmOrder,
            icon: _creatingOrder
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(_creatingOrder
                ? 'Placing Order...'
                : 'Confirm & Place Order'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required String fee,
    required bool isSelected,
    required Widget details,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFulfillment = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? C.purple : const Color(0xFFE9E6F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected ? DawaShadows.purpleGlow : DawaShadows.card,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? C.purple : C.light,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : C.purple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: t(16, w: FontWeight.w700, c: C.text)),
                      Text(subtitle,
                          style: t(12, c: C.sub)),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? C.purple : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? C.purple : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              details,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPickupDetails(String address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time_rounded, size: 16, color: C.purple),
            const SizedBox(width: 8),
            Text('Ready for pickup today: 9:00 AM – 11:00 PM',
                style: t(12.5, w: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: C.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Collect at: $address',
                  style: t(12.5, c: C.sub)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliveryDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: 'Delivery Address in Lahore',
            hintText: 'House/Flat #, Street, Area',
            prefixIcon: const Icon(Icons.home_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.my_location_rounded, color: C.purple),
              onPressed: () {
                final loc = LocationService.instance.currentLocation.value;
                if (loc != null) {
                  _addressCtrl.text = '${loc.label}, ${loc.address}';
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _instructionsCtrl,
          decoration: const InputDecoration(
            labelText: 'Rider Instructions (Optional)',
            hintText: 'e.g. Ring bell, leave with security guard',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    );
  }
}
