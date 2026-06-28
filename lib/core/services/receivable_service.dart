import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/installment_plan.dart';

class ReceivableService {
  final _dbHelper = DatabaseHelper.instance;

  Future<List<InstallmentPlan>> getAllPlans() async {
    final db = await _dbHelper.database;
    final maps = await db.query('installment_plans', orderBy: 'start_date DESC');
    final plans = <InstallmentPlan>[];
    for (var map in maps) {
      final id = map['id'] as int;
      final payments = await _getPayments(db, id);
      plans.add(InstallmentPlan.fromMap(map, payments: payments));
    }
    return plans;
  }

  Future<List<InstallmentPlan>> getPlansByCustomer(int customerId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('installment_plans',
      where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'start_date DESC');
    final plans = <InstallmentPlan>[];
    for (var map in maps) {
      final id = map['id'] as int;
      final payments = await _getPayments(db, id);
      plans.add(InstallmentPlan.fromMap(map, payments: payments));
    }
    return plans;
  }

  Future<InstallmentPlan?> getPlanById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('installment_plans', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final payments = await _getPayments(db, id);
    return InstallmentPlan.fromMap(maps.first, payments: payments);
  }

  Future<int> createPlan(InstallmentPlan plan) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final planId = await txn.insert('installment_plans', plan.toMap());
      for (int i = 0; i < plan.installmentCount; i++) {
        await txn.insert('installment_payments', {
          'plan_id': planId,
          'amount': plan.installmentAmount,
          'due_date': plan.startDate.add(Duration(days: plan.periodDays * (i + 1))).toIso8601String(),
          'status': 'pending',
        });
      }
      return planId;
    });
  }

  Future<void> markPaymentPaid(int paymentId, {double? lateFee, String? note}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('installment_payments', {
        'status': 'paid',
        'paid_date': DateTime.now().toIso8601String(),
        if (lateFee != null) 'late_fee': lateFee,
        if (note != null) 'note': note,
      }, where: 'id = ?', whereArgs: [paymentId]);

      final payMap = await txn.query('installment_payments', where: 'id = ?', whereArgs: [paymentId]);
      if (payMap.isNotEmpty) {
        final planId = payMap.first['plan_id'];
        final allPaid = await txn.query('installment_payments',
          where: 'plan_id = ? AND status != ?', whereArgs: [planId, 'paid']);
        if (allPaid.isEmpty) {
          await txn.update('installment_plans', {'status': 'completed', 'remaining': 0},
            where: 'id = ?', whereArgs: [planId]);
        } else {
          final paidTotal = await txn.rawQuery(
            "SELECT COALESCE(SUM(amount + late_fee), 0) as total FROM installment_payments WHERE plan_id = ? AND status = 'paid'",
            [planId]);
          final paid = (paidTotal.first['total'] as num?)?.toDouble() ?? 0.0;
          final planMap = await txn.query('installment_plans', where: 'id = ?', whereArgs: [planId]);
          if (planMap.isNotEmpty) {
            final total = (planMap.first['total_amount'] as num?)?.toDouble() ?? 0.0;
            await txn.update('installment_plans', {'remaining': (total - paid).clamp(0, total)},
              where: 'id = ?', whereArgs: [planId]);
          }
        }
      }
    });
  }

  Future<void> updateOverdueStatus() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.execute(
      "UPDATE installment_payments SET status = 'late' WHERE status = 'pending' AND due_date < ?",
      [now],
    );
    final latePlans = await db.rawQuery('''
      SELECT DISTINCT plan_id FROM installment_payments 
      WHERE status = 'late' AND plan_id IN (SELECT id FROM installment_plans WHERE status = 'active')
    ''');
    for (var p in latePlans) {
      await db.update('installment_plans', {'status': 'defaulted'},
        where: 'id = ? AND status = ?', whereArgs: [p['plan_id'], 'active']);
    }
  }

  Future<List<InstallmentPlan>> getOverduePlans() async {
    await updateOverdueStatus();
    final all = await getAllPlans();
    return all.where((p) => p.status == 'defaulted' || p.isOverdue).toList();
  }

  Future<List<InstallmentPayment>> _getPayments(dynamic db, int planId) async {
    final maps = await db.query('installment_payments',
      where: 'plan_id = ?', whereArgs: [planId], orderBy: 'due_date ASC');
    return maps.map((m) => InstallmentPayment.fromMap(m)).toList();
  }
}
