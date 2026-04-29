class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String? company;
  final double totalDebt; // Money we owe to the supplier
  final DateTime? lastTransactionDate;

  Supplier({
    this.id,
    required this.name,
    required this.phone,
    this.company,
    this.totalDebt = 0.0,
    this.lastTransactionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'company': company,
      'total_debt': totalDebt,
      'last_transaction_date': lastTransactionDate?.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      company: map['company'],
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0.0,
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
    double? totalDebt,
    DateTime? lastTransactionDate,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      totalDebt: totalDebt ?? this.totalDebt,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }
}
