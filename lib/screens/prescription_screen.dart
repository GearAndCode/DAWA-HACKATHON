import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'extracted_medicine_review_screen.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _bytes;
  String? _filename;
  String? _error;
  bool _uploading = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        imageQuality: 90,
      );
      if (x == null) return;
      final b = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = b;
        _filename = x.name;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = source == ImageSource.camera
          ? 'The camera is not available. Please choose an image from your gallery.'
          : 'Could not access file. Please try again.');
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const IconChip(Icons.photo_camera_outlined),
                title: Text('Take a photo', style: t(16, w: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const IconChip(Icons.photo_library_outlined),
                title: Text('Choose from gallery or files',
                    style: t(16, w: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pick(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPrescription() async {
    if (_bytes == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final fn = _filename ?? 'prescription_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final res = await ApiService.instance.uploadPrescription(_bytes!, fn);

      if (!mounted) return;
      setState(() => _uploading = false);

      final prescriptionId = res['prescription_id'] as int;
      final patient = res['patient'] as Map<String, dynamic>? ?? {};
      final doctor = res['doctor'] as Map<String, dynamic>? ?? {};
      final List rawMeds = res['medicines'] ?? [];
      final List rawWarnings = res['warnings'] ?? [];

      push(
        context,
        ExtractedMedicineReviewScreen(
          prescriptionId: prescriptionId,
          imageBytes: _bytes!,
          patientName: patient['name'] as String?,
          patientAge: patient['age'] as String?,
          doctorName: doctor['name'] as String?,
          prescriptionDate: patient['date'] as String?,
          initialMedicines: rawMeds.cast<Map<String, dynamic>>(),
          warnings: rawWarnings.cast<String>(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Failed to process prescription: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Upload Prescription',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bytes == null) _empty() else _preview(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!,
                        style: t(13.5, c: const Color(0xFF991B1B))),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _guidance(),
          const SizedBox(height: 16),
          _safetyCallout(),
        ],
      ),
    );
  }

  Widget _empty() => DawaCard(
        color: C.light,
        padding: const EdgeInsets.all(28),
        shadow: false,
        child: Column(
          children: [
            const IconChip(Icons.document_scanner_outlined,
                size: 68, bg: Colors.white),
            const SizedBox(height: 16),
            Text('Scan Prescription',
                style: t(20, w: FontWeight.w800, c: C.indigo)),
            const SizedBox(height: 8),
            Text(
              'Upload a prescription photo to identify medicines and check pharmacy stock across Lahore.',
              textAlign: TextAlign.center,
              style: t(14, c: C.sub, h: 1.5),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take a Photo'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
          ],
        ),
      );

  Widget _preview() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.border),
              boxShadow: softShadow,
            ),
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _chooseSource,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Replace Image'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => setState(() {
                            _bytes = null;
                            _filename = null;
                          }),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _uploading ? null : _processPrescription,
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(_uploading
                ? 'Processing Prescription...'
                : 'Read Prescription Details'),
          ),
        ],
      );

  Widget _guidance() => DawaCard(
        shadow: false,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: C.purple, size: 20),
                const SizedBox(width: 8),
                Text('Prescription photo tips',
                    style: t(15, w: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            for (final s in const [
              'Place prescription on a flat surface with good lighting.',
              'Ensure medicine names, strengths, and doctor signature are clear.',
              'Avoid heavy shadows, reflections, or steep angles.',
            ])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: C.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: t(13.5, c: C.sub))),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _safetyCallout() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.light,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined,
                color: C.indigo, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Healthcare Notice: Prescriptions are automatically read for your convenience. All orders are reviewed and verified by a licensed pharmacist before dispensing.',
                style: t(12.5, c: C.indigo, h: 1.4),
              ),
            ),
          ],
        ),
      );
}
