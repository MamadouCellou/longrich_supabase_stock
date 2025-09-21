class PurchaseItem {
  final String? id;
  final String? purchaseId; // lien vers la commande
  final String productId;
  final String productName;
  final double unitPrice;
  final double unitPv;
  final int quantityTotal;
  final int quantityReceived;
  final int quantityMissing;

  PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.unitPv,
    required this.quantityTotal,
    required this.quantityReceived,
    required this.quantityMissing,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as String?,
      purchaseId: map['purchase_id'] as String?,
      productId: map['product_id'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      unitPv: (map['unit_pv'] as num?)?.toDouble() ?? 0,
      quantityTotal: map['quantity_total'] as int? ?? 0,
      quantityReceived: map['quantity_received'] as int? ?? 0,
      quantityMissing: map['quantity_missing'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null && id!.trim().isNotEmpty) 'id': id,
      if (purchaseId != null) 'purchase_id': purchaseId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'unit_pv': unitPv,
      'quantity_total': quantityTotal,
      'quantity_received': quantityReceived,
      'quantity_missing': quantityMissing,
    };
  }

  PurchaseItem copyWith({
    String? id,
    String? purchaseId,
    String? productId,
    String? productName,
    double? unitPrice,
    double? unitPv,
    int? quantityTotal,
    int? quantityReceived,
    int? quantityMissing,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      unitPv: unitPv ?? this.unitPv,
      quantityTotal: quantityTotal ?? this.quantityTotal,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      quantityMissing: quantityMissing ?? this.quantityMissing,
    );
  }

  @override
  String toString() {
    return 'PurchaseItem{id: $id, purchaseId: $purchaseId, productId: $productId, '
        'productName: $productName, unitPrice: $unitPrice, unitPv: $unitPv, '
        'quantityTotal: $quantityTotal, quantityReceived: $quantityReceived, '
        'quantityMissing: $quantityMissing}';
  }
}
