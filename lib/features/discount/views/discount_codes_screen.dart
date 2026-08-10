import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_feature.dart';
import '../../../core/models/discount_code.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/discount_code_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/desktop_tokens.dart';
import '../../../core/widgets/desktop/desktop_scaffold.dart';
import '../../../core/widgets/desktop/desktop_table.dart';
import '../../../core/widgets/desktop/page_header.dart';
import '../../../core/widgets/subscription_dialog.dart';

class DiscountCodesScreen extends StatefulWidget {
  const DiscountCodesScreen({super.key});

  @override
  State<DiscountCodesScreen> createState() => _DiscountCodesScreenState();
}

class _DiscountCodesScreenState extends State<DiscountCodesScreen> {
  final _service = sl<DiscountCodeService>();
  List<DiscountCode> _codes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final codes = await _service.getAllCodes();
    if (mounted) setState(() { _codes = codes; _isLoading = false; });
  }

  Future<void> _showAddEditDialog([DiscountCode? existing]) async {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final valCtrl = TextEditingController(text: existing?.discountValue.toString() ?? '');
    final minCtrl = TextEditingController(text: existing?.minPurchase.toString() ?? '0');
    final maxCtrl = TextEditingController(text: existing?.maxUses.toString() ?? '0');
    String type = existing?.discountType ?? 'percentage';
    bool active = existing?.active ?? true;
    DateTime? from = existing?.validFrom;
    DateTime? to = existing?.validTo;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(existing != null ? 'edit_code'.tr() : 'add_code'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: InputDecoration(labelText: 'code'.tr(), hintText: 'SUMMER20'), textCapitalization: TextCapitalization.characters),
                SizedBox(height: 8.h),
                DropdownButtonFormField<String>(
                  value: type,
                  items: [
                    DropdownMenuItem(value: 'percentage', child: Text(context.locale.languageCode == 'ar' ? 'نسبة %' : 'Percentage %')),
                    DropdownMenuItem(value: 'fixed', child: Text(context.locale.languageCode == 'ar' ? 'قيمة ثابتة' : 'Fixed Amount')),
                  ],
                  onChanged: (v) => setDState(() => type = v!),
                  decoration: InputDecoration(labelText: 'discount_type'.tr()),
                ),
                SizedBox(height: 8.h),
                TextField(controller: valCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: type == 'percentage' ? 'discount_percent'.tr() : 'discount_amount'.tr())),
                SizedBox(height: 8.h),
                TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'min_purchase'.tr())),
                SizedBox(height: 8.h),
                TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'max_uses'.tr())),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Text(context.locale.languageCode == 'ar' ? 'من' : 'From', style: TextStyle(fontSize: 12.sp)),
                    SizedBox(width: 8.w),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: from ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) setDState(() => from = d);
                      },
                      child: Text(from != null ? '${from!.year}-${from!.month}-${from!.day}' : 'select'.tr()),
                    ),
                    SizedBox(width: 8.w),
                    Text(context.locale.languageCode == 'ar' ? 'إلى' : 'To', style: TextStyle(fontSize: 12.sp)),
                    SizedBox(width: 8.w),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: to ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) setDState(() => to = d);
                      },
                      child: Text(to != null ? '${to!.year}-${to!.month}-${to!.day}' : 'select'.tr()),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: active,
                  onChanged: (v) => setDState(() => active = v!),
                  title: Text('active'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.isEmpty || valCtrl.text.isEmpty) return;
                final code = DiscountCode(
                  id: existing?.id,
                  code: codeCtrl.text.trim().toUpperCase(),
                  discountType: type,
                  discountValue: double.tryParse(valCtrl.text) ?? 0,
                  minPurchase: double.tryParse(minCtrl.text) ?? 0,
                  maxUses: int.tryParse(maxCtrl.text) ?? 0,
                  currentUses: existing?.currentUses ?? 0,
                  validFrom: from,
                  validTo: to,
                  active: active,
                  createdAt: existing?.createdAt ?? DateTime.now(),
                );
                try {
                  if (existing != null) { await _service.updateCode(code); } else { await _service.addCode(code); }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('error_occurred'.tr()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      activeNavIndex: -1,
      title: 'discount_codes'.tr(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      onNavigate: _onNavTap,
      body: _buildMobileBody(context),
      desktopBody: _buildDesktopBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _codes.isEmpty
            ? Center(child: Text('no_discount_codes'.tr()))
            : ListView.builder(
                padding: EdgeInsets.all(20.w),
                itemCount: _codes.length,
                itemBuilder: (context, index) {
                  final code = _codes[index];
                  final expired = !code.isValid;
                  return Card(
                    margin: EdgeInsets.only(bottom: 8.h),
                    color: expired ? Colors.grey[100] : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (expired ? Colors.grey : Colors.blue).withValues(alpha: 0.1),
                        child: Icon(Icons.redeem, color: expired ? Colors.grey : Colors.blue),
                      ),
                      title: Row(
                        children: [
                          Text(code.code, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: code.active ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              code.active ? 'active'.tr() : 'inactive'.tr(),
                              style: TextStyle(fontSize: 10.sp, color: code.active ? Colors.green : Colors.red),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        code.discountType == 'percentage'
                            ? '${code.discountValue}% ${'off'.tr()}'
                            : '${'discount'.tr()}: ${code.discountValue} YER',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${code.currentUses}/${code.maxUses > 0 ? code.maxUses : '∞'}', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                          SizedBox(width: 8.w),
                          PopupMenuButton<String>(
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text('edit'.tr())),
                              PopupMenuItem(value: 'delete', child: Text('delete'.tr(), style: const TextStyle(color: Colors.red))),
                            ],
                            onSelected: (v) async {
                              if (v == 'edit') _showAddEditDialog(code);
                              if (v == 'delete') {
                                await _service.deleteCode(code.id!);
                                _load();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                title: 'discount_codes'.tr(),
                subtitle: '${_codes.length}',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('add_code'.tr()),
                  ),
                ],
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
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = _codes.map((code) => _buildCodeRow(colors, code)).toList();
    return DesktopTable(
      headers: [
        'code'.tr(),
        'discount'.tr(),
        'min_purchase'.tr(),
        'max_uses'.tr(),
        'status'.tr(),
        '',
      ],
      flexes: const [2, 2, 2, 2, 2, 1],
      rows: rows,
      emptyMessage: 'no_discount_codes'.tr(),
    );
  }

  List<Widget> _buildCodeRow(AppColorSet colors, DiscountCode code) {
    return [
      Text(
        code.code,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      Text(
        code.discountType == 'percentage'
            ? '${code.discountValue}% ${'off'.tr()}'
            : '${'discount'.tr()}: ${code.discountValue} YER',
        style: const TextStyle(fontSize: 12),
      ),
      Text('${code.minPurchase}', style: const TextStyle(fontSize: 12)),
      Text(
        '${code.currentUses}/${code.maxUses > 0 ? code.maxUses : '∞'}',
        style: const TextStyle(fontSize: 12),
      ),
      _buildStatusBadge(colors, code),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'edit'.tr(),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () => _showAddEditDialog(code),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'delete'.tr(),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await _service.deleteCode(code.id!);
              _load();
            },
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
    ];
  }

  Widget _buildStatusBadge(AppColorSet colors, DiscountCode code) {
    final expired = !code.isValid;
    final Color color;
    final String label;
    if (expired) {
      color = colors.textLight;
      label = 'expired'.tr();
    } else if (code.active) {
      color = colors.success;
      label = 'active'.tr();
    } else {
      color = colors.error;
      label = 'inactive'.tr();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
}
