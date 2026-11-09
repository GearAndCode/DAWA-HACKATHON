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
          title: const Text('Invoice Rejected'),
          content: const Text(
              'You have declined this quotation. You can select another pharmacy or resubmit your prescription at any time.'),
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
    final total = (widget.invoice['total_amount'] as num?)?.toDouble() ?? subtotal;
    final List items = widget.invoice['items'] ?? [];

    return PageScaffold(
      title: 'Digital Invoice Quotation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Invoice Header Card
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
                        Text('DAWA INVOICE',
                            style: t(12,
                                w: FontWeight.w800,
                                c: C.purple,
                                ls: 1.5)),
                        const SizedBox(height: 2),
                        Text(invNumber,
                            style: t(17,
                                w: FontWeight.w800, c: C.indigo)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'AWAITING APPROVAL',
                        style: t(11,
                            w: FontWeight.w700,
                            c: const Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: C.border),
                Text('Dispensing Pharmacy',
                    style: t(12, c: C.sub, w: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(pharmacyName,
                    style: t(15.5, w: FontWeight.w700, c: C.text)),
                Text(pharmacyAddress,
                    style: t(13, c: C.sub)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Itemized Table
          Text('Prescribed Medicines',
              style: t(17, w: FontWeight.w700, c: C.indigo)),
          const SizedBox(height: 10),
          DawaCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: C.light,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: t(12,
                                  w: FontWeight.w700, c: C.purple)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i]['medicine_name'] ?? 'Medicine',
                              style: t(14.5, w: FontWeight.w600),
                            ),
                            Text(
                              '${items[i]['strength'] ?? 'Standard'} • Qty: ${items[i]['quantity']} @ PKR ${items[i]['unit_price']}',
                              style: t(12, c: C.sub),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'PKR ${items[i]['line_total']}',
                        style: t(14.5, w: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (i < items.length - 1)
                    const Divider(height: 20, color: C.border),
                ],
                const Divider(height: 26, color: C.border),

                // Calculations
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: t(14, c: C.sub)),
                    Text('PKR ${subtotal.toStringAsFixed(0)}',
                        style: t(14, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delivery Fee (Determined at Next Step)',
                        style: t(13, c: C.sub)),
                    Text('PKR 0', style: t(13, c: C.sub)),
                  ],
                ),
                const Divider(height: 20, color: C.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quotation Total',
                        style: t(16, w: FontWeight.w800, c: C.indigo)),
                    Text(
                      'PKR ${total.toStringAsFixed(0)}',
                      style: t(19, w: FontWeight.w800, c: C.purple),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Action Buttons
          FilledButton.icon(
            onPressed: _submitting ? null : _approve,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Approve Invoice & Select Pickup / Delivery'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _reject,
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
            label: const Text('Decline Quotation',
                style: TextStyle(color: Colors.redAccent)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
