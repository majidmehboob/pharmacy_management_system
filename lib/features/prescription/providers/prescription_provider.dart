import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/prescription_model.dart';
import '../../inventory/providers/inventory_provider.dart';

class PrescriptionNotifier extends StateNotifier<List<Prescription>> {
  final DatabaseHelper _dbHelper;
  final Ref _ref;

  PrescriptionNotifier(this._dbHelper, this._ref) : super([]) {
    loadPrescriptions();
  }

  Future<void> loadPrescriptions() async {
    final prescriptions = await _dbHelper.getPrescriptions();
    state = prescriptions;
  }

  Future<void> createPrescription(Prescription prescription) async {
    await _dbHelper.insertPrescription(prescription);
    await loadPrescriptions();
  }

  Future<void> updatePrescription(Prescription prescription) async {
    await _dbHelper.updatePrescription(prescription);
    await loadPrescriptions();
  }

  Future<void> deletePrescription(String id) async {
    await _dbHelper.deletePrescription(id);
    await loadPrescriptions();
  }

  Future<bool> dispensePrescription(String id) async {
    final rx = await _dbHelper.getPrescriptionById(id);
    if (rx == null) return false;
    
    // Verify if we can dispense (all medicines must have sufficient stock)
    final inventory = _ref.read(inventoryProvider);
    if (!rx.canDispense(inventory)) {
      return false;
    }

    // Update status to 'dispensed'
    final updatedRx = rx.copyWith(
      status: 'dispensed',
      items: rx.items.map((i) => i.copyWith(dispensed: true)).toList(),
    );
    await _dbHelper.updatePrescription(updatedRx);

    // Deduct stock for each medicine in the prescription
    for (final item in rx.items) {
      await _dbHelper.updateStock(item.medicineId, -item.quantity);
    }

    // Refresh inventory provider
    await _ref.read(inventoryProvider.notifier).loadMedicines();
    
    // Reload prescriptions
    await loadPrescriptions();
    return true;
  }

  Future<void> getPrescriptionsByPatient(String name) async {
    if (name.trim().isEmpty) {
      await loadPrescriptions();
      return;
    }
    final allPrescriptions = await _dbHelper.getPrescriptions();
    state = allPrescriptions.where((rx) => rx.patientName.toLowerCase().contains(name.toLowerCase())).toList();
  }

  Future<void> getPrescriptionsByStatus(String status) async {
    if (status == 'All' || status.trim().isEmpty) {
      await loadPrescriptions();
      return;
    }
    final allPrescriptions = await _dbHelper.getPrescriptions();
    state = allPrescriptions.where((rx) => rx.status.toLowerCase() == status.toLowerCase()).toList();
  }

  List<Prescription> getPendingPrescriptions() {
    return state.where((rx) => rx.status.toLowerCase() == 'pending').toList();
  }
}

final prescriptionProvider = StateNotifierProvider<PrescriptionNotifier, List<Prescription>>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return PrescriptionNotifier(dbHelper, ref);
});
