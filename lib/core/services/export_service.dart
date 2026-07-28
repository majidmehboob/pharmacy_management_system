import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/medicine_model.dart';
import '../models/prescription_model.dart';
import '../models/sale_model.dart';

class ExportService {
  static Future<File> exportInventoryToCSV(List<Medicine> medicines) async {
    final buffer = StringBuffer();
    buffer.writeln('ID,Name,Generic Name,Category,Manufacturer,Purchase Price,Selling Price,Current Stock,Reorder Level,Batch Number,Expiry Date,Status');

    for (final m in medicines) {
      buffer.writeln(
        '"${m.id}","${m.name}","${m.genericName ?? ""}","${m.category ?? ""}","${m.manufacturer ?? ""}",'
        '${m.purchasePrice ?? 0},${m.sellingPrice},${m.currentStock},${m.reorderLevel},'
        '"${m.batchNumber ?? ""}","${m.expiryDate ?? ""}","${m.getStatus()}"'
      );
    }

    return await _saveCSVFile('inventory_export', buffer.toString());
  }

  static Future<File> exportPrescriptionsToCSV(List<Prescription> prescriptions) async {
    final buffer = StringBuffer();
    buffer.writeln('Prescription #,Patient Name,Patient Phone,Patient Age,Gender,Doctor Name,Prescribed Date,Status,Items Count,Notes');

    for (final rx in prescriptions) {
      buffer.writeln(
        '"${rx.prescriptionNumber}","${rx.patientName}","${rx.patientPhone ?? ""}","${rx.patientAge ?? ""}","${rx.patientGender ?? ""}",'
        '"${rx.doctorName ?? ""}","${rx.prescribedDate}","${rx.status}",${rx.items.length},"${rx.notes ?? ""}"'
      );
    }

    return await _saveCSVFile('prescriptions_export', buffer.toString());
  }

  static Future<File> exportSalesToCSV(List<Sale> sales) async {
    final buffer = StringBuffer();
    buffer.writeln('Invoice #,Customer Name,Customer Phone,Total Amount,Discount (%),Tax (%),Net Amount,Payment Method,Sale Date,Status');

    for (final s in sales) {
      buffer.writeln(
        '"${s.invoiceNumber}","${s.customerName ?? ""}","${s.customerPhone ?? ""}",'
        '${s.totalAmount},${s.discount},${s.tax},${s.netAmount},"${s.paymentMethod}","${s.saleDate}","${s.status}"'
      );
    }

    return await _saveCSVFile('sales_export', buffer.toString());
  }

  static Future<File> _saveCSVFile(String prefix, String content) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(join(docsDir.path, 'pharmacy_system', 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(join(exportDir.path, '${prefix}_$dateStr.csv'));
    await file.writeAsString(content);
    return file;
  }
}
