class Customer {
  final int? id;
  final String name;
  final String phone;
  final double totalDebt;
  final double totalSpent;
  final DateTime? lastTransactionDate;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.totalDebt = 0.0,
    this.totalSpent = 0.0,
    this.lastTransactionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'total_debt': totalDebt,
      'total_spent': totalSpent,
      'last_transaction_date': lastTransactionDate?.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      lastTransactionDate: map['last_transaction_date'] != null 
        ? DateTime.parse(map['last_transaction_date']) 
        : null,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    double? totalDebt,
    double? totalSpent,
    DateTime? lastTransactionDate,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalDebt: totalDebt ?? this.totalDebt,
      totalSpent: totalSpent ?? this.totalSpent,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }
}
