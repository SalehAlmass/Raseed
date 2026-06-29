import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_transaction.dart';
import '../models/customer.dart';
import '../utils/currency_helper.dart';
import '../services/settings_service.dart';
import '../di/injection_container.dart';
import '../models/app_settings.dart';
import 'package:flutter/services.dart' show rootBundle;

class ReceiptService {
  pw.Font? _cachedFont;
  pw.Font? _cachedBoldFont;

  Future<pw.Font> _getFont() async {
    if (_cachedFont != null) return _cachedFont!;
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    _cachedFont = pw.Font.ttf(fontData);
    return _cachedFont!;
  }

  Future<pw.Font> _getBoldFont() async {
    if (_cachedBoldFont != null) return _cachedBoldFont!;
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    _cachedBoldFont = pw.Font.ttf(boldFontData);
    return _cachedBoldFont!;
  }

  Future<void> printReceipt(AppTransaction transaction, {Customer? customer}) async {
    final settings = sl<SettingsService>().settings;
    final store = settings.storeProfile;
    final isRtl = settings.languageCode == 'ar';

    final pdf = pw.Document();
    final font = await _getFont();
    final boldFont = await _getBoldFont();

    pw.MemoryImage? logoImage;
    if (store.logoPath != null && File(store.logoPath!).existsSync()) {
      try {
        final bytes = await File(store.logoPath!).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 150);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          logoImage = pw.MemoryImage(data.buffer.asUint8List());
        }
      } catch (_) {}
      logoImage ??= pw.MemoryImage(File(store.logoPath!).readAsBytesSync());
    }

    // Receipt Size: 80mm or 58mm from settings
    final double pageWidth = settings.receiptWidth * PdfPageFormat.mm;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              if (logoImage != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Image(logoImage, width: 40, height: 40),
                ),
              pw.Text(store.storeName ?? 'app_name'.tr(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (store.phone != null) pw.Text(store.phone!, style: const pw.TextStyle(fontSize: 8)),
              if (store.address != null) pw.Text(store.address!, style: const pw.TextStyle(fontSize: 8)),
              if (store.taxNumber != null) pw.Text('${'tax_number'.tr()}: ${store.taxNumber}', style: const pw.TextStyle(fontSize: 8)),
              
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              
              // Transaction Info
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${'date'.tr()}: ${DateFormat('yyyy-MM-dd HH:mm').format(transaction.date)}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('${'transaction_number'.tr()}: #${transaction.id ?? "NEW"}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (customer != null) ...[
                pw.SizedBox(height: 5),
                pw.Text('${'customer'.tr()}: ${customer.name}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Items Table
              pw.SizedBox(height: 5),
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('item'.tr(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('quantity'.tr(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('total'.tr(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: isRtl ? pw.TextAlign.right : pw.TextAlign.left)),
                ],
              ),
              pw.SizedBox(height: 5),
              if (transaction.items != null)
                ...transaction.items!.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(item.productName, style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 1, child: pw.Text(item.quantity.toString(), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text(item.total.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 8), textAlign: isRtl ? pw.TextAlign.right : pw.TextAlign.left)),
                    ],
                  ),
                )),
              
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Totals
              pw.SizedBox(height: 5),
              _buildTotalRow('${'total_amount'.tr()}:', transaction.amount),
              if (transaction.paidAmount > 0)
                _buildTotalRow('${'paid_amount'.tr()}:', transaction.paidAmount),
              if (transaction.amount - transaction.paidAmount > 0)
                _buildTotalRow('${'remaining_amount'.tr()}:', transaction.amount - transaction.paidAmount, isBold: true),
              
              pw.SizedBox(height: 20),
              pw.Text('thank_you'.tr(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('www.tajermas.com', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'receipt_${transaction.date.millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _buildTotalRow(String label, double value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value.toStringAsFixed(0), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
