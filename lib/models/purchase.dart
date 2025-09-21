class Purchase {
  final String? id;
  final String buyerName;
  final String paymentMethod;
  final String gn;
  final String purchaseType;
  final DateTime? createdAt;

  /// Ajout des champs de totaux
  final double totalAmount;
  final double totalPv;

  Purchase({
    this.id,
    required this.buyerName,
    required this.paymentMethod,
    required this.gn,
    required this.purchaseType,
    this.createdAt,
    this.totalAmount = 0.0,
    this.totalPv = 0.0,
  });

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: (map['id'] as String?)?.isNotEmpty == true ? map['id'] as String : null,
      buyerName: map['buyer_name'] as String,
      paymentMethod: map['payment_method'] as String,
      gn: map['gn'] as String,
      purchaseType: map['purchase_type'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,

      /// Important : récupérer correctement depuis la DB
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalPv: (map['total_pv'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null && id!.trim().isNotEmpty) 'id': id,
      'buyer_name': buyerName,
      'payment_method': paymentMethod,
      'gn': gn,
      'purchase_type': purchaseType,
      'created_at': createdAt?.toIso8601String(),

      /// Important : sauver aussi les totaux
      'total_amount': totalAmount,
      'total_pv': totalPv,
    };
  }

  @override
  String toString() {
    return "Purchase{id: $id, buyerName: $buyerName, paymentMethod: $paymentMethod, gn: $gn, purchaseType: $purchaseType, createdAt: $createdAt, totalAmount: $totalAmount, totalPv: $totalPv}";
  }
}
