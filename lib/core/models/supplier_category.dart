class SupplierCategory {
  final int? id;
  final String name;
  final String? icon;

  SupplierCategory({
    this.id,
    required this.name,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }

  factory SupplierCategory.fromMap(Map<String, dynamic> map) {
    return SupplierCategory(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
