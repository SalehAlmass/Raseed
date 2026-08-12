import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/account.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/accounting_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

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
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'chart_of_accounts'.tr(),
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return _isLoading
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
                    color: isParent
                        ? AppColors.primary.withValues(alpha: 0.05)
                        : AppColors.of(context).surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isParent
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.of(context).border,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    leading: Text(
                      account.code,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isParent
                            ? AppColors.primary
                            : AppColors.of(context).textSecondary,
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
                        color: account.balance >= 0 ? AppColors.of(context).textPrimary : AppColors.error,
                      ),
                    ),
                  ),
                );
              },
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'chart_of_accounts'.tr(),
                subtitle: '${_accounts.length}',
              ),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopTable(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable(AppColorSet colors) {
    final rows = _accounts.map((account) {
      final isParent = account.parentId == null;
      return <Widget>[
        Text(
          account.code,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isParent ? AppColors.primary : colors.textSecondary,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: isParent ? 0 : AppSpace.lg),
          child: Text(
            account.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isParent ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        Text(
          account.type.name,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            CurrencyHelper.getFormatter('YER').format(account.balance),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color:
                  account.balance >= 0 ? colors.textPrimary : AppColors.error,
            ),
          ),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: [
        'code'.tr(),
        'name'.tr(),
        'type'.tr(),
        'balance'.tr(),
      ],
      flexes: const [2, 5, 3, 3],
      rows: rows,
      emptyMessage: 'no_entries'.tr(),
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
}
