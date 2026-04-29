import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/account.dart';
import '../../../core/services/accounting_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  final AccountingService _accountingService = sl<AccountingService>();
  List<Account> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final accounts = await _accountingService.getAccounts();
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('chart_of_accounts'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: EdgeInsets.all(20.w),
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final account = _accounts[index];
                  final isParent = account.parentId == null;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    decoration: BoxDecoration(
                      color: isParent ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isParent ? AppColors.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      leading: Text(
                        account.code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isParent ? AppColors.primary : Colors.grey[600],
                        ),
                      ),
                      title: Text(
                        account.name,
                        style: TextStyle(
                          fontWeight: isParent ? FontWeight.bold : FontWeight.normal,
                          fontSize: isParent ? 15.sp : 14.sp,
                        ),
                      ),
                      trailing: Text(
                        CurrencyHelper.getFormatter('YER').format(account.balance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: account.balance >= 0 ? AppColors.textPrimary : AppColors.error,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
