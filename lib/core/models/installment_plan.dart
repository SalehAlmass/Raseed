class InstallmentPayment {
  final int? id;
  final int planId;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String status; // pending, paid, late, missed
  final double lateFee;
  final String note;

  InstallmentPayment({
    this.id,
    required this.planId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    this.status = 'pending',
    this.lateFee = 0.0,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_id': planId,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'paid_date': paidDate?.toIso8601String(),
      'status': status,
      'late_fee': lateFee,
      'note': note,
    };
  }

  factory InstallmentPayment.fromMap(Map<String, dynamic> map) {
    return InstallmentPayment(
      id: map['id'],
      planId: map['plan_id'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(map['due_date']),
      paidDate: map['paid_date'] != null ? DateTime.parse(map['paid_date']) : null,
      status: map['status'] ?? 'pending',
      lateFee: (map['late_fee'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] ?? '',
    );
  }

  bool get isOverdue => status != 'paid' && DateTime.now().isAfter(dueDate);
}

class InstallmentPlan {
  final int? id;
  final int transactionId;
  final int customerId;
  final double totalAmount;
  final double downPayment;
  final double remaining;
  final double installmentAmount;
  final int installmentCount;
  final int periodDays;
  final DateTime startDate;
  final String status; // active, completed, defaulted
  final String notes;
  final List<InstallmentPayment> payments;

  InstallmentPlan({
    this.id,
    required this.transactionId,
    required this.customerId,
    required this.totalAmount,
    this.downPayment = 0,
    required this.remaining,
    required this.installmentAmount,
    required this.installmentCount,
    this.periodDays = 30,
    required this.startDate,
    this.status = 'active',
    this.notes = '',
    this.payments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'down_payment': downPayment,
      'remaining': remaining,
      'installment_amount': installmentAmount,
      'installment_count': installmentCount,
      'period_days': periodDays,
      'start_date': startDate.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  factory InstallmentPlan.fromMap(Map<String, dynamic> map, {List<InstallmentPayment> payments = const []}) {
    return InstallmentPlan(
      id: map['id'],
      transactionId: map['transaction_id'],
      customerId: map['customer_id'],
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      downPayment: (map['down_payment'] as num?)?.toDouble() ?? 0.0,
      remaining: (map['remaining'] as num?)?.toDouble() ?? 0.0,
      installmentAmount: (map['installment_amount'] as num?)?.toDouble() ?? 0.0,
      installmentCount: map['installment_count'] ?? 0,
      periodDays: map['period_days'] ?? 30,
      startDate: DateTime.parse(map['start_date']),
      status: map['status'] ?? 'active',
      notes: map['notes'] ?? '',
      payments: payments,
    );
  }

  double get totalPaid {
    return payments.where((p) => p.status == 'paid').fold(0.0, (sum, p) => sum + p.amount + p.lateFee);
  }

  int get paidCount => payments.where((p) => p.status == 'paid').length;
  int get overdueCount => payments.where((p) => p.isOverdue).length;
  bool get isOverdue => overdueCount > 0;

  List<InstallmentPayment> get schedule {
    if (payments.isNotEmpty) return payments;
    final list = <InstallmentPayment>[];
    for (int i = 0; i < installmentCount; i++) {
      list.add(InstallmentPayment(
        planId: id ?? 0,
        amount: installmentAmount,
        dueDate: startDate.add(Duration(days: periodDays * (i + 1))),
        status: 'pending',
      ));
    }
    return list;
  }
}
