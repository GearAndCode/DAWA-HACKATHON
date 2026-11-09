import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'fulfillment_selection_screen.dart';

class InvoiceApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final int prescriptionId;

  const InvoiceApprovalScreen({
    super.key,
    required this.invoice,
    required this.prescriptionId,
  });

  @override
  State<InvoiceApprovalScreen> createState() => _InvoiceApprovalScreenState();
}

class _InvoiceApprovalScreenState extends State<InvoiceApprovalScreen> {
  bool _submitting = false;

  Future<void> _approve() async {
    final invoiceId = widget.invoice['id'] as int;
    setState(() => _submitting = true);

    try {
      final updatedInvoice = await ApiService.instance.submitInvoiceDecision(
        invoiceId,
        approved: true,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      push(
        context,
        FulfillmentSelectionScreen(
          invoice: updatedInvoice,
          prescriptionId: widget.prescriptionId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving invoice: $e')),
      );
    }
  }

  Future<void> _reject() async {
    final invoiceId = widget.invoice['id'] as int;
    setState(() => _submitting = true);

    try {
      await ApiService.instance.submitInvoiceDecision(
        invoiceId,
        approved: false,
        reason: 'Patient cancelled invoice.',
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Invoice Cancelled'),
          content: const Text(
              'You have declined this quotation. You can select another pharmacy or rescan your prescription at any time.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('Return to Home'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting invoice: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invNumber = widget.invoice['invoice_number'] ?? 'INV-2026-0000';
    final pharmacyName = widget.invoice['pharmacy_name'] ?? 'DAWA Pharmacy';
    final pharmacyAddress = widget.invoice['pharmacy_address'] ?? 'Lahore';
    final subtotal = (widget.invoice['subtotal'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (widget.invoice['grand_total'] as num?)?.toDouble() ?? subtotal;
    final List items = widget.invoice['items'] ?? [];

    return PageScaffold(
      title: 'Order Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review itemized prices calculated directly by the pharmacy inventory.',
            style: t(14, c: C.sub),
          ),
          const SizedBox(height: 16),

          // 1. Invoice Meta Header Card
          DawaSurface(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: C.light,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: C.purple, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pharmacyName,
                          style: t(16, w: FontWeight.w800, c: C.indigo)),
                      const SizedBox(height: 2),
                      Text(pharmacyAddress,
                          style: t(12.5, c: C.sub)),
                      const SizedBox(height: 4),
                      Text(
                        'Ref: $invNumber',
                        style: t(11.5, w: FontWeight.w600, c: C.purple),
                      ),
                    ],
                  ),
                ),
                const DawaBadge(
                  label: 'Quotation',
                  bg: Color(0xFFDCFCE7),
                  text: Color(0xFF15803D),
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Itemized Medicines Table
          DawaSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prescription Items',
                    style: t(15.5, w: FontWeight.w800, c: C.text)),
                const SizedBox(height: 14),
                for (int i = 0; i < items.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: t(12, w: FontWeight.w700, c: const Color(0xFF475569)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i]['medicine_name'] ?? 'Medicine',
                              style: t(14.5, w: FontWeight.w700),
                            ),
                            Text(
                              '${items[i]['strength'] ?? ''} • Qty: ${items[i]['quantity'] ?? 1} x PKR ${items[i]['unit_price'] ?? 0}',
                              style: t(12, c: C.sub),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'PKR ${items[i]['subtotal'] ?? 0}',
                        style: t(14.5, w: FontWeight.w700, c: C.text),
                      ),
                    ],
                  ),
                  if (i < items.length - 1) const Divider(height: 20),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Fintech-Level Grand Total Card with Ambient Glow
          DawaSurface(
            hasGlow: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Medicine Subtotal', style: t(14, c: C.sub)),
                    Text('PKR ${subtotal.toStringAsFixed(0)}',
                        style: t(15, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fulfillment (Calculated Next Step)',
                        style: t(13, c: C.sub)),
                    Text('From PKR 0', style: t(13, w: FontWeight.w600)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimated Total',
                            style: t(16.5, w: FontWeight.w800, c: C.indigo)),
                        Text('PKR Currency', style: t(11.5, c: C.sub)),
                      ],
                    ),
                    Text(
                      'PKR ${grandTotal.toStringAsFixed(0)}',
                      style: t(22, w: FontWeight.w900, c: C.purple, ls: -0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Action Buttons
          FilledButton.icon(
            onPressed: _submitting ? null : _approve,
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(_submitting
                ? 'Processing...'
                : 'Approve & Choose Delivery / Pickup'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _submitting ? null : _reject,
            child: const Text('Decline Quotation'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
