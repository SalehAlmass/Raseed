enum AccountType { asset, liability, equity, revenue, expense }

class Account {
  final int? id;
  final String code;
  final String name;
  final AccountType type;
  final int? parentId;
  final double balance;

  Account({
    this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.balance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'type': type.name,
      'parent_id': parentId,
      'balance': balance,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      code: map['code'],
      name: map['name'],
      type: AccountType.values.byName(map['type']),
      parentId: map['parent_id'],
      balance: map['balance']?.toDouble() ?? 0.0,
    );
  }
}
