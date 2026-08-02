import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/sale_model.dart';
import '../../inventory/providers/inventory_provider.dart';

class PrinterState {
  final String connectionType; // 'None', 'USB', 'BLE', 'Network'
  final String name;
  final String address;
  final int port;
  final int paperSize; // 58 or 80
  final bool autoPrint;
  final List<Printer> scannedPrinters;
  final bool isScanning;
  final bool isConnecting;
  final String? error;

  PrinterState({
    required this.connectionType,
    required this.name,
    required this.address,
    required this.port,
    required this.paperSize,
    required this.autoPrint,
    this.scannedPrinters = const [],
    this.isScanning = false,
    this.isConnecting = false,
    this.error,
  });

  PrinterState copyWith({
    String? connectionType,
    String? name,
    String? address,
    int? port,
    int? paperSize,
    bool? autoPrint,
    List<Printer>? scannedPrinters,
    bool? isScanning,
    bool? isConnecting,
    String? error,
  }) {
    return PrinterState(
      connectionType: connectionType ?? this.connectionType,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      paperSize: paperSize ?? this.paperSize,
      autoPrint: autoPrint ?? this.autoPrint,
      scannedPrinters: scannedPrinters ?? this.scannedPrinters,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
    );
  }
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  final DatabaseHelper _dbHelper;
  final _printerPlugin = FlutterThermalPrinter.instance;
  StreamSubscription<List<Printer>>? _devicesSubscription;

