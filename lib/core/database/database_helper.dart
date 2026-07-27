import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/medicine_model.dart';
import '../models/prescription_model.dart';
import '../models/sale_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pharmacy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // If running on Desktop (Windows or Linux), initialize FFI
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, 'pharmacy_system', filePath);
    
    // Ensure parent directory exists
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // 1. Medicines Table
    await db.execute('''
      CREATE TABLE medicines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        generic_name TEXT,
        category TEXT,
        manufacturer TEXT,
        purchase_price REAL,
        selling_price REAL NOT NULL,
        current_stock INTEGER NOT NULL DEFAULT 0,
        reorder_level INTEGER DEFAULT 10,
        batch_number TEXT,
        expiry_date TEXT,
        requires_prescription INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 2. Prescriptions Table
    await db.execute('''
      CREATE TABLE prescriptions (
        id TEXT PRIMARY KEY,
        prescription_number TEXT UNIQUE NOT NULL,
        patient_name TEXT NOT NULL,
        patient_phone TEXT,
        patient_age INTEGER,
        patient_gender TEXT,
        doctor_name TEXT,
        doctor_license TEXT,
        prescribed_date TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 3. Prescription Items Table
    await db.execute('''
      CREATE TABLE prescription_items (
        id TEXT PRIMARY KEY,
        prescription_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        dosage TEXT,
        frequency TEXT,
        duration TEXT,
        quantity INTEGER NOT NULL,
        dispensed INTEGER DEFAULT 0,
        FOREIGN KEY (prescription_id) REFERENCES prescriptions(id) ON DELETE CASCADE,
        FOREIGN KEY (medicine_id) REFERENCES medicines(id)
      )
    ''');

    // 4. Sales Table
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        invoice_number TEXT UNIQUE NOT NULL,
        prescription_id TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        total_amount REAL NOT NULL,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        net_amount REAL NOT NULL,
        payment_method TEXT,
        sale_date TEXT NOT NULL,
        status TEXT DEFAULT 'completed',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (prescription_id) REFERENCES prescriptions(id)
      )
    ''');

    // 5. Sales Items Table
    await db.execute('''
      CREATE TABLE sales_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY (medicine_id) REFERENCES medicines(id)
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_medicines_name ON medicines(name)');
    await db.execute('CREATE INDEX idx_prescriptions_number ON prescriptions(prescription_number)');
    await db.execute('CREATE INDEX idx_sales_invoice_number ON sales(invoice_number)');
    await db.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');
  }

  // --- Transactions ---
  Transaction? _activeTransaction;

  Future<void> beginTransaction() async {
    // Note: sqflite supports nested transactions or batch internally.
    // For standard manual control, we run db.transaction() but sqflite usually
    // wraps transaction callbacks. We'll implement helper callbacks, or use the db object.
  }

  Future<void> commitTransaction() async {
    // Handled automatically by sqflite when the transaction block completes successfully.
  }

  Future<void> rollbackTransaction() async {
    // Handled automatically by throwing an exception inside sqflite transaction blocks.
  }

  // --- MEDICINES CRUD ---

  Future<int> insertMedicine(Medicine medicine) async {
    final db = await instance.database;
    return await db.insert('medicines', medicine.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateMedicine(Medicine medicine) async {
    final db = await instance.database;
    return await db.update(
      'medicines',
      medicine.toJson(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(String id) async {
    final db = await instance.database;
    return await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Medicine>> getMedicines() async {
    final db = await instance.database;
    final result = await db.query('medicines', orderBy: 'name ASC');
    return result.map((json) => Medicine.fromJson(json)).toList();
  }

  Future<Medicine?> getMedicineById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Medicine.fromJson(result.first);
    }
    return null;
  }

  Future<List<Medicine>> searchMedicines(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'medicines',
      where: 'name LIKE ? OR generic_name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((json) => Medicine.fromJson(json)).toList();
  }

  Future<List<Medicine>> getLowStockMedicines() async {
    final db = await instance.database;
    final result = await db.query(
      'medicines',
      where: 'current_stock <= reorder_level AND is_active = 1',
      orderBy: 'current_stock ASC',
    );
    return result.map((json) => Medicine.fromJson(json)).toList();
  }

  Future<void> updateStock(String medicineId, int quantityChange) async {
    final db = await instance.database;
    await db.execute(
      'UPDATE medicines SET current_stock = current_stock + ? WHERE id = ?',
      [quantityChange, medicineId],
    );
  }

  // --- PRESCRIPTIONS CRUD ---

  Future<int> insertPrescription(Prescription prescription) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final res = await txn.insert('prescriptions', prescription.toJson());
      for (final item in prescription.items) {
        await txn.insert('prescription_items', item.toJson());
      }
      return res;
    });
  }

  Future<int> updatePrescription(Prescription prescription) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final res = await txn.update(
        'prescriptions',
        prescription.toJson(),
        where: 'id = ?',
        whereArgs: [prescription.id],
      );
      
      // Delete old items and insert new ones
      await txn.delete('prescription_items', where: 'prescription_id = ?', whereArgs: [prescription.id]);
      for (final item in prescription.items) {
        await txn.insert('prescription_items', item.toJson());
      }
      return res;
    });
  }

  Future<int> deletePrescription(String id) async {
    final db = await instance.database;
    return await db.delete(
      'prescriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Prescription>> getPrescriptions() async {
    final db = await instance.database;
    final rxList = await db.query('prescriptions', orderBy: 'prescribed_date DESC');
    
    final List<Prescription> prescriptions = [];
    for (final rxJson in rxList) {
      final id = rxJson['id'] as String;
      final itemsResult = await db.query('prescription_items', where: 'prescription_id = ?', whereArgs: [id]);
      
      final List<PrescriptionItem> items = [];
      for (final itemJson in itemsResult) {
        final medicineId = itemJson['medicine_id'] as String;
        final medicine = await getMedicineById(medicineId);
        items.add(PrescriptionItem.fromJson(itemJson, medicine: medicine));
      }
      prescriptions.add(Prescription.fromJson(rxJson, items: items));
    }
    return prescriptions;
  }

  Future<Prescription?> getPrescriptionById(String id) async {
    final db = await instance.database;
    final rxList = await db.query('prescriptions', where: 'id = ?', whereArgs: [id]);
    if (rxList.isEmpty) return null;
    
    final itemsResult = await db.query('prescription_items', where: 'prescription_id = ?', whereArgs: [id]);
    final List<PrescriptionItem> items = [];
    for (final itemJson in itemsResult) {
      final medicineId = itemJson['medicine_id'] as String;
      final medicine = await getMedicineById(medicineId);
      items.add(PrescriptionItem.fromJson(itemJson, medicine: medicine));
    }
    return Prescription.fromJson(rxList.first, items: items);
  }

  // --- SALES CRUD ---

  Future<int> insertSale(Sale sale) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final res = await txn.insert('sales', sale.toJson());
      for (final item in sale.items) {
        await txn.insert('sales_items', item.toJson());
        // Deduct inventory stock
        await txn.execute(
          'UPDATE medicines SET current_stock = current_stock - ? WHERE id = ?',
          [item.quantity, item.medicineId],
        );
      }
      
      // If sale has a prescription_id associated, change the prescription status to 'completed'
      if (sale.prescriptionId != null && sale.prescriptionId!.isNotEmpty) {
        await txn.update(
          'prescriptions',
          {'status': 'completed'},
          where: 'id = ?',
          whereArgs: [sale.prescriptionId],
        );
        await txn.execute(
          'UPDATE prescription_items SET dispensed = 1 WHERE prescription_id = ?',
          [sale.prescriptionId],
        );
      }
      return res;
    });
  }

  Future<int> updateSale(Sale sale) async {
    final db = await instance.database;
    return await db.update(
      'sales',
      sale.toJson(),
      where: 'id = ?',
      whereArgs: [sale.id],
    );
  }

  Future<List<Sale>> getSales() async {
    final db = await instance.database;
    final salesList = await db.query('sales', orderBy: 'sale_date DESC');
    
    final List<Sale> sales = [];
    for (final saleJson in salesList) {
      final id = saleJson['id'] as String;
      final itemsList = await getSaleItems(id);
      sales.add(Sale.fromJson(saleJson, items: itemsList));
    }
    return sales;
  }

  Future<Sale?> getSaleById(String id) async {
    final db = await instance.database;
    final salesList = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    if (salesList.isEmpty) return null;
    
    final itemsList = await getSaleItems(id);
    return Sale.fromJson(salesList.first, items: itemsList);
  }

  Future<List<Sale>> getTodaySales() async {
    final db = await instance.database;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final salesList = await db.query(
      'sales',
      where: 'sale_date LIKE ?',
      whereArgs: ['$todayStr%'],
      orderBy: 'sale_date DESC',
    );
    
    final List<Sale> sales = [];
    for (final saleJson in salesList) {
      final id = saleJson['id'] as String;
      final itemsList = await getSaleItems(id);
      sales.add(Sale.fromJson(saleJson, items: itemsList));
    }
    return sales;
  }

  Future<List<Sale>> getSalesByDateRange(String startDate, String endDate) async {
    final db = await instance.database;
    final salesList = await db.query(
      'sales',
      where: 'sale_date >= ? AND sale_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'sale_date DESC',
    );
    
    final List<Sale> sales = [];
    for (final saleJson in salesList) {
      final id = saleJson['id'] as String;
      final itemsList = await getSaleItems(id);
      sales.add(Sale.fromJson(saleJson, items: itemsList));
    }
    return sales;
  }

  Future<int> insertSaleItem(SaleItem item) async {
    final db = await instance.database;
    return await db.insert('sales_items', item.toJson());
  }

  Future<List<SaleItem>> getSaleItems(String saleId) async {
    final db = await instance.database;
    final result = await db.query('sales_items', where: 'sale_id = ?', whereArgs: [saleId]);
    
    final List<SaleItem> items = [];
    for (final itemJson in result) {
      final medicineId = itemJson['medicine_id'] as String;
      final medicine = await getMedicineById(medicineId);
      items.add(SaleItem.fromJson(itemJson, medicine: medicine));
    }
    return items;
  }

  Future<void> close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}
