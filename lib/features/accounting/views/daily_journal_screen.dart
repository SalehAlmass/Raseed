import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/journal_entry.dart';
import '../../../core/services/accounting_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_helper.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('daily_journal'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
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
            ),
    );
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
            color: Colors.black.withOpacity(0.05),
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
                  color: AppColors.primary.withOpacity(0.1),
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
