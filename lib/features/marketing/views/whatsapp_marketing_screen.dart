import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/models/customer.dart';
import '../../../core/theme/colors.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('whatsapp_marketing'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Padding(
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
      ),
    );
  }
}
