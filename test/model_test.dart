import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_management_system/core/models/medicine_model.dart';
import 'package:pharmacy_management_system/core/models/prescription_model.dart';
import 'package:pharmacy_management_system/core/models/sale_model.dart';

void main() {
  group('Medicine Model Tests', () {
    test('JSON serialization & deserialization', () {
      final medMap = {
        'id': 'med-123',
        'name': 'Paracetamol',
        'generic_name': 'Acetaminophen',
        'category': 'Pain Relief',
        'manufacturer': 'GSK',
        'purchase_price': 2.50,
        'selling_price': 5.00,
        'current_stock': 50,
        'reorder_level': 10,
        'batch_number': 'BATCH-001',
        'expiry_date': '2030-12-31',
        'requires_prescription': 0,
        'is_active': 1,
        'created_at': '2026-07-22T00:00:00Z',
        'updated_at': '2026-07-22T00:00:00Z',
      };

      final medicine = Medicine.fromJson(medMap);
      expect(medicine.name, 'Paracetamol');
      expect(medicine.sellingPrice, 5.00);
      expect(medicine.requiresPrescription, false);

      final serialized = medicine.toJson();
      expect(serialized['id'], 'med-123');
      expect(serialized['requires_prescription'], 0);
    });

    test('isLowStock helper', () {
      final medLow = Medicine(id: '1', name: 'MedA', sellingPrice: 10, currentStock: 5, reorderLevel: 10);
      final medOk = Medicine(id: '2', name: 'MedB', sellingPrice: 10, currentStock: 15, reorderLevel: 10);
      
      expect(medLow.isLowStock(), true);
      expect(medOk.isLowStock(), false);
    });

    test('isExpired helper', () {
      final today = DateTime.now();
      final expiredMed = Medicine(
        id: '1', 
        name: 'MedA', 
        sellingPrice: 10, 
        expiryDate: today.subtract(const Duration(days: 5)).toIso8601String().substring(0, 10),
      );
      final activeMed = Medicine(
        id: '2', 
        name: 'MedB', 
        sellingPrice: 10, 
        expiryDate: today.add(const Duration(days: 30)).toIso8601String().substring(0, 10),
      );

      expect(expiredMed.isExpired(), true);
      expect(activeMed.isExpired(), false);
    });

    test('getStatus helper checks', () {
      final activeMed = Medicine(id: '1', name: 'MedA', sellingPrice: 10, currentStock: 15, reorderLevel: 10);
      final lowStockMed = Medicine(id: '2', name: 'MedB', sellingPrice: 10, currentStock: 5, reorderLevel: 10);
      final inactiveMed = Medicine(id: '3', name: 'MedC', sellingPrice: 10, currentStock: 15, isActive: false);

      expect(activeMed.getStatus(), 'In Stock');
      expect(lowStockMed.getStatus(), 'Low Stock');
      expect(inactiveMed.getStatus(), 'Discontinued');
    });
  });

  group('Prescription Model Tests', () {
    test('canDispense helper validation', () {
      final availableMeds = [
        Medicine(id: 'med-1', name: 'MedA', sellingPrice: 10, currentStock: 15, reorderLevel: 5),
        Medicine(id: 'med-2', name: 'MedB', sellingPrice: 20, currentStock: 2, reorderLevel: 5),
      ];

      final item1 = PrescriptionItem(id: 'i-1', prescriptionId: 'rx-1', medicineId: 'med-1', quantity: 5);
      final item2 = PrescriptionItem(id: 'i-2', prescriptionId: 'rx-1', medicineId: 'med-2', quantity: 5); // Needs 5, only has 2 in stock

      final rxGood = Prescription(
        id: 'rx-1',
        prescriptionNumber: 'RX-1',
        patientName: 'John',
        prescribedDate: '2026-07-22',
        status: 'pending',
        items: [item1],
      );

      final rxBad = Prescription(
        id: 'rx-2',
        prescriptionNumber: 'RX-2',
        patientName: 'Mary',
        prescribedDate: '2026-07-22',
        status: 'pending',
        items: [item1, item2],
      );

      expect(rxGood.canDispense(availableMeds), true);
      expect(rxBad.canDispense(availableMeds), false);
    });
  });

  group('SaleState Calculation Tests', () {
    test('Cart Calculations subtotal, discount, tax, and netTotal', () {
      final med1 = Medicine(id: 'm1', name: 'Med1', sellingPrice: 10.0);
      final med2 = Medicine(id: 'm2', name: 'Med2', sellingPrice: 20.0);

      final item1 = CartItem(medicine: med1, quantity: 2, unitPrice: med1.sellingPrice); // 20.0
      final item2 = CartItem(medicine: med2, quantity: 3, unitPrice: med2.sellingPrice); // 60.0

      final state = SaleState(
        cartItems: [item1, item2],
        discount: 10.0, // 10%
        tax: 5.0, // 5%
      );

      expect(state.subtotal, 80.0);
      expect(state.totalDiscount, 8.0);
      expect(state.taxableAmount, 72.0);
      expect(state.taxAmount, 3.6);
      expect(state.netTotal, 75.6);
    });
  });
}
