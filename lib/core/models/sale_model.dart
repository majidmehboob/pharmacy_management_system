import 'medicine_model.dart';

class CartItem {
  final Medicine medicine;
  final int quantity;
  final double unitPrice;

  CartItem({
    required this.medicine,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  CartItem copyWith({
    Medicine? medicine,
    int? quantity,
    double? unitPrice,
  }) {
    return CartItem(
      medicine: medicine ?? this.medicine,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

class SaleState {
  final List<CartItem> cartItems;
  final double discount; // percentage
  final double tax; // percentage
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final double tenderedAmount;
  final String? prescriptionId;
  final String? insurancePolicyNumber;
  final String? cardType;

  SaleState({
    this.cartItems = const [],
    this.discount = 0.0,
    this.tax = 0.0,
    this.customerName = '',
    this.customerPhone = '',
    this.paymentMethod = 'Cash',
    this.tenderedAmount = 0.0,
    this.prescriptionId,
    this.insurancePolicyNumber,
    this.cardType,
  });

  double get subtotal => cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get totalDiscount => subtotal * (discount / 100);
  double get taxableAmount => subtotal - totalDiscount;
  double get taxAmount => taxableAmount * (tax / 100);
  double get netTotal => taxableAmount + taxAmount;
  double get changeAmount => tenderedAmount > netTotal ? tenderedAmount - netTotal : 0.0;

  SaleState copyWith({
    List<CartItem>? cartItems,
    double? discount,
    double? tax,
    String? customerName,
    String? customerPhone,
    String? paymentMethod,
    double? tenderedAmount,
    String? prescriptionId,
    String? insurancePolicyNumber,
    String? cardType,
  }) {
    return SaleState(
      cartItems: cartItems ?? this.cartItems,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tenderedAmount: tenderedAmount ?? this.tenderedAmount,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      insurancePolicyNumber: insurancePolicyNumber ?? this.insurancePolicyNumber,
      cardType: cardType ?? this.cardType,
    );
  }
}

class SaleItem {
  final String id;
  final String saleId;
  final String medicineId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final Medicine? medicine;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.medicineId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.medicine,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json, {Medicine? medicine}) {
    return SaleItem(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      medicineId: json['medicine_id'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      medicine: medicine,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_id': saleId,
      'medicine_id': medicineId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}

class Sale {
  final String id;
  final String invoiceNumber;
  final String? prescriptionId;
  final String? customerName;
  final String? customerPhone;
  final double totalAmount;
  final double discount;
  final double tax;
  final double netAmount;
  final String paymentMethod;
  final String saleDate;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final List<SaleItem> items;

  Sale({
    required this.id,
    required this.invoiceNumber,
    this.prescriptionId,
    this.customerName,
    this.customerPhone,
    required this.totalAmount,
    required this.discount,
    required this.tax,
    required this.netAmount,
    required this.paymentMethod,
    required this.saleDate,
    this.status = 'completed',
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory Sale.fromJson(Map<String, dynamic> json, {List<SaleItem> items = const []}) {
    return Sale(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      prescriptionId: json['prescription_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      discount: (json['discount'] as num? ?? 0).toDouble(),
      tax: (json['tax'] as num? ?? 0).toDouble(),
      netAmount: (json['net_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      saleDate: json['sale_date'] as String,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'prescription_id': prescriptionId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_amount': totalAmount,
      'discount': discount,
      'tax': tax,
      'net_amount': netAmount,
      'payment_method': paymentMethod,
      'sale_date': saleDate,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Sale copyWith({
    String? id,
    String? invoiceNumber,
    String? prescriptionId,
    String? customerName,
    String? customerPhone,
    double? totalAmount,
    double? discount,
    double? tax,
    double? netAmount,
    String? paymentMethod,
    String? saleDate,
    String? status,
    String? createdAt,
    String? updatedAt,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      netAmount: netAmount ?? this.netAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      saleDate: saleDate ?? this.saleDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}
