import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/demo_data.dart';
import '../navigation/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _bytes;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 85);
      if (x == null) return;
      final b = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = b;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = source == ImageSource.camera
          ? 'The camera is not available here. Please choose an image from your gallery instead.'
          : 'Could not open your files. Please try again.');
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const IconChip(Icons.photo_camera_outlined),
              title: Text('Take a photo', style: t(16, w: FontWeight.w600)),
              onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera); },
            ),
            ListTile(
              leading: const IconChip(Icons.photo_library_outlined),
              title: Text('Choose from gallery or files', style: t(16, w: FontWeight.w600)),
              onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery); },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Upload Prescription',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_bytes == null) _empty() else _preview(),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(14)),
            child: Text(_error!, style: t(13.5, c: const Color(0xFF9B1C1C))),
          ),
        ],
        const SizedBox(height: 20),
        _tips(),
      ]),
    );
  }

  Widget _empty() => DawaCard(
        color: C.light,
        padding: const EdgeInsets.all(26),
        shadow: false,
        child: Column(children: [
          const IconChip(Icons.upload_file_rounded, size: 72, bg: Colors.white),
          const SizedBox(height: 18),
          Text('Add your prescription', style: t(20, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Take a photo or choose a file from your device.',
              textAlign: TextAlign.center, style: t(14, c: C.sub)),
          const SizedBox(height: 22),
          FilledButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take a Photo')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery')),
        ]),
      );

  Widget _preview() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.border),
            boxShadow: softShadow,
          ),
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(_bytes!, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: _chooseSource,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Replace'))),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => setState(() => _bytes = null),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'))),
        ]),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: () => push(context, ReviewScreen(bytes: _bytes!)),
            child: const Text('Continue')),
      ]);

  Widget _tips() => DawaCard(
        shadow: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('For a clear upload', style: t(15, w: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final s in const [
            'Place the prescription on a flat, well-lit surface.',
            'Keep all text sharp and fully inside the frame.',
            'Do not cover the doctor details or medicine list.',
          ])
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_outline_rounded, size: 18, color: C.green)),
                const SizedBox(width: 8),
                Expanded(child: Text(s, style: t(13.5, c: C.sub))),
              ]),
            ),
        ]),
      );
}

class ReviewScreen extends StatefulWidget {
  final Uint8List bytes;
  const ReviewScreen({super.key, required this.bytes});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final List<TextEditingController> _ctrls = [TextEditingController()];

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final items = _ctrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter at least one medicine from your prescription.')));
      return;
    }
    prescriptionRecords.value = [
      PrescriptionRecord(DateTime.now(), widget.bytes, items),
      ...prescriptionRecords.value,
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Saved in demo mode'),
        content: const Text(
            'Your prescription details were saved on this device only. Nothing was sent to a pharmacy. '
            'In a live service, a qualified pharmacist would review the prescription before any approval.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Review Prescription',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: C.purple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  'DAWA has not read your prescription automatically. Please type the medicines exactly as written. '
                  'A qualified pharmacist must verify prescription orders, and unclear details will need human review.',
                  style: t(13.5, c: C.indigo)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(widget.bytes, width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Your uploaded prescription', style: t(15, w: FontWeight.w600))),
        ]),
        const SizedBox(height: 18),
        Text('Medicines', style: t(17, w: FontWeight.w700)),
        const SizedBox(height: 10),
        for (int i = 0; i < _ctrls.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrls[i],
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Medicine name, strength, quantity',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.purple, width: 1.5)),
                  ),
                ),
              ),
              if (_ctrls.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    _ctrls.removeAt(i).dispose();
                  }),
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: C.sub),
                ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _ctrls.add(TextEditingController())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add another medicine'),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: _submit, child: const Text('Save for Pharmacist Review (Demo)')),
      ]),
    );
  }
}
