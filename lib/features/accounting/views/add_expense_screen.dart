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
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final expense = Expense(
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        note: _noteController.text,
      );

      await sl<ExpenseService>().addExpense(expense);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('expense_added_successfully'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_adding_expense'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'add_expense'.tr(),
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAmountField(),
            const SizedBox(height: 20),
            _buildDateField(),
            const SizedBox(height: 20),
            _buildNoteField(),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('save'.tr(), style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DesktopMetrics.contentMaxWidth,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'add_expense'.tr(),
                  actions: [
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: Text('cancel'.tr()),
                    ),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveExpense,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text('save'.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: colors.border),
                    boxShadow: AppShadow.soft(Colors.black),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide =
                          constraints.maxWidth >= AppBreakpoints.desktop;
                      final amountField = _buildAmountField();
                      final dateField = _buildDateField();
                      final noteField = _buildNoteField();
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  amountField,
                                  const SizedBox(height: AppSpace.lg),
                                  noteField,
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.xl),
                            Expanded(child: dateField),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          amountField,
                          const SizedBox(height: AppSpace.lg),
                          dateField,
                          const SizedBox(height: AppSpace.lg),
                          noteField,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'amount'.tr(),
        prefixIcon: const Icon(Icons.attach_money),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'field_required'.tr();
        if (double.tryParse(value) == null) return 'invalid_number'.tr();
        return null;
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'date'.tr(),
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          DateFormat('yyyy/MM/dd').format(_selectedDate),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'note'.tr(),
        prefixIcon: const Icon(Icons.note_alt_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
