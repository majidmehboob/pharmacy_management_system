import 'package:flutter/material.dart';
import 'medicine_model.dart';
import 'package:uuid/uuid.dart';

class PrescriptionItem {
  final String id;
  final String prescriptionId;
  final String medicineId;
  final String? dosage; // e.g. "500mg"
  final String? frequency; // e.g. "Twice daily"
  final String? duration; // e.g. "7 days"
  final int quantity;
  final bool dispensed;
  
  // Optional, for UI convenience
  final Medicine? medicine;

  PrescriptionItem({
    required this.id,
    required this.prescriptionId,
    required this.medicineId,
    this.dosage,
    this.frequency,
    this.duration,
    required this.quantity,
    this.dispensed = false,
    this.medicine,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> json, {Medicine? medicine}) {
    return PrescriptionItem(
      id: json['id'] as String,
      prescriptionId: json['prescription_id'] as String,
      medicineId: json['medicine_id'] as String,
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
      duration: json['duration'] as String?,
      quantity: json['quantity'] as int,
      dispensed: (json['dispensed'] as int? ?? 0) == 1,
      medicine: medicine,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prescription_id': prescriptionId,
      'medicine_id': medicineId,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'quantity': quantity,
      'dispensed': dispensed ? 1 : 0,
    };
  }

  PrescriptionItem copyWith({
    String? id,
    String? prescriptionId,
    String? medicineId,
    String? dosage,
    String? frequency,
    String? duration,
    int? quantity,
    bool? dispensed,
    Medicine? medicine,
  }) {
    return PrescriptionItem(
      id: id ?? this.id,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      medicineId: medicineId ?? this.medicineId,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      duration: duration ?? this.duration,
      quantity: quantity ?? this.quantity,
      dispensed: dispensed ?? this.dispensed,
      medicine: medicine ?? this.medicine,
    );
  }
}

class Prescription {
  final String id;
  final String prescriptionNumber;
  final String patientName;
  final String? patientPhone;
  final int? patientAge;
  final String? patientGender;
  final String? doctorName;
  final String? doctorLicense;
  final String prescribedDate; // ISO Date String
  final String status; // 'pending', 'dispensed', 'completed', 'cancelled'
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final List<PrescriptionItem> items;

  Prescription({
    required this.id,
    required this.prescriptionNumber,
    required this.patientName,
    this.patientPhone,
    this.patientAge,
    this.patientGender,
    this.doctorName,
    this.doctorLicense,
    required this.prescribedDate,
    this.status = 'pending',
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  static String generatePrescriptionNumber() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final randomSuffix = const Uuid().v4().substring(0, 4).toUpperCase();
    return 'RX-$year-$month$day-$randomSuffix';
  }

  factory Prescription.fromJson(Map<String, dynamic> json, {List<PrescriptionItem> items = const []}) {
    return Prescription(
      id: json['id'] as String,
      prescriptionNumber: json['prescription_number'] as String,
      patientName: json['patient_name'] as String,
      patientPhone: json['patient_phone'] as String?,
      patientAge: json['patient_age'] as int?,
      patientGender: json['patient_gender'] as String?,
      doctorName: json['doctor_name'] as String?,
      doctorLicense: json['doctor_license'] as String?,
      prescribedDate: json['prescribed_date'] as String,
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prescription_number': prescriptionNumber,
      'patient_name': patientName,
      'patient_phone': patientPhone,
      'patient_age': patientAge,
      'patient_gender': patientGender,
      'doctor_name': doctorName,
      'doctor_license': doctorLicense,
      'prescribed_date': prescribedDate,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Prescription copyWith({
    String? id,
    String? prescriptionNumber,
    String? patientName,
    String? patientPhone,
    int? patientAge,
    String? patientGender,
    String? doctorName,
    String? doctorLicense,
    String? prescribedDate,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
    List<PrescriptionItem>? items,
  }) {
    return Prescription(
      id: id ?? this.id,
      prescriptionNumber: prescriptionNumber ?? this.prescriptionNumber,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      patientAge: patientAge ?? this.patientAge,
      patientGender: patientGender ?? this.patientGender,
      doctorName: doctorName ?? this.doctorName,
      doctorLicense: doctorLicense ?? this.doctorLicense,
      prescribedDate: prescribedDate ?? this.prescribedDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange; // Yellow/Orange
      case 'dispensed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusText() {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  bool canDispense(List<Medicine> availableMedicines) {
    if (status.toLowerCase() != 'pending') return false;
    for (final item in items) {
      final medicine = availableMedicines.firstWhere(
        (m) => m.id == item.medicineId,
        orElse: () => Medicine(id: '', name: '', sellingPrice: 0, currentStock: 0),
      );
      if (medicine.id.isEmpty || medicine.currentStock < item.quantity) {
        return false;
      }
    }
    return true;
  }
}
