import 'dart:typed_data';
import 'package:flutter/material.dart';

/// All data in this file is LOCAL DEMO DATA. It is not live inventory.
class Medicine {
  final String name, strength, category, form;
  const Medicine(this.name, this.strength, this.category, this.form);
}

const List<Medicine> medicines = [
  Medicine('Panadol', '500 mg', 'Pain & Fever', 'Tablet'),
  Medicine('Brufen', '400 mg', 'Pain & Inflammation', 'Tablet'),
  Medicine('Augmentin', '625 mg', 'Antibiotic (prescription required)', 'Tablet'),
  Medicine('Calpol', '120 mg/5 ml', 'Pain & Fever', 'Syrup'),
  Medicine('Disprin', '300 mg', 'Pain Relief', 'Soluble tablet'),
  Medicine('Vitamin C', '500 mg', 'Supplement', 'Tablet'),
];

class Product {
  final String name, category;
  final IconData icon;
  const Product(this.name, this.category, this.icon);
}

const List<Product> products = [
  Product('Digital Thermometer', 'Health Devices', Icons.thermostat_rounded),
  Product('Blood Pressure Monitor', 'Health Devices', Icons.monitor_heart_outlined),
  Product('Face Masks (Box)', 'Protection', Icons.masks_outlined),
  Product('Hand Sanitizer', 'Hygiene', Icons.clean_hands_outlined),
  Product('First Aid Kit', 'Safety', Icons.medical_services_outlined),
  Product('Adhesive Bandages', 'Safety', Icons.healing_outlined),
];

class Pharmacy {
  final String name, area, description, hours;
  final IconData icon;
  const Pharmacy(this.name, this.area, this.description, this.hours, this.icon);
}

const List<Pharmacy> pharmacies = [
  Pharmacy('City Care Pharmacy', 'Gulberg, Lahore (demo)',
      'A fictional neighbourhood pharmacy used to demonstrate the DAWA experience.',
      '9:00 AM – 11:00 PM (demo)', Icons.local_pharmacy_outlined),
  Pharmacy('HealthPlus Pharmacy', 'Model Town, Lahore (demo)',
      'A fictional pharmacy with everyday medicines and health products.',
      '8:00 AM – 10:00 PM (demo)', Icons.medication_liquid_outlined),
  Pharmacy('MediPoint Pharmacy', 'DHA Phase 5, Lahore (demo)',
      'A fictional pharmacy used to preview how DAWA presents pharmacy information.',
      '24 hours (demo)', Icons.health_and_safety_outlined),
];

class DemoLocation {
  final String label, address;
  const DemoLocation(this.label, this.address);
}

const List<DemoLocation> locations = [
  DemoLocation('Home Address', 'Lahore, Pakistan'),
  DemoLocation('Office', 'Gulberg III, Lahore'),
  DemoLocation("Parents' Home", 'Model Town, Lahore'),
];

final ValueNotifier<DemoLocation> selectedLocation =
    ValueNotifier<DemoLocation>(locations.first);

final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

final ValueNotifier<List<Medicine>> recentlyViewed =
    ValueNotifier<List<Medicine>>([medicines[0], medicines[1], medicines[5]]);

void markViewed(Medicine m) {
  final list = List<Medicine>.from(recentlyViewed.value)
    ..removeWhere((e) => e.name == m.name)
    ..insert(0, m);
  recentlyViewed.value = list.take(6).toList();
}

class PrescriptionRecord {
  final DateTime date;
  final Uint8List? bytes;
  final List<String> items;
  const PrescriptionRecord(this.date, this.bytes, this.items);
}

final ValueNotifier<List<PrescriptionRecord>> prescriptionRecords =
    ValueNotifier<List<PrescriptionRecord>>([]);

class DemoNotification {
  final String title, body, time;
  const DemoNotification(this.title, this.body, this.time);
}

const List<DemoNotification> notifications = [
  DemoNotification('Welcome to DAWA',
      'Upload a prescription to explore the DAWA workflow. This version uses demo data.', 'Today'),
  DemoNotification('Pharmacist review',
      'Prescription orders should be reviewed by a qualified pharmacist before approval.', 'Today'),
  DemoNotification('Health reminder',
      'Always read the label and follow the instructions of your doctor or pharmacist.', 'Yesterday'),
];
