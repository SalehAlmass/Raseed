enum ShiftStatus {
  open,
  closed,
}

class Shift {
  final int? id;
  final int userId;
  final DateTime startTime;
  final DateTime? endTime;
  final double openingBalance;
  final double? closingBalanceSystem;
  final double? closingBalanceActual;
  final ShiftStatus status;

  Shift({
    this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.openingBalance,
    this.closingBalanceSystem,
    this.closingBalanceActual,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'opening_balance': openingBalance,
      'closing_balance_system': closingBalanceSystem,
      'closing_balance_actual': closingBalanceActual,
      'status': status.name,
    };
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map['id'],
      userId: map['user_id'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      openingBalance: (map['opening_balance'] as num).toDouble(),
      closingBalanceSystem: (map['closing_balance_system'] as num?)?.toDouble(),
      closingBalanceActual: (map['closing_balance_actual'] as num?)?.toDouble(),
      status: ShiftStatus.values.firstWhere((e) => e.name == map['status']),
    );
  }
}
