class Medicine {
  final String id;
  final String name;
  final String? genericName;
  final String? category;
  final String? manufacturer;
  final double? purchasePrice;
  final double sellingPrice;
  final int currentStock;
  final int reorderLevel;
  final String? batchNumber;
  final String? expiryDate;
  final bool requiresPrescription;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  Medicine({
    required this.id,
    required this.name,
    this.genericName,
    this.category,
    this.manufacturer,
    this.purchasePrice,
    required this.sellingPrice,
    this.currentStock = 0,
    this.reorderLevel = 10,
    this.batchNumber,
    this.expiryDate,
    this.requiresPrescription = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String,
      genericName: json['generic_name'] as String?,
      category: json['category'] as String?,
      manufacturer: json['manufacturer'] as String?,
      purchasePrice: json['purchase_price'] != null ? (json['purchase_price'] as num).toDouble() : null,
      sellingPrice: (json['selling_price'] as num).toDouble(),
      currentStock: json['current_stock'] as int? ?? 0,
      reorderLevel: json['reorder_level'] as int? ?? 10,
      batchNumber: json['batch_number'] as String?,
      expiryDate: json['expiry_date'] as String?,
      requiresPrescription: (json['requires_prescription'] as int? ?? 0) == 1,
      isActive: (json['is_active'] as int? ?? 1) == 1,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'generic_name': genericName,
      'category': category,
      'manufacturer': manufacturer,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'current_stock': currentStock,
      'reorder_level': reorderLevel,
      'batch_number': batchNumber,
      'expiry_date': expiryDate,
      'requires_prescription': requiresPrescription ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Medicine copyWith({
    String? id,
    String? name,
    String? genericName,
    String? category,
    String? manufacturer,
    double? purchasePrice,
    double? sellingPrice,
    int? currentStock,
    int? reorderLevel,
    String? batchNumber,
    String? expiryDate,
    bool? requiresPrescription,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      requiresPrescription: requiresPrescription ?? this.requiresPrescription,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool isLowStock() {
    return currentStock <= reorderLevel;
  }

  bool isExpired() {
    if (expiryDate == null || expiryDate!.isEmpty) return false;
    try {
      final expiry = DateTime.parse(expiryDate!);
      final today = DateTime.now();
      return expiry.isBefore(DateTime(today.year, today.month, today.day));
    } catch (_) {
      return false;
    }
  }

  String getStatus() {
    if (!isActive) return 'Discontinued';
    if (isExpired()) return 'Expired';
    if (currentStock == 0) return 'Out of Stock';
    if (isLowStock()) return 'Low Stock';
    return 'In Stock';
  }
}
