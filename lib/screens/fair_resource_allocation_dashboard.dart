import 'package:flutter/material.dart';
import 'package:dawa/theme/app_theme.dart';
import 'package:dawa/widgets/common.dart';
import 'package:dawa/services/api_service.dart';

class FairResourceAllocationView extends StatefulWidget {
  const FairResourceAllocationView({super.key});

  @override
  State<FairResourceAllocationView> createState() =>
      _FairResourceAllocationViewState();
}

class _FairResourceAllocationViewState
    extends State<FairResourceAllocationView> {
  int _activeSubTab = 0; // 0: Shortages & Allocation, 1: Pending Assessments, 2: History
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _shortages = [];
  List<Map<String, dynamic>> _pendingAssessments = [];
  List<Map<String, dynamic>> _auditHistory = [];

  // Currently inspected shortage allocations
  int? _selectedShortagePharmacyId;
  int? _selectedShortageMedicineId;
  String? _selectedShortageMedicineName;
  List<Map<String, dynamic>> _inspectedAllocations = [];
  bool _runningAllocation = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final shortages = await ApiService.instance.getInventoryShortages();
      final pending = await ApiService.instance.getPendingUrgencyAssessments();
      final history = await ApiService.instance.getAllocationAuditHistory();

      if (mounted) {
        setState(() {
          _shortages = shortages;
          _pendingAssessments = pending;
          _auditHistory = history;
          _loading = false;
        });

        // If a shortage was previously selected, refresh its allocations
        if (_selectedShortagePharmacyId != null &&
            _selectedShortageMedicineId != null) {
          _loadAllocations(
              _selectedShortagePharmacyId!,
              _selectedShortageMedicineId!,
              _selectedShortageMedicineName ?? 'Medicine');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load allocation data: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadAllocations(
      int pharmacyId, int medicineId, String medicineName) async {
    try {
      final allocs =
          await ApiService.instance.getPrescriptionAllocations(pharmacyId);
      // Fallback or specific inventory query:
      if (mounted) {
        setState(() {
          _selectedShortagePharmacyId = pharmacyId;
          _selectedShortageMedicineId = medicineId;
          _selectedShortageMedicineName = medicineName;
          _inspectedAllocations = allocs;
        });
      }
    } catch (e) {
      debugPrint('Error loading allocations: $e');
    }
  }

  Future<void> _runAllocation(int pharmacyId, int medicineId) async {
    setState(() => _runningAllocation = true);

    try {
      final results = await ApiService.instance.runFairAllocation(
        pharmacyId: pharmacyId,
        medicineId: medicineId,
        pharmacistName: 'Dr. Sarah Khan, Licensed Pharmacist',
      );

      if (!mounted) return;
      setState(() {
        _runningAllocation = false;
        _inspectedAllocations = results;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Fair allocation executed successfully. Inventory updated transactionally.'),
          backgroundColor: Color(0xFF24845A),
        ),
      );

      _fetchData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _runningAllocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Allocation failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openUrgencyReviewModal(Map<String, dynamic> assessment) async {
    final assessmentId = assessment['id'] as int;
    final medicineName = assessment['medicine_name'] ?? 'Prescribed Medicine';
    final patientId = assessment['patient_id'] ?? 1;

    String selectedUrgency = 'Urgent';
    String verificationStatus = 'VERIFIED';
    final reasonCtrl = TextEditingController(
        text: 'Patient dose due soon; continuous therapy required.');
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: C.purple, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Clinical Urgency Review',
                    style: t(16.5, w: FontWeight.w800)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient #$patientId • $medicineName',
                  style: t(13.5, w: FontWeight.w700, c: C.indigo),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: C.light,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported: ${assessment["has_run_out"]} • Next dose: ${assessment["next_dose_timeframe"]}',
                        style: t(12, c: C.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Preliminary: ${assessment["preliminary_logistical_priority"]}',
                        style: t(11.5, w: FontWeight.w600, c: C.purple),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Pharmacist Clinical Urgency Classification',
                    style: t(13, w: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final u in [
                  'Urgent',
                  'Priority',
                  'Routine',
                  'Further review required'
                ]) ...[
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        selectedUrgency = u;
                        if (u == 'Urgent') {
                          reasonCtrl.text =
                              'Immediate clinical need; critical course continuity.';
                        } else if (u == 'Priority') {
                          reasonCtrl.text =
                              'Active ongoing course with few doses remaining.';
                        } else if (u == 'Routine') {
                          reasonCtrl.text =
                              'Routine maintenance or ample doses remaining.';
                        } else {
                          reasonCtrl.text =
                              'Additional medical records or physician consult needed.';
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedUrgency == u ? const Color(0xFFF5F3FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedUrgency == u ? C.purple : const Color(0xFFE9E6F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedUrgency == u ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selectedUrgency == u ? C.purple : const Color(0xFF94A3B8),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(u, style: t(13, w: selectedUrgency == u ? FontWeight.w700 : FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Clinical Decision Rationale (Mandatory)',
                    hintText: 'State reason for this classification...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Internal Pharmacist Notes (Optional)',
                    hintText: 'e.g. Checked medical history with patient...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Clinical Assessment'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.instance.reviewUrgencyAssessment(
        assessmentId,
        clinicalUrgency: selectedUrgency,
        verificationStatus: verificationStatus,
        decisionReason: reasonCtrl.text.trim(),
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        pharmacistName: 'Dr. Sarah Khan, Licensed Pharmacist',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clinical urgency verified and recorded successfully.'),
          backgroundColor: Color(0xFF24845A),
        ),
      );

      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save assessment: $e')),
      );
    }
  }

  Future<void> _openOverrideModal(Map<String, dynamic> alloc) async {
    final allocId = alloc['id'] as int;
    final patientId = alloc['patient_id'] ?? 1;
    final medicineName = alloc['medicine_name'] ?? 'Medicine';
    final currentAllocated = alloc['allocated_quantity'] as int? ?? 0;
    final requested = alloc['requested_quantity'] as int? ?? 1;

    final qtyCtrl = TextEditingController(text: '$currentAllocated');
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: C.purple, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Override Allocation',
                  style: t(16.5, w: FontWeight.w800)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient #$patientId • $medicineName',
              style: t(13.5, w: FontWeight.w700, c: C.indigo),
            ),
            const SizedBox(height: 6),
            Text(
              'Requested: $requested units • Currently Allocated: $currentAllocated units',
              style: t(12.5, c: C.sub),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Allocated Quantity',
                hintText: 'e.g. 5',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Override Clinical Justification (Mandatory)',
                hintText:
                    'State mandatory reason (e.g. Emergency reserve released)...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().length < 5) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a clinical justification.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Apply Override'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newQty = int.tryParse(qtyCtrl.text.trim()) ?? currentAllocated;

    try {
      await ApiService.instance.overrideAllocation(
        allocId,
        newQuantity: newQty,
        reason: reasonCtrl.text.trim(),
        pharmacistName: 'Dr. Sarah Khan, Licensed Pharmacist',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allocation override recorded with audit history.'),
          backgroundColor: Color(0xFF24845A),
        ),
      );

      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Override failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: C.purple, strokeWidth: 2.5),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(_error!, style: t(13.5, c: C.sub), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Metric Summary Cards
        Row(
          children: [
            _metricPill(
              'Shortages',
              '${_shortages.length}',
              const Color(0xFFDC2626),
              Icons.warning_amber_rounded,
            ),
            const SizedBox(width: 10),
            _metricPill(
              'Awaiting Review',
              '${_pendingAssessments.length}',
              const Color(0xFFD97706),
              Icons.pending_actions_rounded,
            ),
            const SizedBox(width: 10),
            _metricPill(
              'Audit Logs',
              '${_auditHistory.length}',
              const Color(0xFF312E81),
              Icons.history_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Sub-tab Navigation
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _subTabBtn(0, 'Shortages & Allocation (${_shortages.length})'),
              const SizedBox(width: 8),
              _subTabBtn(1, 'Pending Reviews (${_pendingAssessments.length})'),
              const SizedBox(width: 8),
              _subTabBtn(2, 'Audit History (${_auditHistory.length})'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3. Tab Content
        if (_activeSubTab == 0) _buildShortagesSection(),
        if (_activeSubTab == 1) _buildPendingAssessmentsSection(),
        if (_activeSubTab == 2) _buildAuditHistorySection(),
      ],
    );
  }

  Widget _metricPill(String label, String val, Color col, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9E6F0)),
          boxShadow: DawaShadows.subtle,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: col, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(val,
                      style: t(16, w: FontWeight.w800, c: C.text)),
                  Text(label,
                      style: t(10.5, c: C.sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subTabBtn(int index, String label) {
    final isSel = _activeSubTab == index;
    return InkWell(
      onTap: () => setState(() => _activeSubTab = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? C.purple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? C.purple : const Color(0xFFE9E6F0),
          ),
          boxShadow: isSel ? DawaShadows.purpleGlow : DawaShadows.subtle,
        ),
        child: Text(
          label,
          style: t(
            12.5,
            w: isSel ? FontWeight.w700 : FontWeight.w500,
            c: isSel ? Colors.white : C.text,
          ),
        ),
      ),
    );
  }

  // --- SUB-TAB 0: Shortages & Allocation ---
  Widget _buildShortagesSection() {
    if (_shortages.isEmpty) {
      return const EmptyState(
        Icons.inventory_rounded,
        'No Inventory Shortages Detected',
        'All active medicine requests can be completely fulfilled by existing pharmacy stock.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in _shortages) ...[
          DawaSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_rounded,
                          color: Color(0xFFDC2626), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['medicine_name'] ?? 'Medicine',
                              style: t(15.5, w: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(s['pharmacy_name'] ?? 'Pharmacy',
                              style: t(12.5, c: C.sub)),
                        ],
                      ),
                    ),
                    DawaBadge(
                      label: '-${s['shortage_quantity']} Units Short',
                      bg: const Color(0xFFFEE2E2),
                      text: const Color(0xFFDC2626),
                      icon: Icons.trending_down_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Statistics row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F7FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('Available', '${s['stock_quantity']}'),
                      _stat('Requested', '${s['total_requested_quantity']}'),
                      _stat('Patients', '${s['affected_patients_count']}'),
                      _stat('Pending Rev', '${s['pending_assessments_count']}'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: _runningAllocation
                          ? null
                          : () => _runAllocation(
                              s['pharmacy_id'], s['medicine_id']),
                      icon: const Icon(Icons.auto_mode_rounded, size: 16),
                      label: const Text('Run Fair Allocation Engine'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Show Inspected Allocations if available
        if (_inspectedAllocations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.balance_rounded, color: C.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Allocation Proposals (${_inspectedAllocations.length} Requests)',
                style: t(15, w: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final a in _inspectedAllocations) ...[
            _buildAllocationCard(a),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _stat(String label, String val) {
    return Column(
      children: [
        Text(val, style: t(14, w: FontWeight.w800, c: C.indigo)),
        Text(label, style: t(10.5, c: C.sub)),
      ],
    );
  }

  Widget _buildAllocationCard(Map<String, dynamic> alloc) {
    final status = alloc['allocation_status'] ?? 'Pending';
    final requested = alloc['requested_quantity'] ?? 0;
    final allocated = alloc['allocated_quantity'] ?? 0;
    final explanation = alloc['allocation_explanation'] ?? '';
    final patientId = alloc['patient_id'] ?? 1;

    Color badgeBg;
    Color badgeText;
    if (status == 'Fully Allocated') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF15803D);
    } else if (status == 'Partially Allocated') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFD97706);
    } else if (status == 'Waitlisted') {
      badgeBg = const Color(0xFFF1EDFF);
      badgeText = C.purple;
    } else {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
    }

    return DawaSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Patient #$patientId', style: t(14, w: FontWeight.w700)),
              DawaBadge(
                label: '$status ($allocated / $requested)',
                bg: badgeBg,
                text: badgeText,
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: t(12, c: C.text, h: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _openOverrideModal(alloc),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Manual Override'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SUB-TAB 1: Pending Assessments ---
  Widget _buildPendingAssessmentsSection() {
    if (_pendingAssessments.isEmpty) {
      return const EmptyState(
        Icons.task_alt_rounded,
        'No Pending Assessments',
        'All patient urgency assessments have been clinically reviewed and verified by a licensed pharmacist.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in _pendingAssessments) ...[
          DawaSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.light,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_outline_rounded,
                          color: C.purple, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Patient #${p['patient_id']} • ${p['medicine_name'] ?? "Medicine"}',
                              style: t(14.5, w: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            'Rx Ref #${p['prescription_id']}',
                            style: t(11.5, c: C.sub),
                          ),
                        ],
                      ),
                    ),
                    DawaBadge(
                      label: p['preliminary_logistical_priority'] ?? 'Review',
                      bg: const Color(0xFFFEF3C7),
                      text: const Color(0xFFD97706),
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Patient reported circumstances summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F7FC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Has Run Out:', p['has_run_out'] ?? 'N/A'),
                      _infoRow('Next Dose Due:', p['next_dose_timeframe'] ?? 'N/A'),
                      _infoRow('Treatment:', p['treatment_status'] ?? 'N/A'),
                      _infoRow('Alternative Pharmacy:',
                          p['alternative_pharmacy_available'] ?? 'N/A'),
                      if (p['additional_information'] != null &&
                          p['additional_information'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Patient Note: "${p['additional_information']}"',
                          style: t(11.5, c: const Color(0xFF475569), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openUrgencyReviewModal(p),
                      icon: const Icon(Icons.verified_rounded, size: 16),
                      label: const Text('Review & Verify Urgency'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _infoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: t(12, c: C.sub)),
          ),
          Expanded(
            child: Text(val, style: t(12, w: FontWeight.w600, c: C.text)),
          ),
        ],
      ),
    );
  }

  // --- SUB-TAB 2: Audit History ---
  Widget _buildAuditHistorySection() {
    if (_auditHistory.isEmpty) {
      return const EmptyState(
        Icons.history_rounded,
        'No Allocation Adjustments Logged',
        'Audit logs will appear here when fair allocations or pharmacist overrides are recorded.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final h in _auditHistory) ...[
          DawaSurface(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EDFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_edu_rounded,
                      color: C.purple, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(h['changed_by'] ?? 'System',
                              style: t(13, w: FontWeight.w700, c: C.indigo)),
                          Text(
                            (h['timestamp'] ?? '').toString().split('T').first,
                            style: t(11, c: C.sub),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: ${h['previous_status'] ?? "Initial"} -> ${h['new_status']} (Qty: ${h['new_quantity']})',
                        style: t(12, w: FontWeight.w600, c: C.text),
                      ),
                      if (h['reason'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Reason: ${h['reason']}',
                          style: t(11.5, c: C.sub, h: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

