import 'package:flutter/material.dart';
import 'package:dawa/theme/app_theme.dart';
import 'package:dawa/widgets/common.dart';
import 'package:dawa/services/api_service.dart';
import 'package:dawa/services/location_service.dart';
import 'package:dawa/screens/pharmacy_matching_screen.dart';
import 'package:dawa/navigation/nav.dart';

class PatientUrgencyAssessmentScreen extends StatefulWidget {
  final int prescriptionId;
  final List<Map<String, dynamic>> confirmedItems;
  final List<Map<String, dynamic>>? preloadedPharmacies;

  const PatientUrgencyAssessmentScreen({
    super.key,
    required this.prescriptionId,
    required this.confirmedItems,
    this.preloadedPharmacies,
  });

  @override
  State<PatientUrgencyAssessmentScreen> createState() =>
      _PatientUrgencyAssessmentScreenState();
}

class _MedicineAssessmentState {
  final String medicineName;
  final String? strength;
  final int? itemId;

  String hasRunOut = 'completely_out';
  String requestedTimeframe = 'asap';
  String treatmentStatus = 'ongoing';
  String nextDoseTimeframe = 'today';
  String alternativeAvailable = 'no';
  bool alternativeVerified = false;
  final TextEditingController notesCtrl = TextEditingController();

  _MedicineAssessmentState({
    required this.medicineName,
    this.strength,
    this.itemId,
  });

  Map<String, dynamic> toJson(int prescriptionId) => {
        'prescription_id': prescriptionId,
        'prescription_item_id': itemId,
        'medicine_name': medicineName,
        'has_run_out': hasRunOut,
        'requested_timeframe': requestedTimeframe,
        'treatment_status': treatmentStatus,
        'next_dose_timeframe': nextDoseTimeframe,
        'alternative_pharmacy_available': alternativeAvailable,
        'alternative_availability_verified': alternativeVerified,
        'additional_information':
            notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      };

  void dispose() {
    notesCtrl.dispose();
  }
}

