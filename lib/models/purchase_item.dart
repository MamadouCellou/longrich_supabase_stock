class PurchaseItem {
  final String id;
  final String productId;
  final String productName;
  final double unitPrice;
  final double unitPv;
  final int quantityTotal;
  final int quantityReceived;
  final int quantityMissing;

  PurchaseItem({
    required this.id,
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
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      unitPv: (map['unit_pv'] as num).toDouble(),
      quantityTotal: map['quantity_total'] as int,
      quantityReceived: map['quantity_received'] as int,
      quantityMissing: map['quantity_missing'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'unit_pv': unitPv,
      'quantity_total': quantityTotal,
      'quantity_received': quantityReceived,
      'quantity_missing': quantityMissing,
    };
  }
}
