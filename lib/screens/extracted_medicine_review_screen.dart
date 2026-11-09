import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pharmacy_matching_screen.dart';

class ExtractedMedicineReviewScreen extends StatefulWidget {
  final int prescriptionId;
  final Uint8List imageBytes;
  final String ocrRawText;
  final double ocrConfidence;
  final bool isUncertain;
  final String? uncertaintyReason;
  final List<Map<String, dynamic>> initialItems;

  const ExtractedMedicineReviewScreen({
    super.key,
    required this.prescriptionId,
    required this.imageBytes,
    required this.ocrRawText,
    required this.ocrConfidence,
    required this.isUncertain,
    this.uncertaintyReason,
    required this.initialItems,
  });

  @override
  State<ExtractedMedicineReviewScreen> createState() =>
      _ExtractedMedicineReviewScreenState();
}

class _MedicineItemForm {
  final TextEditingController nameCtrl;
  final TextEditingController strengthCtrl;
  final TextEditingController formCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController instructionsCtrl;

  _MedicineItemForm({
    required String name,
    required String strength,
    required String form,
    required int qty,
    required String instructions,
  })  : nameCtrl = TextEditingController(text: name),
        strengthCtrl = TextEditingController(text: strength),
        formCtrl = TextEditingController(text: form),
        qtyCtrl = TextEditingController(text: qty.toString()),
        instructionsCtrl = TextEditingController(text: instructions);

  void dispose() {
    nameCtrl.dispose();
    strengthCtrl.dispose();
    formCtrl.dispose();
    qtyCtrl.dispose();
    instructionsCtrl.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_name': nameCtrl.text.trim(),
      'strength': strengthCtrl.text.trim(),
      'dosage_form': formCtrl.text.trim(),
      'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 1,
      'instructions': instructionsCtrl.text.trim(),
      'confidence': 1.0,
    };
  }
}

class _ExtractedMedicineReviewScreenState
    extends State<ExtractedMedicineReviewScreen> {
  final List<_MedicineItemForm> _forms = [];
  bool _submitting = false;
  bool _showRawOcr = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems.isNotEmpty) {
      for (final item in widget.initialItems) {
        _forms.add(_MedicineItemForm(
          name: item['medicine_name'] ?? '',
          strength: item['strength'] ?? '500 mg',
          form: item['dosage_form'] ?? 'Tablet',
          qty: item['quantity'] is int ? item['quantity'] : 10,
          instructions: item['instructions'] ?? 'Take after meals',
        ));
      }
    } else {
      _forms.add(_MedicineItemForm(
        name: 'Panadol',
        strength: '500 mg',
        form: 'Tablet',
        qty: 10,
        instructions: '1 tablet twice daily',
      ));
    }
  }

  @override
  void dispose() {
    for (final f in _forms) {
      f.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _forms.add(_MedicineItemForm(
        name: '',
        strength: '500 mg',
        form: 'Tablet',
        qty: 10,
        instructions: 'As directed',
      ));
    });
  }

  void _removeItem(int index) {
    if (_forms.length <= 1) return;
    setState(() {
      _forms.removeAt(index).dispose();
    });
  }

  Future<void> _confirmAndMatch() async {
    final validItems = _forms
        .map((f) => f.toJson())
        .where((m) => (m['medicine_name'] as String).isNotEmpty)
        .toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify at least one valid medicine name.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final loc = LocationService.instance.currentLocation.value;
      final lat = loc?.latitude ?? 31.5204;
      final lon = loc?.longitude ?? 74.3587;

      final res = await ApiService.instance.confirmPrescriptionAndMatch(
        prescriptionId: widget.prescriptionId,
        items: validItems,
        lat: lat,
        lon: lon,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      final List matchingPharmacies = res['matching_pharmacies'] ?? [];

      push(
        context,
        PharmacyMatchingScreen(
          prescriptionId: widget.prescriptionId,
          confirmedItems: validItems,
          matchingPharmacies: matchingPharmacies.cast<Map<String, dynamic>>(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error matching pharmacies: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Review Extracted Medicines',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prescription Image & OCR Confidence Badge
          DawaCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    widget.imageBytes,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Prescription OCR Scan',
                          style: t(15.5, w: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.isUncertain
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Confidence: ${(widget.ocrConfidence * 100).toInt()}%',
                              style: t(11.5,
                                  w: FontWeight.w700,
                                  c: widget.isUncertain
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF15803D)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero),
                            onPressed: () {
                              setState(() => _showRawOcr = !_showRawOcr);
                            },
                            child: Text(
                              _showRawOcr ? 'Hide raw OCR' : 'View raw OCR',
                              style: t(12,
                                  w: FontWeight.w600, c: C.purple),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_showRawOcr) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.ocrRawText.isEmpty
                    ? '(No OCR text extracted)'
                    : widget.ocrRawText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFE5E7EB),
                ),
              ),
            ),
          ],

          if (widget.isUncertain) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.uncertaintyReason ??
                          'Prescription handwriting or text is partially unclear. Please verify and correct fields below.',
                      style: t(13, c: const Color(0xFF92400E), h: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Detected Medicines',
                  style: t(18, w: FontWeight.w800, c: C.indigo)),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Add Medicine'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          for (int i = 0; i < _forms.length; i++)
            _buildMedicineCard(i, _forms[i]),

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.light,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: C.purple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Safety Notice: A licensed pharmacist will verify this prescription prior to dispensing.',
                    style: t(12, c: C.indigo),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _submitting ? null : _confirmAndMatch,
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(_submitting
                ? 'Searching Pharmacy Inventories...'
                : 'Confirm & Find Available Pharmacies'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(int index, _MedicineItemForm form) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DawaCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: C.purple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: t(13, w: FontWeight.w700, c: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Medicine #${index + 1}',
                    style: t(15, w: FontWeight.w700)),
                const Spacer(),
                if (_forms.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    onPressed: () => _removeItem(index),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: form.nameCtrl,
              decoration: InputDecoration(
                labelText: 'Medicine Name',
                hintText: 'e.g. Panadol, Augmentin',
                filled: true,
                fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: C.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: form.strengthCtrl,
                    decoration: InputDecoration(
                      labelText: 'Strength',
                      hintText: '500 mg',
                      filled: true,
                      fillColor: C.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: C.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: form.formCtrl,
                    decoration: InputDecoration(
                      labelText: 'Dosage Form',
                      hintText: 'Tablet / Syrup',
                      filled: true,
                      fillColor: C.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: C.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: form.qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      filled: true,
                      fillColor: C.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: C.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: form.instructionsCtrl,
              decoration: InputDecoration(
                labelText: 'Instructions / Frequency',
                hintText: 'e.g. 1 tablet twice daily after meals',
                filled: true,
                fillColor: C.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: C.border),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
