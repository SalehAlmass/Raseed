import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/widgets/subscription_dialog.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/routes/routes.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/desktop/responsive.dart';
import '../../../core/widgets/desktop/stat_card.dart';
import 'package:timeago/timeago.dart' as timeago;

enum CustomerFilter { all, debtor, noDebt, active, inactive, vip }

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final CustomerService _customerService = sl<CustomerService>();
  final SettingsService _settingsService = sl<SettingsService>();
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  AppSettings? _settings;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  CustomerFilter _selectedFilter = CustomerFilter.all;
  Map<String, dynamic> _analytics = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await _customerService.getAllCustomers();
    final settings = await _settingsService.getSettings();
    final analytics = await _customerService.getCustomerAnalytics();
    setState(() {
      _customers = customers;
      _settings = settings;
      _analytics = analytics;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((customer) {
        // 1. Search Query
        final matchesSearch =
            customer.name.toLowerCase().contains(query) ||
            customer.phone.contains(query);
        if (!matchesSearch) return false;

        // 2. Chip Filter
        switch (_selectedFilter) {
          case CustomerFilter.all:
            return true;
          case CustomerFilter.debtor:
            return customer.totalDebt > 0;
          case CustomerFilter.noDebt:
            return customer.totalDebt == 0;
          case CustomerFilter.active:
            if (customer.lastTransactionDate == null) return false;
            final diff = DateTime.now()
                .difference(customer.lastTransactionDate!)
                .inDays;
            return diff <= (_settings?.inactiveDays ?? 30);
          case CustomerFilter.inactive:
            if (customer.lastTransactionDate == null)
              return true; // Dead is also inactive
            final diff = DateTime.now()
                .difference(customer.lastTransactionDate!)
                .inDays;
            return diff > (_settings?.inactiveDays ?? 30);
          case CustomerFilter.vip:
            return customer.totalSpent >= (_settings?.vipThreshold ?? 100000);
        }
      }).toList();

      // Handle VIP sorting
      if (_selectedFilter == CustomerFilter.vip) {
        _filteredCustomers.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
      } else {
        _filteredCustomers.sort((a, b) => a.name.compareTo(b.name));
      }
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: 1,
      title: 'customers'.tr(),
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (sl<SubscriptionService>().canUseFeature(
            AppFeature.addCustomer,
          )) {
            _showAddCustomerDialog(context);
          } else {
            SubscriptionDialog.show(context);
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add),
      ),
      onNavigate: _onNavTap,
      body: _buildMobileBody(),
      desktopBody: _buildDesktopBody(),
    );
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        _buildAnalyticsDashboard(),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'search_hint'.tr(),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.of(context).surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        _buildFilterChips(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredCustomers.isEmpty
              ? Center(child: Text('no_customers'.tr()))
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 100.h),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];
                    return _CustomerTile(
                      customer: customer,
                      settings: _settings,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/customer_detail',
                        arguments: customer,
                      ).then((_) => _loadCustomers()),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopBody() {
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
                title: 'customers'.tr(),
                subtitle: '${_filteredCustomers.length}',
                actions: [
                  FilledButton.icon(
                    onPressed: () {
                      if (sl<SubscriptionService>().canUseFeature(
                        AppFeature.addCustomer,
                      )) {
                        _showAddCustomerDialog(context);
                      } else {
                        SubscriptionDialog.show(context);
                      }
                    },
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: Text('add_new_customer'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              _buildDesktopStats(),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopToolbar(colors),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopCustomersTable(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStats() {
    return ResponsiveGrid(
      columns: 3,
      children: [
        StatCard(
          title: 'total'.tr(),
          value: _analytics['total_customers']?.toString() ?? '0',
          icon: Icons.people_alt_outlined,
          color: AppColors.primary,
        ),
        StatCard(
          title: 'debtors'.tr(),
          value: _analytics['debtors_count']?.toString() ?? '0',
          icon: Icons.person_pin_circle_outlined,
          color: AppColors.error,
        ),
        StatCard(
          title: 'active'.tr(),
          value: _analytics['active_count']?.toString() ?? '0',
          icon: Icons.timelapse_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildDesktopToolbar(AppColorSet colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: [
                for (final filter in CustomerFilter.values)
                  _buildDesktopFilterChip(filter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilterChip(CustomerFilter filter) {
    final isSelected = _selectedFilter == filter;
    final colors = AppColors.of(context);
    return ChoiceChip(
      label: Text(filter.name.tr()),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = filter;
            _applyFilters();
          });
        }
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colors.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: colors.surface,
      selectedColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDesktopCustomersTable(AppColorSet colors) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = _filteredCustomers
        .map((c) => _buildCustomerRow(colors, c))
        .toList();
    return DesktopTable(
      headers: [
        'name'.tr(),
        'phone_number'.tr(),
        'status'.tr(),
        'last_deal'.tr(),
        'debt'.tr(),
        'spent'.tr(),
        '',
      ],
      flexes: const [3, 2, 2, 2, 2, 2, 1],
      rows: rows,
      emptyMessage: 'no_customers'.tr(),
    );
  }

  List<Widget> _buildCustomerRow(AppColorSet colors, Customer customer) {
    final isDebtor = customer.totalDebt > 0;
    final (statusColor, statusLabel) = _customerStatus(customer);
    return [
      Text(
        customer.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      Text(customer.phone, style: const TextStyle(fontSize: 12)),
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpace.xs),
          Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor)),
        ],
      ),
      Text(
        customer.lastTransactionDate == null
            ? '-'
            : timeago.format(
                customer.lastTransactionDate!,
                locale: context.locale.languageCode,
              ),
        style: const TextStyle(fontSize: 12),
      ),
      Text(
        CurrencyHelper.getFormatter('YER').format(customer.totalDebt),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDebtor ? AppColors.error : AppColors.success,
        ),
      ),
      Text(
        CurrencyHelper.getFormatter('YER').format(customer.totalSpent),
        style: const TextStyle(fontSize: 12),
      ),
      IconButton(
        tooltip: 'view'.tr(),
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.pushNamed(
          context,
          '/customer_detail',
          arguments: customer,
        ).then((_) => _loadCustomers()),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ];
  }

  (Color, String) _customerStatus(Customer customer) {
    Color statusColor = Colors.grey;
    String statusLabel = 'dead'.tr();
    if (customer.lastTransactionDate != null) {
      final days = DateTime.now()
          .difference(customer.lastTransactionDate!)
          .inDays;
      if (days <= (_settings?.inactiveDays ?? 30)) {
        statusColor = AppColors.success;
        statusLabel = 'active'.tr();
      } else if (days < (_settings?.deadDays ?? 90)) {
        statusColor = Colors.orange;
        statusLabel = 'inactive'.tr();
      }
    }
    return (statusColor, statusLabel);
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, Routes.home);
        break;
      case 1:
        break;
      case 2:
        if (sl<SubscriptionService>().canUseFeature(AppFeature.addSale)) {
          Navigator.pushNamed(context, Routes.sale).then((result) {
            if (result == true) _loadCustomers();
          });
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

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_new_customer'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'name'.tr()),
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'name_required'.tr();
                  if (!RegExp(r'^[\u0600-\u06FFa-zA-Z\s]+$').hasMatch(val))
                    return 'name_letters_only'.tr();
                  return null;
                },
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'phone_number'.tr()),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'phone_required'.tr();
                  if (val.trim().length < 9) return 'phone_invalid'.tr();
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _customerService.createCustomer(
                  Customer(
                    name: nameController.text,
                    phone: phoneController.text,
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadCustomers();
                }
              }
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsDashboard() {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 0),
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'total'.tr(),
            _analytics['total_customers']?.toString() ?? '0',
          ),
          _buildStatDivider(),
          _buildStatItem(
            'debtors'.tr(),
            _analytics['debtors_count']?.toString() ?? '0',
          ),
          _buildStatDivider(),
          _buildStatItem(
            'active'.tr(),
            _analytics['active_count']?.toString() ?? '0',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30.h,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        children: CustomerFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ChoiceChip(
              label: Text(filter.name.tr()),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedFilter = filter;
                    _applyFilters();
                  });
                }
              },
              backgroundColor: AppColors.of(context).surface,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.of(context).textPrimary,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              side: BorderSide.none,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final AppSettings? settings;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.onTap,
    this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDebtor = customer.totalDebt > 0;
    final bool isVIP =
        customer.totalSpent >= (settings?.vipThreshold ?? 100000);

    // Activity Status
    Color statusColor = Colors.grey;
    String statusLabel = 'dead'.tr();
    if (customer.lastTransactionDate != null) {
      final days = DateTime.now()
          .difference(customer.lastTransactionDate!)
          .inDays;
      if (days <= (settings?.inactiveDays ?? 30)) {
        statusColor = AppColors.success;
        statusLabel = 'active'.tr();
      } else if (days < (settings?.deadDays ?? 90)) {
        statusColor = Colors.orange;
        statusLabel = 'inactive'.tr();
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(15.w),
        onTap: onTap,
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                customer.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                customer.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
            // if (isVIP)
            //   Container(
            //     padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            //     decoration: BoxDecoration(
            //       color: Colors.amber.withOpacity(0.15),
            //       borderRadius: BorderRadius.circular(6.r),
            //     ),
            //     child: Text(
            //       'VIP'.tr(),
            //       style: TextStyle(
            //         color: Colors.amber[800],
            //         fontSize: 10.sp,
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //   ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.phone,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
            if (customer.lastTransactionDate != null)
              Text(
                '${'last_deal'.tr()}: ${timeago.format(customer.lastTransactionDate!, locale: context.locale.languageCode)}',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.primary.withOpacity(0.7),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${CurrencyHelper.getFormatter('YER').format(customer.totalDebt)}',
              style: TextStyle(
                color: isDebtor ? AppColors.error : AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
            Text(
              '${'spent'.tr()}: ${CurrencyHelper.getFormatter('YER').format(customer.totalSpent)}',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
