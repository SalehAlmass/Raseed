class DiscountCode {
  final int? id;
  final String code;
  final String discountType; // percentage, fixed
  final double discountValue;
  final double minPurchase;
  final int maxUses;
  final int currentUses;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool active;
  final DateTime createdAt;

  DiscountCode({
    this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minPurchase = 0,
    this.maxUses = 0,
    this.currentUses = 0,
    this.validFrom,
    this.validTo,
    this.active = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_purchase': minPurchase,
      'max_uses': maxUses,
      'current_uses': currentUses,
      'valid_from': validFrom?.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DiscountCode.fromMap(Map<String, dynamic> map) {
    return DiscountCode(
      id: map['id'],
      code: map['code'],
      discountType: map['discount_type'],
      discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0.0,
      minPurchase: (map['min_purchase'] as num?)?.toDouble() ?? 0.0,
      maxUses: map['max_uses'] ?? 0,
      currentUses: map['current_uses'] ?? 0,
      validFrom: map['valid_from'] != null ? DateTime.parse(map['valid_from']) : null,
      validTo: map['valid_to'] != null ? DateTime.parse(map['valid_to']) : null,
      active: map['active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  bool get isValid {
    if (!active) return false;
    if (maxUses > 0 && currentUses >= maxUses) return false;
    if (validFrom != null && DateTime.now().isBefore(validFrom!)) return false;
    if (validTo != null && DateTime.now().isAfter(validTo!)) return false;
    return true;
  }

  double applyDiscount(double subtotal) {
    if (subtotal < minPurchase) return 0;
    if (discountType == 'percentage') return subtotal * discountValue / 100;
    if (discountType == 'fixed') return discountValue.clamp(0, subtotal);
    return 0;
  }

  DiscountCode copyWith({
    int? id,
    String? code,
    String? discountType,
    double? discountValue,
    double? minPurchase,
    int? maxUses,
    int? currentUses,
    DateTime? validFrom,
    DateTime? validTo,
    bool? active,
    DateTime? createdAt,
  }) {
    return DiscountCode(
      id: id ?? this.id,
      code: code ?? this.code,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      minPurchase: minPurchase ?? this.minPurchase,
      maxUses: maxUses ?? this.maxUses,
      currentUses: currentUses ?? this.currentUses,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
