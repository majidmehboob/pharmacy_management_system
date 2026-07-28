import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pharmacy_management_system/core/database/database_helper.dart';
import 'package:pharmacy_management_system/core/models/medicine_model.dart';
import 'package:pharmacy_management_system/core/models/prescription_model.dart';
import 'package:pharmacy_management_system/core/models/sale_model.dart';

// Fake Path Provider Platform to bypass platform channel calls in unit tests
class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '.';
  
  @override
  Future<String?> getApplicationSupportPath() async => '.';
  
  @override
  Future<String?> getLibraryPath() async => '.';
  
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
  
  @override
  Future<String?> getExternalStoragePath() async => '.';
  
  @override
  Future<List<String>?> getExternalCachePaths() async => ['.'];
  
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => ['.'];
  
  @override
  Future<String?> getDownloadsPath() async => '.';
}

void main() {
  // Initialize test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  // Override PathProviderPlatform instance
  PathProviderPlatform.instance = FakePathProviderPlatform();

  // Setup FFI for test execution environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper CRUD Tests', () {
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      // Clear database tables to ensure isolation
      final db = await dbHelper.database;
      await db.delete('sales_items');
      await db.delete('sales');
      await db.delete('prescription_items');
      await db.delete('prescriptions');
      await db.delete('medicines');
    });

    test('Medicine CRUD Operations', () async {
      final med = Medicine(
        id: 'm-test-1',
        name: 'Aspirin Test',
        genericName: 'Acetylsalicylic Acid',
        category: 'Pain Relief',
        sellingPrice: 1.50,
        currentStock: 100,
        reorderLevel: 10,
        isActive: true,
      );

      // 1. Insert
      int resInsert = await dbHelper.insertMedicine(med);
      expect(resInsert, greaterThan(0));

      // 2. Query By Id
      final fetched = await dbHelper.getMedicineById('m-test-1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Aspirin Test');
      expect(fetched.currentStock, 100);

      // 3. Update
      final updatedMed = fetched.copyWith(currentStock: 80);
      await dbHelper.updateMedicine(updatedMed);
      final fetchedUpdated = await dbHelper.getMedicineById('m-test-1');
      expect(fetchedUpdated!.currentStock, 80);

      // 4. Search
      final searchResults = await dbHelper.searchMedicines('Aspirin');
      expect(searchResults.length, 1);

      // 5. Delete
      await dbHelper.deleteMedicine('m-test-1');
      final fetchedDeleted = await dbHelper.getMedicineById('m-test-1');
      expect(fetchedDeleted, isNull);
    });

    test('Prescription Workflow', () async {
      // Add a test medicine
      final med = Medicine(
        id: 'med-p-1',
        name: 'Amlodipine',
        sellingPrice: 4.00,
        currentStock: 50,
      );
      await dbHelper.insertMedicine(med);

      final item = PrescriptionItem(
        id: 'pi-1',
        prescriptionId: 'rx-test-1',
        medicineId: 'med-p-1',
        dosage: '5mg',
        frequency: 'Once daily',
        duration: '30 days',
        quantity: 30,
      );

      final rx = Prescription(
        id: 'rx-test-1',
        prescriptionNumber: 'RX-TEST-001',
        patientName: 'Jane Doe',
        prescribedDate: '2026-07-22',
        status: 'pending',
        items: [item],
      );

      // 1. Insert
      await dbHelper.insertPrescription(rx);

      // 2. Query
      final fetched = await dbHelper.getPrescriptionById('rx-test-1');
      expect(fetched, isNotNull);
      expect(fetched!.patientName, 'Jane Doe');
      expect(fetched.items.length, 1);
      expect(fetched.items[0].medicineId, 'med-p-1');

      // Cleanup
      await dbHelper.deletePrescription('rx-test-1');
      await dbHelper.deleteMedicine('med-p-1');
    });

    test('Sales Checkout Workflow and Stock Deductions', () async {
      // 1. Setup medicine in inventory
      final med = Medicine(
        id: 'med-s-1',
        name: 'Metformin',
        sellingPrice: 10.00,
        currentStock: 100,
      );
      await dbHelper.insertMedicine(med);

      // 2. Create Sale
      final saleId = 'sale-test-1';
      final saleItem = SaleItem(
        id: 'si-1',
        saleId: saleId,
        medicineId: 'med-s-1',
        quantity: 5, // Should reduce stock to 95
        unitPrice: 10.00,
        totalPrice: 50.00,
      );

      final sale = Sale(
        id: saleId,
        invoiceNumber: 'INV-TEST-001',
        totalAmount: 50.00,
        discount: 0,
        tax: 0,
        netAmount: 50.00,
        paymentMethod: 'Cash',
        saleDate: '2026-07-22T12:00:00Z',
        items: [saleItem],
      );

      // 3. Process Sale
      await dbHelper.insertSale(sale);

      // 4. Verify stock reduced
      final updatedMed = await dbHelper.getMedicineById('med-s-1');
      expect(updatedMed!.currentStock, 95);

      // 5. Verify sale history matches
      final fetchedSale = await dbHelper.getSaleById(saleId);
      expect(fetchedSale, isNotNull);
      expect(fetchedSale!.invoiceNumber, 'INV-TEST-001');
      expect(fetchedSale.items.length, 1);
      expect(fetchedSale.items[0].quantity, 5);

      // Verification complete; table cleanup is handled automatically in setUp
    });
  });
}
