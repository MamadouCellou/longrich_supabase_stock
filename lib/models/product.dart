class Product {
  final String id;
  final String name;
  final String? sku;
  final double pricePartner;
  final double pv;
  final String? description;
  final int stock;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    this.sku,
    required this.pricePartner,
    required this.pv,
    this.description,
    required this.stock,
    this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      sku: map['sku'] as String?,
      pricePartner: (map['price_partner'] as num).toDouble(),
      pv: (map['pv'] as num).toDouble(),
      description: map['description'] as String?,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'price_partner': pricePartner,
      'pv': pv,
      'description': description,
      'stock': stock,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
