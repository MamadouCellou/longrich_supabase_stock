class Purchase {
  final String? id;
  final String buyerName;
  final String paymentMethod;
  final String gn;
  final String purchaseType;

  /// 🔹 Suivi des dates
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 🔹 Champs de totaux
  final double totalAmount;
  final double totalPv;

  /// 🔹 Nouveaux champs
  final String? comment;
  bool positioned;
  bool validated;

  Purchase({
    this.id,
    required this.buyerName,
    required this.paymentMethod,
    required this.gn,
    required this.purchaseType,
    this.createdAt,
    this.updatedAt,
    this.totalAmount = 0.0,
    this.totalPv = 0.0,
    this.comment,
    this.positioned = false,
    this.validated = false,
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
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalPv: (map['total_pv'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment'] as String?,
      positioned: map['positioned'] as bool? ?? false,
      validated: map['validated'] as bool? ?? false,
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
      'updated_at': updatedAt?.toIso8601String(),
      'total_amount': totalAmount,
      'total_pv': totalPv,
      'comment': comment,
      'positioned': positioned,
      'validated': validated,
    };
  }

  @override
  String toString() {
    return "Purchase{id: $id, buyerName: $buyerName, paymentMethod: $paymentMethod, gn: $gn, purchaseType: $purchaseType, createdAt: $createdAt, updatedAt: $updatedAt, totalAmount: $totalAmount, totalPv: $totalPv, comment: $comment, positioned: $positioned, validated: $validated}";
  }
}
