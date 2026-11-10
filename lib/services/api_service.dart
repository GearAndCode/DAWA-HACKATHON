import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // Android emulator uses 10.0.2.2, Web/Desktop/iOS uses 127.0.0.1
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  String baseUrl = defaultBaseUrl;

  Uri _uri(String endpoint, [Map<String, String>? queryParams]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$baseUrl$cleanEndpoint';
    return Uri.parse(fullUrl).replace(queryParameters: queryParams);
  }

  // 1. Location & Nearby Pharmacies
  Future<List<Map<String, dynamic>>> getNearbyPharmacies(
      double lat, double lon) async {
    try {
      final res = await http.get(_uri('/location/nearby-pharmacies', {
        'lat': lat.toString(),
        'lon': lon.toString(),
      })).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Server returned ${res.statusCode}: ${res.body}');
    } catch (e) {
      debugPrint('Error getting nearby pharmacies: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllPharmacies() async {
    try {
      final res = await http
          .get(_uri('/location/pharmacies'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Server returned ${res.statusCode}');
    } catch (e) {
      debugPrint('Error fetching pharmacies: $e');
      rethrow;
    }
  }

  // 2. Medicines Catalog
  Future<List<Map<String, dynamic>>> searchMedicines(
      {String? query, String? category}) async {
    try {
      final params = <String, String>{};
      if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
      if (category != null && category.trim().isNotEmpty) {
        params['category'] = category.trim();
      }

      final res = await http
          .get(_uri('/medicines', params.isNotEmpty ? params : null))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Server returned ${res.statusCode}');
    } catch (e) {
      debugPrint('Error searching medicines: $e');
      rethrow;
    }
  }

  // 3. Prescription OCR Upload
  Future<Map<String, dynamic>> uploadPrescription(
      Uint8List imageBytes, String filename,
      {int patientId = 1}) async {
    try {
      final uri = _uri('/ocr/upload-prescription');
      final request = http.MultipartRequest('POST', uri)
        ..fields['patient_id'] = patientId.toString()
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
        ));

      final streamedRes =
          await request.send().timeout(const Duration(seconds: 25));
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Upload failed (${res.statusCode}): ${res.body}');
    } catch (e) {
      debugPrint('Error uploading prescription: $e');
      rethrow;
    }
  }

  // 4. Confirm Medicine Review & Match Pharmacies
  Future<Map<String, dynamic>> confirmPrescriptionAndMatch({
    required int prescriptionId,
    required List<Map<String, dynamic>> items,
    int patientId = 1,
    double? lat,
    double? lon,
  }) async {
    try {
      final body = jsonEncode({
        'prescription_id': prescriptionId,
        'patient_id': patientId,
        'items': items,
        'patient_latitude': lat,
        'patient_longitude': lon,
      });

      final res = await http
          .post(
            _uri('/prescriptions/confirm-and-match'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Confirmation failed: ${res.body}');
    } catch (e) {
      debugPrint('Error confirming prescription: $e');
      rethrow;
    }
  }

  // 5. Generate Invoice
  Future<Map<String, dynamic>> generateInvoice({
    required int prescriptionId,
    required int pharmacyId,
    bool delivery = false,
  }) async {
    try {
      final uri = _uri('/invoices/generate', {
        'prescription_id': prescriptionId.toString(),
        'pharmacy_id': pharmacyId.toString(),
        'delivery': delivery.toString(),
      });

      final res = await http.post(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Invoice generation failed: ${res.body}');
    } catch (e) {
      debugPrint('Error generating invoice: $e');
      rethrow;
    }
  }

  // 6. Invoice Decision (Approve / Reject)
  Future<Map<String, dynamic>> submitInvoiceDecision(
    int invoiceId, {
    required bool approved,
    String? reason,
  }) async {
    try {
      final body = jsonEncode({
        'approved': approved,
        'rejection_reason': reason,
      });

      final res = await http
          .post(
            _uri('/invoices/$invoiceId/decision'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Decision failed: ${res.body}');
    } catch (e) {
      debugPrint('Error submitting invoice decision: $e');
      rethrow;
    }
  }

  // 7. Create Order (Pickup or Delivery)
  Future<Map<String, dynamic>> createOrder({
    required int invoiceId,
    required String fulfillmentType,
    int patientId = 1,
    String? deliveryAddress,
    double? lat,
    double? lon,
    String? paymentMethod,
  }) async {
    try {
      final body = jsonEncode({
        'invoice_id': invoiceId,
        'patient_id': patientId,
        'fulfillment_type': fulfillmentType,
        'delivery_address': deliveryAddress,
        'delivery_latitude': lat,
        'delivery_longitude': lon,
        'payment_method': paymentMethod ??
            'Pay at Pickup / Cash on Delivery (Demo)',
      });

      final res = await http
          .post(
            _uri('/orders/create'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Order creation failed: ${res.body}');
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  // 8. Order Tracking & History
  Future<List<Map<String, dynamic>>> getOrders() async {
    try {
      final res = await http
          .get(_uri('/orders'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Failed to fetch orders: ${res.statusCode}');
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOrderDetails(int orderId) async {
    try {
      final res = await http
          .get(_uri('/orders/$orderId'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Order details error: ${res.statusCode}');
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      rethrow;
    }
  }

  // 9. Pharmacist Admin API
  Future<List<Map<String, dynamic>>> getAdminOrders({String? statusFilter}) async {
    try {
      final params = statusFilter != null ? {'status_filter': statusFilter} : null;
      final res = await http
          .get(_uri('/admin/orders', params))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Admin orders error: ${res.statusCode}');
    } catch (e) {
      debugPrint('Error fetching admin orders: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyOrder(
    int orderId, {
    required String action, // "VERIFY" or "REJECT"
    String? notes,
    String? rejectionReason,
  }) async {
    try {
      final body = jsonEncode({
        'action': action,
        'notes': notes,
        'rejection_reason': rejectionReason,
      });

      final res = await http
          .post(
            _uri('/admin/orders/$orderId/verify'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Verification failed: ${res.body}');
    } catch (e) {
      debugPrint('Error verifying order: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    int orderId, {
    required String status,
    String? notes,
  }) async {
    try {
      final body = jsonEncode({
        'status': status,
        'notes': notes,
      });

      final res = await http
          .post(
            _uri('/admin/orders/$orderId/update-status'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Status update failed: ${res.body}');
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }

  // =========================================================
  // 8. Clinical Urgency Assessment & Fair Resource Allocation
  // =========================================================

  /// Patient submits urgency assessment for medicines in a prescription
  Future<List<Map<String, dynamic>>> submitBatchUrgencyAssessments({
    required int prescriptionId,
    int patientId = 1,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final body = jsonEncode({
        'prescription_id': prescriptionId,
        'patient_id': patientId,
        'items': items,
      });

      final res = await http
          .post(
            _uri('/urgency-assessments/batch'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Failed to submit urgency assessment: ${res.body}');
    } catch (e) {
      debugPrint('Error submitting urgency assessment: $e');
      rethrow;
    }
  }

  /// Get urgency assessments for a prescription
  Future<List<Map<String, dynamic>>> getAssessmentsForPrescription(
      int prescriptionId) async {
    try {
      final res = await http
          .get(_uri('/urgency-assessments/prescription/$prescriptionId'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching prescription assessments: $e');
      return [];
    }
  }

  /// Pharmacist retrieves requests awaiting clinical review
  Future<List<Map<String, dynamic>>> getPendingUrgencyAssessments() async {
    try {
      final res = await http
          .get(_uri('/admin/urgency-assessments/pending'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching pending urgency assessments: $e');
      return [];
    }
  }

  /// Pharmacist verifies urgency assessment and assigns clinical urgency
  Future<Map<String, dynamic>> reviewUrgencyAssessment(
    int assessmentId, {
    required String clinicalUrgency,
    String verificationStatus = 'VERIFIED',
    String? notes,
    String? decisionReason,
    int pharmacistId = 101,
    String pharmacistName = 'Licensed Pharmacist',
  }) async {
    try {
      final body = jsonEncode({
        'clinical_urgency': clinicalUrgency,
        'verification_status': verificationStatus,
        'assessment_notes': notes,
        'decision_reason': decisionReason,
        'pharmacist_id': pharmacistId,
        'pharmacist_name': pharmacistName,
      });

      final res = await http
          .post(
            _uri('/admin/urgency-assessments/$assessmentId/review'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Review failed: ${res.body}');
    } catch (e) {
      debugPrint('Error reviewing urgency assessment: $e');
      rethrow;
    }
  }

  /// Get pharmacy inventory shortages
  Future<List<Map<String, dynamic>>> getInventoryShortages() async {
    try {
      final res = await http
          .get(_uri('/admin/resource-allocation/shortages'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching shortages: $e');
      return [];
    }
  }

  /// Register an allocation request for a patient prescription item
  Future<Map<String, dynamic>> createAllocationRequest({
    required int pharmacyId,
    required int medicineId,
    int? patientId,
    int? prescriptionId,
    int? prescriptionItemId,
    int? urgencyAssessmentId,
    required int requestedQuantity,
  }) async {
    try {
      final body = jsonEncode({
        'pharmacy_id': pharmacyId,
        'medicine_id': medicineId,
        'patient_id': patientId ?? 1,
        'prescription_id': prescriptionId,
        'prescription_item_id': prescriptionItemId,
        'urgency_assessment_id': urgencyAssessmentId,
        'requested_quantity': requestedQuantity,
      });

      final res = await http
          .post(
            _uri('/resource-allocation/request'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Failed to create allocation request: ${res.body}');
    } catch (e) {
      debugPrint('Error creating allocation request: $e');
      rethrow;
    }
  }

  /// Run fair resource allocation engine for a shortage medicine
  Future<List<Map<String, dynamic>>> runFairAllocation({
    required int pharmacyId,
    required int medicineId,
    String pharmacistName = 'Licensed Pharmacist',
  }) async {
    try {
      final body = jsonEncode({
        'pharmacy_id': pharmacyId,
        'medicine_id': medicineId,
      });

      final res = await http
          .post(
            _uri('/admin/resource-allocation/run', {'pharmacist_name': pharmacistName}),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Allocation run failed: ${res.body}');
    } catch (e) {
      debugPrint('Error running fair allocation: $e');
      rethrow;
    }
  }

  /// Pharmacist manual override with mandatory reason
  Future<Map<String, dynamic>> overrideAllocation(
    int allocationId, {
    required int newQuantity,
    required String reason,
    String pharmacistName = 'Licensed Pharmacist',
  }) async {
    try {
      final body = jsonEncode({
        'override_allocated_quantity': newQuantity,
        'override_reason': reason,
        'pharmacist_name': pharmacistName,
      });

      final res = await http
          .post(
            _uri('/admin/resource-allocation/$allocationId/override'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Override failed: ${res.body}');
    } catch (e) {
      debugPrint('Error overriding allocation: $e');
      rethrow;
    }
  }

  /// Get patient's allocations
  Future<List<Map<String, dynamic>>> getPatientAllocations(int patientId) async {
    try {
      final res = await http
          .get(_uri('/patient/resource-allocations/$patientId'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching patient allocations: $e');
      return [];
    }
  }

  /// Get allocations for a prescription
  Future<List<Map<String, dynamic>>> getPrescriptionAllocations(int prescriptionId) async {
    try {
      final res = await http
          .get(_uri('/resource-allocation/prescription/$prescriptionId'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching prescription allocations: $e');
      return [];
    }
  }

  /// Get allocation audit history
  Future<List<Map<String, dynamic>>> getAllocationAuditHistory({int? allocationId}) async {
    try {
      final params = <String, String>{};
      if (allocationId != null) params['allocation_id'] = allocationId.toString();

      final res = await http
          .get(_uri('/admin/resource-allocation/history', params.isNotEmpty ? params : null))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching audit history: $e');
      return [];
    }
  }
}
