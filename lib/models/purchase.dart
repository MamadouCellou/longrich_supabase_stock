class Purchase {
  final String id;
  final String buyerName;
  final String paymentMethod;
  final DateTime? createdAt;
  final double totalAmount;
  final double totalPv;

  Purchase({
    required this.id,
    required this.buyerName,
    required this.paymentMethod,
    this.createdAt,
    this.totalAmount = 0,
    this.totalPv = 0,
  });

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'] as String,
      buyerName: map['buyer_name'] as String,
      paymentMethod: map['payment_method'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      totalPv: (map['total_pv'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buyer_name': buyerName,
      'payment_method': paymentMethod,
      'created_at': createdAt?.toIso8601String(),
      'total_amount': totalAmount,
      'total_pv': totalPv,
    };
  }
}
