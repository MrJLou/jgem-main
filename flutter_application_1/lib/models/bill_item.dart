class BillItem {
  final int? id;
  final String billId;
  final String? serviceId;
  final String description; // Service name or custom item
  final int quantity;
  final double unitPrice;
  final double itemTotal; // quantity * unitPrice

  BillItem({
    this.id,
    required this.billId,
    this.serviceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotal,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] as int?,
      billId: json['billId'] as String? ?? '',
      serviceId: json['serviceId'] as String?,
      description: json['description'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      itemTotal: (json['itemTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'billId': billId,
      'serviceId': serviceId,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'itemTotal': itemTotal,
    };
  }
}
