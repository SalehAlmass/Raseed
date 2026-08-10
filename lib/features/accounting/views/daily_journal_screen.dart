import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/journal_entry.dart';
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

class DailyJournalScreen extends StatefulWidget {
  const DailyJournalScreen({super.key});

  @override
  State<DailyJournalScreen> createState() => _DailyJournalScreenState();
}

class _DailyJournalScreenState extends State<DailyJournalScreen> {
  final AccountingService _accountingService = sl<AccountingService>();
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final entries = await _accountingService.getJournalEntries();
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'daily_journal'.tr(),
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
            child: _entries.isEmpty
                ? Center(child: Text('no_entries'.tr()))
                : ListView.builder(
                    padding: EdgeInsets.all(20.w),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      return _JournalEntryCard(entry: _entries[index]);
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
                title: 'daily_journal'.tr(),
                subtitle: '${_entries.length}',
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
    final rows = <List<Widget>>[];
    for (final entry in _entries) {
      final entryCells = <Widget>[
        Text(
          DateFormat('yyyy-MM-dd HH:mm').format(entry.date),
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        Text(
          '#${entry.id}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          entry.description,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ];
      if (entry.lines.isEmpty) {
        rows.add([...entryCells, const Text('-'), const Text('-'), const Text('-')]);
        continue;
      }
      for (final line in entry.lines) {
        rows.add([
          ...entryCells,
          Text(
            line.accountName ?? 'Account',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              line.debit > 0
                  ? CurrencyHelper.getFormatter('YER').format(line.debit)
                  : '-',
              style: TextStyle(
                fontSize: 13,
                color: line.debit > 0 ? AppColors.success : colors.textLight,
                fontWeight:
                    line.debit > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              line.credit > 0
                  ? CurrencyHelper.getFormatter('YER').format(line.credit)
                  : '-',
              style: TextStyle(
                fontSize: 13,
                color: line.credit > 0 ? AppColors.error : colors.textLight,
                fontWeight:
                    line.credit > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ]);
      }
    }
    return DesktopTable(
      headers: [
        'date'.tr(),
        '#',
        'description'.tr(),
        'account'.tr(),
        'debit'.tr(),
        'credit'.tr(),
      ],
      flexes: const [2, 1, 3, 3, 2, 2],
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

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  const _JournalEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(entry.date),
                style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Text(
                  '#${entry.id}',
                  style: TextStyle(fontSize: 10.sp, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            entry.description,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 15.h),
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('description'.tr(), style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontWeight: FontWeight.bold))),
                Expanded(child: Text('debit'.tr(), textAlign: TextAlign.center, style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontWeight: FontWeight.bold))),
                Expanded(child: Text('credit'.tr(), textAlign: TextAlign.center, style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(),
          ...entry.lines.map((line) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        line.accountName ?? 'Account',
                        style: TextStyle(fontSize: 13.sp),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line.debit > 0 ? CurrencyHelper.getFormatter('YER').format(line.debit) : '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: line.debit > 0 ? AppColors.success : Colors.grey[400],
                          fontWeight: line.debit > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line.credit > 0 ? CurrencyHelper.getFormatter('YER').format(line.credit) : '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: line.credit > 0 ? AppColors.error : Colors.grey[400],
                          fontWeight: line.credit > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
