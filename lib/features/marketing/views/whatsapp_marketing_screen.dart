import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/customer.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

class WhatsappMarketingScreen extends StatefulWidget {
  const WhatsappMarketingScreen({super.key});

  @override
  State<WhatsappMarketingScreen> createState() => _WhatsappMarketingScreenState();
}

class _WhatsappMarketingScreenState extends State<WhatsappMarketingScreen> {
  final CustomerService _customerService = sl<CustomerService>();
  final TextEditingController _messageController = TextEditingController();
  
  String _selectedAudience = 'all';
  List<Customer> _filteredCustomers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final all = await _customerService.getAllCustomers();
    
    setState(() {
      if (_selectedAudience == 'all') {
        _filteredCustomers = all;
      } else if (_selectedAudience == 'vip') {
        _filteredCustomers = all.where((c) => c.totalSpent > 100000).toList();
      } else if (_selectedAudience == 'debtors') {
        _filteredCustomers = all.where((c) => c.totalDebt > 0).toList();
      }
      _isLoading = false;
    });
  }

  Future<void> _sendMessage(Customer customer) async {
    final message = Uri.encodeComponent(_messageController.text);
    final phone = customer.phone.startsWith('+') ? customer.phone : '+967${customer.phone}'; // Default to Yemen if no prefix
    final url = 'https://wa.me/${phone.replaceAll('+', '')}?text=$message';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'whatsapp_marketing'.tr(),
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'select_audience'.tr(),
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 10.w,
            children: [
              ChoiceChip(
                label: Text('all_customers'.tr()),
                selected: _selectedAudience == 'all',
                onSelected: (v) {
                  setState(() => _selectedAudience = 'all');
                  _loadCustomers();
                },
              ),
              ChoiceChip(
                label: Text('vip_customers'.tr()),
                selected: _selectedAudience == 'vip',
                onSelected: (v) {
                  setState(() => _selectedAudience = 'vip');
                  _loadCustomers();
                },
              ),
              ChoiceChip(
                label: Text('debtors'.tr()),
                selected: _selectedAudience == 'debtors',
                onSelected: (v) {
                  setState(() => _selectedAudience = 'debtors');
                  _loadCustomers();
                },
              ),
            ],
          ),
          SizedBox(height: 20.h),
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'message_template'.tr(),
              hintText: 'أهلاً بك عميلنا العزيز، لدينا عرض خاص لك...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredCustomers.length} ${'customers'.tr()}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final c = _filteredCustomers[index];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(c.phone),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, color: Colors.green),
                          onPressed: () => _sendMessage(c),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.rocket_launch),
              label: Text('send_now'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onPressed: () {
                // In a real app, we would loop through and send, but mobile OS 
                // usually prevents true bulk background sending without API.
                // We'll show a message or start a sequence.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى النقر على زر الإرسال بجانب كل عميل للبدء')),
                );
              },
            ),
          ),
        ],
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
                title: 'whatsapp_marketing'.tr(),
                subtitle: '${_filteredCustomers.length} ${'customers'.tr()}',
              ),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopFormCard(colors),
              const SizedBox(height: AppSpace.lg),
              _buildDesktopCustomersTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFormCard(AppColorSet colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AppShadow.soft(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'select_audience'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              _buildAudienceChip('all_customers'.tr(), 'all'),
              _buildAudienceChip('vip_customers'.tr(), 'vip'),
              _buildAudienceChip('debtors'.tr(), 'debtors'),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'message_template'.tr(),
              hintText: 'أهلاً بك عميلنا العزيز، لدينا عرض خاص لك...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.rocket_launch, size: 18),
              label: Text('send_now'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى النقر على زر الإرسال بجانب كل عميل للبدء')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedAudience == value,
      onSelected: (_) {
        setState(() => _selectedAudience = value);
        _loadCustomers();
      },
    );
  }

  Widget _buildDesktopCustomersTable() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = _filteredCustomers.map((c) {
      return [
        Text(
          c.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(c.phone, style: const TextStyle(fontSize: 12)),
        IconButton(
          tooltip: 'whatsapp'.tr(),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          onPressed: () => _sendMessage(c),
          icon: const Icon(Icons.send, color: Colors.green),
        ),
      ];
    }).toList();
    return DesktopTable(
      headers: ['name'.tr(), 'phone_number'.tr(), ''],
      flexes: const [3, 3, 1],
      rows: rows,
      emptyMessage: 'no_customers'.tr(),
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
