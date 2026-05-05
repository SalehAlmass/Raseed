class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String? company;
  final int? categoryId;
  final double rating;
  final double totalDebt; // Money we owe to the supplier
  final double totalPaid; // Total money paid to the supplier
  final DateTime? lastTransactionDate;

  Supplier({
    this.id,
    required this.name,
    required this.phone,
    this.company,
    this.categoryId,
    this.rating = 0.0,
    this.totalDebt = 0.0,
    this.totalPaid = 0.0,
    this.lastTransactionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'company': company,
      'category_id': categoryId,
      'rating': rating,
      'total_debt': totalDebt,
      'total_paid': totalPaid,
      'last_transaction_date': lastTransactionDate?.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      company: map['company'],
      categoryId: map['category_id'],
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['total_paid'] as num?)?.toDouble() ?? 0.0,
      lastTransactionDate: map['last_transaction_date'] != null
          ? DateTime.parse(map['last_transaction_date'])
          : null,
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? company,
    int? categoryId,
    double? rating,
    double? totalDebt,
    double? totalPaid,
    DateTime? lastTransactionDate,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      categoryId: categoryId ?? this.categoryId,
      rating: rating ?? this.rating,
      totalDebt: totalDebt ?? this.totalDebt,
      totalPaid: totalPaid ?? this.totalPaid,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
