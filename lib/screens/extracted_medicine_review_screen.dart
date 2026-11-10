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
  final String? patientName;
  final String? patientAge;
  final String? doctorName;
  final String? prescriptionDate;
  final List<Map<String, dynamic>> initialMedicines;
  final List<String> warnings;

  const ExtractedMedicineReviewScreen({
    super.key,
    required this.prescriptionId,
    required this.imageBytes,
    this.patientName,
    this.patientAge,
    this.doctorName,
    this.prescriptionDate,
    required this.initialMedicines,
    this.warnings = const [],
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
  final String fieldStatus;

  _MedicineItemForm({
    required String name,
    required String strength,
    required String form,
    required int qty,
    required String instructions,
    this.fieldStatus = 'verified_from_image',
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

  @override
  void initState() {
    super.initState();
    // Populate form ONLY with medicines genuinely returned by the backend
    for (final m in widget.initialMedicines) {
      final name = (m['original_name'] ?? m['medicine_name'] ?? '') as String;
      final strength = (m['strength'] ?? '') as String;
      final form = (m['dosage_form'] ?? 'Tablet') as String;
      final qty = m['quantity'] is int ? m['quantity'] as int : 10;
      final instructions = (m['instructions'] ?? 'As directed by physician') as String;
      final status = (m['field_status'] ?? 'verified_from_image') as String;

      _forms.add(_MedicineItemForm(
        name: name,
        strength: strength,
        form: form,
        qty: qty,
        instructions: instructions,
        fieldStatus: status,
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
        strength: '',
        form: 'Tablet',
        qty: 10,
        instructions: 'As directed',
        fieldStatus: 'manually_entered',
      ));
    });
  }

  void _removeItem(int index) {
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
          content: Text('Please add at least one medicine before searching pharmacies.'),
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
      title: 'Prescription Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtitle
          Text(
            'Review the medicines identified in your prescription.',
            style: t(14, c: C.sub),
          ),
          const SizedBox(height: 14),

          // 1. Prescription Preview Card
          DawaCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    widget.imageBytes,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Uploaded Prescription',
                          style: t(15.5, w: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (widget.doctorName != null && widget.doctorName!.isNotEmpty)
                        Text(widget.doctorName!,
                            style: t(13, w: FontWeight.w600, c: C.indigo)),
                      if (widget.patientName != null && widget.patientName!.isNotEmpty)
                        Text('Patient: ${widget.patientName!}',
                            style: t(12.5, c: C.sub)),
                      if (widget.prescriptionDate != null && widget.prescriptionDate!.isNotEmpty)
                        Text('Date: ${widget.prescriptionDate!}',
                            style: t(11.5, c: C.sub)),
                      if ((widget.doctorName == null || widget.doctorName!.isEmpty) &&
                          (widget.patientName == null || widget.patientName!.isEmpty))
                        Text(
                          '${_forms.length} ${_forms.length == 1 ? "medicine" : "medicines"} identified',
                          style: t(12.5, c: C.sub),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Warnings or Alerts if present
          if (widget.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final warn in widget.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          warn,
                          style: t(12.5, c: const Color(0xFF92400E), h: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: 18),

          // 3. Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Medicines (${_forms.length})',
                  style: t(17, w: FontWeight.w800)),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Add Medicine'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. Empty State if no medicines identified
          if (_forms.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: C.light,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.medication_outlined,
                      size: 44, color: C.purple),
                  const SizedBox(height: 12),
                  Text('No medicines recognized',
                      style: t(16, w: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'No readable medicine entries were found on this prescription image. You can manually add your medicines below to find pharmacies, or retake a clearer photo.',
                    textAlign: TextAlign.center,
                    style: t(13, c: C.sub, h: 1.4),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Medicine Manually'),
                  ),
                ],
              ),
            ),
          ],

          // 5. Medicine Edit Cards
          for (int i = 0; i < _forms.length; i++) ...[
            _buildMedicineCard(i),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 20),

          // 6. Action Buttons
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
                : 'Confirm Medicines & Find Available Pharmacies'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Rescan Prescription'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(int index) {
    final form = _forms[index];
    final isManual = form.fieldStatus == 'manually_entered';

    return DawaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isManual ? const Color(0xFFF1F5F9) : C.light,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: t(14,
                        w: FontWeight.w700,
                        c: isManual ? const Color(0xFF475569) : C.purple),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text('Medicine #${index + 1}',
                        style: t(14.5, w: FontWeight.w700)),
                    if (isManual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Manual',
                            style: t(10.5, w: FontWeight.w600, c: const Color(0xFF64748B))),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: Color(0xFFEF4444)),
                onPressed: () => _removeItem(index),
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name Field
          TextField(
            controller: form.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Medicine Name',
              hintText: 'e.g. Augmentin, Panadol, Brufen',
              prefixIcon: Icon(Icons.medication_liquid_outlined),
            ),
          ),
          const SizedBox(height: 10),

          // Strength & Dosage Form
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: form.strengthCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Strength',
                    hintText: 'e.g. 500 mg, 625 mg',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: form.formCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Form',
                    hintText: 'Tablet, Syrup, Capsule',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quantity & Instructions
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: form.qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: form.instructionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions / Frequency',
                    hintText: 'e.g. 1 tablet twice daily after meals',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
