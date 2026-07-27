import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/medicine_model.dart';
import 'package:flutter_riverpod/legacy.dart';

class InventoryNotifier extends StateNotifier<List<Medicine>> {
  final DatabaseHelper _dbHelper;

  InventoryNotifier(this._dbHelper) : super([]) {
    loadMedicines();
  }

  Future<void> loadMedicines() async {
    final medicines = await _dbHelper.getMedicines();
    state = medicines;
  }

  Future<void> addMedicine(Medicine medicine) async {
    await _dbHelper.insertMedicine(medicine);
    await loadMedicines();
  }

  Future<void> updateMedicine(Medicine medicine) async {
    await _dbHelper.updateMedicine(medicine);
    await loadMedicines();
  }

  Future<void> deleteMedicine(String id) async {
    await _dbHelper.deleteMedicine(id);
    await loadMedicines();
  }

  Future<void> searchMedicines(String query) async {
    if (query.trim().isEmpty) {
      await loadMedicines();
      return;
    }
    final results = await _dbHelper.searchMedicines(query);
    state = results;
  }

  Future<void> filterByCategory(String category) async {
    if (category == 'All' || category.trim().isEmpty) {
      await loadMedicines();
      return;
    }
    final allMedicines = await _dbHelper.getMedicines();
    state = allMedicines.where((med) => med.category == category).toList();
  }

  List<Medicine> getLowStockMedicines() {
    return state.where((med) => med.isLowStock()).toList();
  }

  List<Medicine> getExpiringMedicines(int days) {
    final now = DateTime.now();
    final limit = now.add(Duration(days: days));
    
    return state.where((med) {
      if (med.expiryDate == null || med.expiryDate!.isEmpty) return false;
      try {
        final expiry = DateTime.parse(med.expiryDate!);
        return expiry.isBefore(limit) && !med.isExpired();
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Future<void> updateStock(String id, int quantityChange) async {
    await _dbHelper.updateStock(id, quantityChange);
    await loadMedicines();
  }
}

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final inventoryProvider = StateNotifierProvider<InventoryNotifier, List<Medicine>>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return InventoryNotifier(dbHelper);
});
