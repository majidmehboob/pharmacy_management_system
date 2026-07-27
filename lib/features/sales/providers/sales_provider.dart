import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/medicine_model.dart';
import '../../../core/models/sale_model.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../prescription/providers/prescription_provider.dart';

class SalesNotifier extends StateNotifier<SaleState> {
  final DatabaseHelper _dbHelper;
  final Ref _ref;

  SalesNotifier(this._dbHelper, this._ref)
    : super(SaleState(tax: 5.0)); // Default tax e.g. 5%

  void addToCart(Medicine medicine, int quantity) {
    final existingIndex = state.cartItems.indexWhere(
      (item) => item.medicine.id == medicine.id,
    );

    // Check stock limit
    if (medicine.currentStock < quantity) {
      throw Exception('Insufficient stock available.');
    }

    List<CartItem> updatedItems;
    if (existingIndex >= 0) {
      final existingItem = state.cartItems[existingIndex];
      final newQty = existingItem.quantity + quantity;
      if (medicine.currentStock < newQty) {
        throw Exception('Insufficient stock available.');
      }
      updatedItems = List.from(state.cartItems);
      updatedItems[existingIndex] = existingItem.copyWith(quantity: newQty);
    } else {
      updatedItems = [
        ...state.cartItems,
        CartItem(
          medicine: medicine,
          quantity: quantity,
          unitPrice: medicine.sellingPrice,
        ),
      ];
    }
    state = state.copyWith(cartItems: updatedItems);
  }

  void removeFromCart(String medicineId) {
    state = state.copyWith(
      cartItems: state.cartItems
          .where((item) => item.medicine.id != medicineId)
          .toList(),
    );
  }

  void updateQuantity(String medicineId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(medicineId);
      return;
    }
    final index = state.cartItems.indexWhere(
      (item) => item.medicine.id == medicineId,
    );
    if (index >= 0) {
      final item = state.cartItems[index];
      if (item.medicine.currentStock < quantity) {
        throw Exception('Insufficient stock available.');
      }
      final List<CartItem> updatedItems = List.from(state.cartItems);
      updatedItems[index] = item.copyWith(quantity: quantity);
      state = state.copyWith(cartItems: updatedItems);
    }
  }

  void clearCart() {
    state = SaleState(tax: 5.0); // Reset to empty cart state with default tax
  }

  void setDiscount(double discount) {
    if (discount < 0 || discount > 100) {
      throw Exception('Discount must be between 0 and 100');
    }
    state = state.copyWith(discount: discount);
  }

  void setTax(double tax) {
    if (tax < 0 || tax > 100) {
      throw Exception('Tax must be between 0 and 100');
    }
    state = state.copyWith(tax: tax);
  }

  void setCustomer(String name, String phone) {
    state = state.copyWith(customerName: name, customerPhone: phone);
  }

  void setPrescriptionId(String? rxId) {
    state = state.copyWith(prescriptionId: rxId);
  }

  void setPaymentDetails(
    String method,
    double tendered, {
    String? policyNumber,
    String? cardType,
  }) {
    state = state.copyWith(
      paymentMethod: method,
      tenderedAmount: tendered,
      insurancePolicyNumber: policyNumber,
      cardType: cardType,
    );
  }

  Future<Sale> processSale() async {
    if (state.cartItems.isEmpty) {
      throw Exception('Cart cannot be empty');
    }
    for (final item in state.cartItems) {
      if (item.quantity <= 0) {
        throw Exception('All items must have quantity > 0');
      }
    }
    if (state.paymentMethod.isEmpty) {
      throw Exception('Payment method must be selected');
    }
    if (state.paymentMethod == 'Insurance' &&
        state.customerName.trim().isEmpty) {
      throw Exception('Customer name required if using insurance');
    }

    final saleId = const Uuid().v4();
    final now = DateTime.now();

    // Generate invoice number e.g. INV-YYYYMMDD-XXXX
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomSuffix = const Uuid().v4().substring(0, 4).toUpperCase();
    final invoiceNumber = 'INV-$dateStr-$randomSuffix';

    final sale = Sale(
      id: saleId,
      invoiceNumber: invoiceNumber,
      prescriptionId: state.prescriptionId,
      customerName: state.customerName.isEmpty
          ? 'Walk-in Customer'
          : state.customerName,
      customerPhone: state.customerPhone,
      totalAmount: state.subtotal,
      discount: state.discount,
      tax: state.tax,
      netAmount: state.netTotal,
      paymentMethod: state.paymentMethod,
      saleDate: now.toIso8601String(),
      status: 'completed',
      items: state.cartItems.map((cartItem) {
        return SaleItem(
          id: const Uuid().v4(),
          saleId: saleId,
          medicineId: cartItem.medicine.id,
          quantity: cartItem.quantity,
          unitPrice: cartItem.unitPrice,
          totalPrice: cartItem.totalPrice,
        );
      }).toList(),
    );

    // Save to Database
    await _dbHelper.insertSale(sale);

    // Refresh other providers
    await _ref.read(inventoryProvider.notifier).loadMedicines();
    await _ref.read(prescriptionProvider.notifier).loadPrescriptions();

    // Clear checkout cart
    clearCart();

    return sale;
  }

  // --- QUERY METHODS ---

  Future<List<Sale>> getSalesHistory() async {
    return await _dbHelper.getSales();
  }

  Future<Sale?> getSaleById(String id) async {
    return await _dbHelper.getSaleById(id);
  }

  Future<List<Sale>> getTodaySales() async {
    return await _dbHelper.getTodaySales();
  }

  Future<double> getTotalSales() async {
    final sales = await _dbHelper.getSales();

    double total = 0.0;

    for (final sale in sales) {
      total +=  sale.netAmount;
    }

    return total;
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, SaleState>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SalesNotifier(dbHelper, ref);
});
