import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/expense.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';
import '../../../core/widgets/desktop/stat_card.dart';
import '../../../core/widgets/subscription_dialog.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _expenseService = sl<ExpenseService>();
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await _expenseService.getExpenses();
    setState(() {
      _expenses = expenses;
      _isLoading = false;
    });
  }

  Future<void> _openAddExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
    );
    if (result == true) {
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'expenses'.tr(),
      actions: [
        IconButton(
          onPressed: _loadExpenses,
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpense,
        label: Text('add_expense'.tr()),
        icon: const Icon(Icons.add),
      ),
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _expenses.isEmpty
            ? _buildEmptyState()
            : _buildExpenseList();
  }

  Widget _buildDesktopBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DesktopMetrics.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'expenses'.tr(),
                subtitle: '${_expenses.length}',
                actions: [
                  FilledButton.icon(
                    onPressed: _openAddExpense,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('add_expense'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopStats(),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopExpensesTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStats() {
    final double total = _expenses.fold(0, (sum, e) => sum + e.amount);
    return ResponsiveGrid(
      columns: 3,
      children: [
        StatCard(
          title: 'total_expenses'.tr(),
          value:
              '${NumberFormat.currency(symbol: '', decimalDigits: 2).format(total)} YER',
          icon: Icons.receipt_long_rounded,
          color: AppColors.error,
        ),
        StatCard(
          title: 'expenses'.tr(),
          value: '${_expenses.length}',
          icon: Icons.outbound_rounded,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildDesktopExpensesTable() {
    final rows = _expenses.map((expense) {
      return <Widget>[
        Text(
          expense.note ?? 'expense'.tr(),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          DateFormat('yyyy/MM/dd HH:mm').format(expense.date),
          style: const TextStyle(fontSize: 12),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '-${NumberFormat.currency(symbol: '', decimalDigits: 0).format(expense.amount)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'note'.tr(),
        'date'.tr(),
        'amount'.tr(),
      ],
      flexes: const [4, 3, 2],
      rows: rows,
      emptyMessage: 'no_expenses_yet'.tr(),
      isLoading: _isLoading,
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, Routes.home);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, Routes.customers);
        break;
      case 2:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.addSale)) {
          Navigator.pushNamed(context, Routes.sale);
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 3:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.viewReports)) {
          Navigator.pushReplacementNamed(context, Routes.reports);
        } else {
          SubscriptionDialog.show(context);
        }
        break;
      case 4:
        Navigator.pushReplacementNamed(context, Routes.store);
        break;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'no_expenses_yet'.tr(),
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    final double total = _expenses.fold(0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        _buildSummaryCard(total),
        Expanded(
          child: ListView.builder(
            itemCount: _expenses.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final expense = _expenses[index];
              return _buildExpenseCard(expense);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'total_expenses'.tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${NumberFormat.currency(symbol: '', decimalDigits: 2).format(total)} YER',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.outbound, color: Colors.red),
        ),
        title: Text(
          expense.note ?? 'expense'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat('yyyy/MM/dd HH:mm').format(expense.date),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Text(
          '-${NumberFormat.currency(symbol: '', decimalDigits: 0).format(expense.amount)}',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