  PrinterNotifier(this._dbHelper)
      : super(PrinterState(
          connectionType: 'None',
          name: '',
          address: '',
          port: 9100,
          paperSize: 58,
          autoPrint: false,
        )) {
    _loadSettings();
    _devicesSubscription = _printerPlugin.devicesStream.listen((event) {
      if (mounted) {
        state = state.copyWith(scannedPrinters: event, isScanning: false);
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final configJson = await _dbHelper.getSetting('printer_settings');
      if (configJson != null) {
        final Map<String, dynamic> config = jsonDecode(configJson);
        if (mounted) {
          state = state.copyWith(
            connectionType: config['connectionType'] ?? 'None',
            name: config['name'] ?? '',
            address: config['address'] ?? '',
            port: config['port'] ?? 9100,
            paperSize: config['paperSize'] ?? 58,
            autoPrint: config['autoPrint'] ?? false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: 'Failed to load settings: $e');
      }
    }
  }

  Future<void> saveSettings({
    required String connectionType,
    required String name,
    required String address,
    required int port,
    required int paperSize,
    required bool autoPrint,
  }) async {
    if (mounted) {
      state = state.copyWith(
        connectionType: connectionType,
        name: name,
        address: address,
        port: port,
        paperSize: paperSize,
        autoPrint: autoPrint,
      );
    }

    final configJson = jsonEncode({
      'connectionType': connectionType,
      'name': name,
      'address': address,
      'port': port,
      'paperSize': paperSize,
      'autoPrint': autoPrint,
    });

    await _dbHelper.saveSetting('printer_settings', configJson);
  }

  void startScan() async {
    if (!mounted) return;
    state = state.copyWith(isScanning: true, scannedPrinters: [], error: null);
    try {
      final List<ConnectionType> types = [];
      if (state.connectionType == 'USB') {
        types.add(ConnectionType.USB);
      } else if (state.connectionType == 'BLE') {
        types.add(ConnectionType.BLE);
      } else {
        types.addAll([ConnectionType.USB, ConnectionType.BLE]);
      }
      await _printerPlugin.getPrinters(connectionTypes: types);
      
      // Auto-stop scanning after 10 seconds if no response
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && state.isScanning) {
          state = state.copyWith(isScanning: false);
        }
      });
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isScanning: false, error: e.toString());
      }
    }
  }

  Future<bool> printReceipt(Sale sale) async {
    if (state.connectionType == 'None') {
      if (mounted) {
        state = state.copyWith(error: 'No printer configured');
      }
      return false;
    }

    if (mounted) {
      state = state.copyWith(isConnecting: true, error: null);
    }

    try {
      // 1. Generate receipt bytes
      final bytes = await _generateReceiptBytes(sale, state.paperSize);

      // 2. Print depending on connection type
      if (state.connectionType == 'Network') {
        if (state.address.isEmpty) {
          throw Exception('Printer IP address is not configured');
        }
        final socket = await Socket.connect(state.address, state.port, timeout: const Duration(seconds: 5));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        if (mounted) {
          state = state.copyWith(isConnecting: false);
        }
        return true;
      } else {
        // USB or BLE
        Printer? targetPrinter;
        
        // Scan to find printer if not in list
        if (state.scannedPrinters.isEmpty) {
          final List<ConnectionType> types = state.connectionType == 'USB' 
              ? [ConnectionType.USB] 
              : [ConnectionType.BLE];
          await _printerPlugin.getPrinters(connectionTypes: types);
          // Wait briefly for discovery stream
          await Future.delayed(const Duration(seconds: 2));
        }

        for (final p in state.scannedPrinters) {
          if (p.address == state.address || p.name == state.name) {
            targetPrinter = p;
            break;
          }
        }

        if (targetPrinter == null) {
          throw Exception('Printer "${state.name}" not found. Please scan and configure again.');
        }

        final isConnected = await _printerPlugin.connect(targetPrinter);
        if (!isConnected) {
          throw Exception('Failed to connect to printer');
        }

        await _printerPlugin.printData(targetPrinter, bytes);
        if (mounted) {
          state = state.copyWith(isConnecting: false);
        }
        return true;
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isConnecting: false, error: e.toString());
      }
      return false;
    }
  }

  Future<List<int>> _generateReceiptBytes(Sale sale, int paperSize) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize == 80 ? PaperSize.mm80 : PaperSize.mm58, profile);
    List<int> bytes = [];

    // Initialize printer
    bytes += generator.reset();

    // 1. Header (Centered, Bold)
    bytes += generator.text(
      'COMMUNITY HEALTH PHARMACY',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text(
      '123 Healthcare Blvd, Medical District',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Phone: (555) 019-2834',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(1);

    // 2. Metadata (Left aligned)
    final date = DateTime.tryParse(sale.saleDate) ?? DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd hh:mm a').format(date);
    
    bytes += generator.text('Invoice: ${sale.invoiceNumber}');
    bytes += generator.text('Date: $formattedDate');
    bytes += generator.text('Customer: ${sale.customerName ?? "Walk-in"}');
    if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty) {
      bytes += generator.text('Phone: ${sale.customerPhone}');
    }
    bytes += generator.text('Payment: ${sale.paymentMethod}');
    bytes += generator.feed(1);

    // 3. Table Headers
    final cols = paperSize == 80 ? 48 : 32;
    final separator = '-' * cols;
    bytes += generator.text(separator);

    if (paperSize == 80) {
      // Columns (sum to 12): Description (6), Qty (2), Price (2), Total (2)
      bytes += generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.center, bold: true)),
        PosColumn(text: 'Price', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: 'Total', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    } else {
      // Columns (sum to 12): Description (5), Qty (2), Price (2), Total (3)
      bytes += generator.row([
        PosColumn(text: 'Item', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.center, bold: true)),
        PosColumn(text: 'Price', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: 'Total', width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }
    bytes += generator.text(separator);

    // 4. Sales Items
    for (final item in sale.items) {
      final name = item.medicine?.name ?? 'Unknown Medicine';
      final qty = item.quantity;
      final price = item.unitPrice;
      final total = item.totalPrice;

      if (paperSize == 80) {
        bytes += generator.row([
          PosColumn(text: name, width: 6),
          PosColumn(text: '$qty', width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: price.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: total.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
        ]);
      } else {
        bytes += generator.row([
          PosColumn(text: name, width: 5),
          PosColumn(text: '$qty', width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: price.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: total.toStringAsFixed(2), width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    }
    bytes += generator.text(separator);

    // 5. Summary (Right Aligned)
    final discountVal = sale.totalAmount * (sale.discount / 100);
    final taxVal = (sale.totalAmount - discountVal) * (sale.tax / 100);

    bytes += generator.text(
      'Subtotal: Rs. ${sale.totalAmount.toStringAsFixed(2)}',
      styles: const PosStyles(align: PosAlign.right),
    );
    if (sale.discount > 0) {
      bytes += generator.text(
        'Discount (${sale.discount.toStringAsFixed(0)}%): -Rs. ${discountVal.toStringAsFixed(2)}',
        styles: const PosStyles(align: PosAlign.right),
      );
    }
    if (sale.tax > 0) {
      bytes += generator.text(
        'Tax (${sale.tax.toStringAsFixed(0)}%): +Rs. ${taxVal.toStringAsFixed(2)}',
        styles: const PosStyles(align: PosAlign.right),
      );
    }
    bytes += generator.text(
      'Net Total: Rs. ${sale.netAmount.toStringAsFixed(2)}',
      styles: const PosStyles(align: PosAlign.right, bold: true),
    );
    bytes += generator.text(separator);

    // 6. Footer (Centered)
    bytes += generator.feed(1);
    bytes += generator.text(
      'Thank you for your business!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Please consult pharmacist for dosage guidance.',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    super.dispose();
  }
}

final printerProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return PrinterNotifier(dbHelper);
});