class _PatientUrgencyAssessmentScreenState
    extends State<PatientUrgencyAssessmentScreen> {
  late List<_MedicineAssessmentState> _assessments;
  int _selectedMedicineIndex = 0;
  bool _submitting = false;
  bool _applyToAll = false;

  @override
  void initState() {
    super.initState();
    _assessments = widget.confirmedItems.map((item) {
      return _MedicineAssessmentState(
        medicineName: item['medicine_name'] ?? 'Prescribed Medicine',
        strength: item['strength'],
        itemId: item['id'],
      );
    }).toList();

    if (_assessments.isEmpty) {
      _assessments.add(_MedicineAssessmentState(
        medicineName: 'Prescription Medicines',
      ));
    }
  }

  @override
  void dispose() {
    for (final a in _assessments) {
      a.dispose();
    }
    super.dispose();
  }

  _MedicineAssessmentState get _current =>
      _assessments[_selectedMedicineIndex];

  Future<void> _submitAndProceed() async {
    setState(() => _submitting = true);

    try {
      List<Map<String, dynamic>> itemsPayload;

      if (_applyToAll && _assessments.isNotEmpty) {
        final template = _current;
        itemsPayload = _assessments.map((a) {
          return {
            'prescription_id': widget.prescriptionId,
            'prescription_item_id': a.itemId,
            'medicine_name': a.medicineName,
            'has_run_out': template.hasRunOut,
            'requested_timeframe': template.requestedTimeframe,
            'treatment_status': template.treatmentStatus,
            'next_dose_timeframe': template.nextDoseTimeframe,
            'alternative_pharmacy_available': template.alternativeAvailable,
            'alternative_availability_verified': template.alternativeVerified,
            'additional_information': template.notesCtrl.text.trim().isNotEmpty
                ? template.notesCtrl.text.trim()
                : null,
          };
        }).toList();
      } else {
        itemsPayload = _assessments
            .map((a) => a.toJson(widget.prescriptionId))
            .toList();
      }

      // 1. Submit to Backend
      final assessmentResults =
          await ApiService.instance.submitBatchUrgencyAssessments(
        prescriptionId: widget.prescriptionId,
        items: itemsPayload,
      );

      // 2. Fetch or reuse matching pharmacies
      List<Map<String, dynamic>> matchingPharmacies =
          widget.preloadedPharmacies ?? [];

      if (matchingPharmacies.isEmpty) {
        final loc = LocationService.instance.currentLocation.value;
        final lat = loc?.latitude ?? 31.5204;
        final lon = loc?.longitude ?? 74.3587;

        final res = await ApiService.instance.confirmPrescriptionAndMatch(
          prescriptionId: widget.prescriptionId,
          items: widget.confirmedItems,
          lat: lat,
          lon: lon,
        );
        matchingPharmacies =
            (res['matching_pharmacies'] as List? ?? []).cast<Map<String, dynamic>>();
      }

      if (!mounted) return;
      setState(() => _submitting = false);

      // Show brief confirmation snackbar with preliminary logistical priority
      final firstPriority = assessmentResults.isNotEmpty
          ? assessmentResults[0]['preliminary_logistical_priority'] ??
              'Logistical Assessment Recorded'
          : 'Assessment Submitted';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Priority Assessment Submitted: $firstPriority'),
          backgroundColor: C.purple,
          duration: const Duration(seconds: 3),
        ),
      );

      // 3. Navigate to Pharmacy Matching Screen
      push(
        context,
        PharmacyMatchingScreen(
          prescriptionId: widget.prescriptionId,
          confirmedItems: widget.confirmedItems,
          matchingPharmacies: matchingPharmacies,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Medicine Priority Assessment',
      child: FadeSlideEntrance(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Subtitle & Objective Header Card
            IlluminatedCard(
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.balance_rounded,
                              color: C.purple, size: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fair Resource Allocation',
                              style: t(16, w: FontWeight.w800, c: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pharmacist-Supervised Priority System',
                              style: t(12, c: const Color(0xFFDDD6FE)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Help us understand how soon you need your prescribed medicines so we can manage limited stock fairly.',
                    style: t(13, c: Colors.white, h: 1.4, w: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Multi-Medicine Selector (if > 1 medicine)
            if (_assessments.length > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Medicine to Assess',
                      style: t(14.5, w: FontWeight.w700)),
                  Row(
                    children: [
                      Checkbox(
                        value: _applyToAll,
                        activeColor: C.purple,
                        onChanged: (v) =>
                            setState(() => _applyToAll = v ?? false),
                      ),
                      Text('Apply to all', style: t(12.5, c: C.sub)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_assessments.length, (i) {
                    final isSel = i == _selectedMedicineIndex;
                    final med = _assessments[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedMedicineIndex = i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? C.purple : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? C.purple : C.border,
                              width: isSel ? 1.5 : 1,
                            ),
                            boxShadow: isSel ? DawaShadows.purpleGlow : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.medication_rounded,
                                size: 16,
                                color: isSel ? Colors.white : C.purple,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                med.medicineName,
                                style: t(
                                  13,
                                  w: isSel ? FontWeight.w700 : FontWeight.w600,
                                  c: isSel ? Colors.white : C.text,
                                ),
                              ),
                              if (med.strength != null &&
                                  med.strength!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${med.strength})',
                                  style: t(11.5,
                                      c: isSel
                                          ? const Color(0xFFE9D5FF)
                                          : C.sub),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 3. Current Medicine Focus Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: C.light,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined,
                      color: C.purple, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Assessing: ${_current.medicineName} ${_current.strength ?? ""}',
                      style: t(13.5, w: FontWeight.w700, c: C.indigo),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // QUESTION 1
            _buildQuestionCard(
              qNum: '1',
              question: 'Have you already run out of this medicine?',
              options: [
                _Option('completely_out', 'Yes, I have completely run out.'),
                _Option('few_doses', 'I have only a few doses remaining.'),
                _Option('enough_for_days',
                    'I have enough medicine for several days.'),
                _Option(
                    'new_prescription', 'This is a newly prescribed medicine.'),
              ],
              selectedValue: _current.hasRunOut,
              onSelected: (val) => setState(() => _current.hasRunOut = val),
            ),
            const SizedBox(height: 16),

            // QUESTION 2
            _buildQuestionCard(
              qNum: '2',
              question: 'When do you need this medicine?',
              subtitle: 'Select your time-sensitivity.',
              options: [
                _Option('asap', 'As soon as possible.'),
                _Option('24_hours', 'Within the next 24 hours.'),
                _Option('2_to_3_days', 'Within 2–3 days.'),
                _Option('4_to_7_days', 'Within 4–7 days.'),
                _Option('enough_for_now', 'I have enough medicine for now.'),
              ],
              selectedValue: _current.requestedTimeframe,
              onSelected: (val) =>
                  setState(() => _current.requestedTimeframe = val),
            ),
            const SizedBox(height: 16),

            // QUESTION 3
            _buildQuestionCard(
              qNum: '3',
              question:
                  'Is this medicine part of an ongoing prescribed treatment?',
              options: [
                _Option('ongoing', 'Yes, I am currently taking it.'),
                _Option('new_prescription', 'No, this is a new prescription.'),
                _Option('unsure', 'I am unsure.'),
              ],
              selectedValue: _current.treatmentStatus,
              onSelected: (val) =>
                  setState(() => _current.treatmentStatus = val),
            ),
            const SizedBox(height: 16),

            // QUESTION 4
            _buildQuestionCard(
              qNum: '4',
              question: 'When is your next prescribed dose due?',
              options: [
                _Option(
                    'within_few_hours', 'Within the next few hours.'),
                _Option('today', 'Today.'),
                _Option('tomorrow', 'Tomorrow.'),
                _Option('later', 'Later than tomorrow.'),
                _Option('unsure', 'I am unsure.'),
              ],
              selectedValue: _current.nextDoseTimeframe,
              onSelected: (val) =>
                  setState(() => _current.nextDoseTimeframe = val),
            ),
            const SizedBox(height: 16),

            // QUESTION 5
            _buildQuestionCard(
              qNum: '5',
              question:
                  'Can you obtain this medicine from another pharmacy?',
              options: [
                _Option('yes', 'Yes.'),
                _Option('no', 'No.'),
                _Option('unsure', 'I am unsure.'),
              ],
              selectedValue: _current.alternativeAvailable,
              onSelected: (val) =>
                  setState(() => _current.alternativeAvailable = val),
              extraWidget: _current.alternativeAvailable == 'yes'
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.border),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _current.alternativeVerified,
                              activeColor: C.purple,
                              onChanged: (v) => setState(() =>
                                  _current.alternativeVerified = v ?? false),
                            ),
                            Expanded(
                              child: Text(
                                'Confirmed available in stock at that pharmacy',
                                style: t(12.5, c: C.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // QUESTION 6: Optional Additional Info
            DawaCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: C.light,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('6',
                              style: t(13, w: FontWeight.w700, c: C.purple)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Additional Information (Optional)',
                          style: t(14.5, w: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Is there anything else the pharmacist should know about your medicine availability?',
                    style: t(12.5, c: C.sub),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _current.notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. Traveling tomorrow morning, strict dosage timing required, post-surgical care...',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // MANDATORY DISCLAIMER
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your answers help our pharmacist understand your situation. They do not replace medical advice or a clinical assessment.',
                      style: t(12.5, c: const Color(0xFF14532D), h: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SUBMIT BUTTON
            FilledButton.icon(
              onPressed: _submitting ? null : _submitAndProceed,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(_submitting
                  ? 'Saving Assessment & Checking Stock...'
                  : 'Submit Priority Assessment'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard({
    required String qNum,
    required String question,
    String? subtitle,
    required List<_Option> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    Widget? extraWidget,
  }) {
    return DawaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: C.light,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(qNum,
                      style: t(13, w: FontWeight.w700, c: C.purple)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question, style: t(14.5, w: FontWeight.w700)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: t(12, c: C.sub)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final opt in options) ...[
            _buildRadioTile(
              label: opt.label,
              value: opt.value,
              groupValue: selectedValue,
              onTap: () => onSelected(opt.value),
            ),
            const SizedBox(height: 6),
          ],
          if (extraWidget != null) extraWidget,
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String label,
    required String value,
    required String groupValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? C.purple : const Color(0xFFF1F1F5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? C.purple : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: C.purple,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: t(
                  13,
                  w: isSelected ? FontWeight.w600 : FontWeight.w400,
                  c: isSelected ? C.indigo : C.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option {
  final String value;
  final String label;
  _Option(this.value, this.label);
}

