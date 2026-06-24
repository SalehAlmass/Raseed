
import 'dart:io';
import 'dart:ui' as ui;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/report_models.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/app_transaction.dart';
import '../../../core/utils/currency_helper.dart';
import 'package:intl/intl.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/utils/number_to_words_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart' show rootBundle;

class ExportService {
  StoreProfile get _store => sl<SettingsService>().settings.storeProfile;

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

  Future<pw.MemoryImage?> _getLogo() async {
    if (_store.logoPath != null && File(_store.logoPath!).existsSync()) {
      try {
        final bytes = await File(_store.logoPath!).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 150);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          return pw.MemoryImage(data.buffer.asUint8List());
        }
      } catch (_) {}
      return pw.MemoryImage(File(_store.logoPath!).readAsBytesSync());
    }
    return null;
  }

  PdfPageFormat _getPageFormat() {
    final formatStr = sl<SettingsService>().settings.pdfPageFormat.toUpperCase();
    switch (formatStr) {
      case 'A5':
        return PdfPageFormat.a5;
      case 'LETTER':
        return PdfPageFormat.letter;
      case 'LEGAL':
        return PdfPageFormat.legal;
      case 'A4':
      default:
        return PdfPageFormat.a4;
    }
  }
  Future<void> exportToExcel(DashboardReport report, ReportFilter filter) async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];

    // Headers
    sheet.appendRow([TextCellValue('Business Performance Report')]);
    sheet.appendRow([
      TextCellValue('Report Period: ${DateFormat('yyyy-MM-dd').format(filter.startDate)} to ${DateFormat('yyyy-MM-dd').format(filter.endDate)}'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Financial Summary
    sheet.appendRow([TextCellValue('Financial Summary')]);
    sheet.appendRow([TextCellValue('Total Sales'), DoubleCellValue(report.totalSales)]);
    sheet.appendRow([TextCellValue('Total Profit'), DoubleCellValue(report.totalProfit)]);
    sheet.appendRow([TextCellValue('Inventory Value'), DoubleCellValue(report.inventoryValue)]);
    sheet.appendRow([TextCellValue('')]);

    // Product Performance
    sheet.appendRow([TextCellValue('Product Performance')]);
    sheet.appendRow([
      TextCellValue('Product Name'), 
      TextCellValue('Sold Qty'), 
      TextCellValue('Revenue'), 
      TextCellValue('Cost'), 
      TextCellValue('Net Profit')
    ]);
    
    for (var p in report.productPerformance) {
      sheet.appendRow([
        TextCellValue(p.productName),
        IntCellValue(p.soldCount),
        DoubleCellValue(p.totalRevenue),
        DoubleCellValue(p.totalCost),
        DoubleCellValue(p.netProfit),
      ]);
    }

    sheet.appendRow([TextCellValue('')]);

    // Dead Stock
    sheet.appendRow([TextCellValue('Dead Stock Analysis')]);
    sheet.appendRow([TextCellValue('Product Name'), TextCellValue('Stock Qty'), TextCellValue('Days Since Last Sale')]);
    for (var d in report.deadStock) {
      sheet.appendRow([TextCellValue(d.name), IntCellValue(d.remainingStock), IntCellValue(d.daysSinceLastSale)]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/bi_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Business Intelligence Report');
    }
  }

  Future<void> exportToPdf(DashboardReport report, ReportFilter filter) async {
    final pdf = pw.Document();
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    final logo = await _getLogo();

    final settings = sl<SettingsService>().settings;
    final isRtl = settings.languageCode == 'ar';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: _getPageFormat(),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildPdfHeader(filter, logo, isRtl),
          pw.SizedBox(height: 20),
          
          // Summary Grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfMetricCard('total_sales'.tr(), report.totalSales, CurrencyHelper.getSymbol(filter.currency ?? 'YER')),
              _buildPdfMetricCard('total_profit'.tr(), report.totalProfit, CurrencyHelper.getSymbol(filter.currency ?? 'YER')),
              _buildPdfMetricCard('inventory_value'.tr(), report.inventoryValue, CurrencyHelper.getSymbol(filter.currency ?? 'YER')),
            ],
          ),
          pw.SizedBox(height: 30),

          pw.Text('product_performance'.tr(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['product_name'.tr(), 'sold_qty'.tr(), 'revenue'.tr(), 'cost'.tr(), 'profit'.tr()],
            data: report.productPerformance.map((p) => [
              p.productName, 
              p.soldCount.toString(),
              p.totalRevenue.toStringAsFixed(0),
              p.totalCost.toStringAsFixed(0),
              p.netProfit.toStringAsFixed(0)
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          ),
          
          pw.SizedBox(height: 30),
          pw.Text('dead_stock_analysis'.tr(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['product_name'.tr(), 'stock'.tr(), 'days_inactive'.tr()],
            data: report.deadStock.map((d) => [
              d.name,
              d.remainingStock.toString(),
              'days_count'.tr(args: [d.daysSinceLastSale.toString()])
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
            cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          ),

          pw.SizedBox(height: 30),
          pw.Text('debt_movement'.tr(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['category'.tr(), 'amount'.tr()],
            data: [
              ['total_current_debt'.tr(), report.debtMovement.totalCurrent.toStringAsFixed(0)],
              ['new_debt_period'.tr(), report.debtMovement.newDebt.toStringAsFixed(0)],
              ['collected_debt_period'.tr(), report.debtMovement.collectedDebt.toStringAsFixed(0)],
            ],
            cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'bi_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  Future<pw.Document> generateCustomerTransactionsPdf(
    Customer customer,
    List<AppTransaction> transactions,
  ) async {
    final pdf = pw.Document();
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    final logo = await _getLogo();

    final settings = sl<SettingsService>().settings;
    final isRtl = settings.languageCode == 'ar';
    final currencySymbol = CurrencyHelper.getSymbol(
      transactions.isNotEmpty ? transactions.first.currency : 'YER',
    );

    final totalInvoiced = transactions
        .where((t) => t.type == TransactionType.sale)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalPaid = transactions
        .where((t) => t.type == TransactionType.payment)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final netDebt = customer.totalDebt;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: _getPageFormat(),
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 25),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildStatementHeader(customer, logo, isRtl),
          pw.SizedBox(height: 16),
          _buildSummaryCards(totalInvoiced, totalPaid, netDebt, currencySymbol, isRtl),
          pw.SizedBox(height: 24),
          _buildModernTable(transactions, isRtl, currencySymbol),
          pw.SizedBox(height: 20),
          _buildBalanceFooter(netDebt, currencySymbol, isRtl),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildStatementHeader(Customer customer, pw.MemoryImage? logo, bool isRtl) {
    return pw.Column(
      crossAxisAlignment: isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (_store.storeName != null)
                  pw.Text(
                    _store.storeName!,
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                if (_store.phone != null)
                  pw.Text(_store.phone!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'statement_of_account'.tr(),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                ),
              ],
            ),
            if (logo != null)
              pw.Image(logo, width: 50, height: 50),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: PdfColors.grey200),
          ),
          child: isRtl
              ? pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(customer.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          if (customer.phone.isNotEmpty)
                            pw.Text(customer.phone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                    pw.Container(width: 1, height: 30, color: PdfColors.grey300),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('date'.tr(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                        pw.Text(DateFormat('yyyy/MM/dd').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                )
              : pw.Row(
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(customer.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        if (customer.phone.isNotEmpty)
                          pw.Text(customer.phone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.SizedBox(width: 12),
                    pw.Container(width: 1, height: 30, color: PdfColors.grey300),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('date'.tr(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                        pw.Text(DateFormat('yyyy/MM/dd').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryCards(double totalInvoiced, double totalPaid, double netDebt, String currency, bool isRtl) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildSummaryCard('total_invoiced'.tr(), totalInvoiced, currency, PdfColors.blue700, PdfColors.blue50),
        _buildSummaryCard('total_paid'.tr(), totalPaid, currency, PdfColors.green700, PdfColors.green50),
        _buildSummaryCard('remaining_debt'.tr(), netDebt, currency, PdfColors.orange700, PdfColors.orange50),
      ],
    );
  }

  pw.Widget _buildSummaryCard(String label, double value, String currency, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(
            value.toStringAsFixed(0),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: textColor),
          ),
          pw.Text(currency, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  pw.Widget _buildModernTable(List<AppTransaction> transactions, bool isRtl, String currencySymbol) {
    return pw.TableHelper.fromTextArray(
      headers: ['date'.tr(), 'type'.tr(), 'description'.tr(), 'invoice_total'.tr(), 'remaining_debt'.tr()],
      data: transactions.map((tx) {
        final isRefund = tx.type == TransactionType.refund;
        final isSale = tx.type == TransactionType.sale;
        final isPayment = tx.type == TransactionType.payment;
        final isFullyPaid = isSale && (tx.amount - tx.paidAmount <= 0);
        final typeStr = isFullyPaid
            ? 'cash_sale'.tr()
            : (isSale
                ? 'transaction_debt_invoice'.tr()
                : (isRefund ? 'refund'.tr() : 'transaction_payment_receipt'.tr()));

        String descriptionStr = '';
        if (tx.note.isNotEmpty) {
          descriptionStr = tx.note;
        } else {
          if (isSale) {
            if (tx.items.isNotEmpty) {
              descriptionStr = tx.items.map((item) => '${item.productName} (${item.quantity})').join('، ');
              if (tx.paidAmount > 0) {
                descriptionStr += '  [المدفوع: ${tx.paidAmount.toStringAsFixed(0)} $currencySymbol]';
              }
            } else {
              descriptionStr = typeStr;
            }
          } else if (isPayment) {
            descriptionStr = 'transaction_payment_receipt'.tr();
          } else if (isRefund) {
            if (tx.items.isNotEmpty) {
              descriptionStr = '${'refund'.tr()}: ${tx.items.map((item) => '${item.productName} (${item.quantity})').join('، ')}';
            } else {
              descriptionStr = typeStr;
            }
          }
        }

        String totalStr;
        String remainingStr;

        if (isSale) {
          totalStr = '${tx.amount.toStringAsFixed(0)} $currencySymbol';
          remainingStr = '${(tx.amount - tx.paidAmount).toStringAsFixed(0)} $currencySymbol';
        } else if (isPayment) {
          totalStr = '${tx.amount.toStringAsFixed(0)} $currencySymbol';
          remainingStr = '-${tx.amount.toStringAsFixed(0)} $currencySymbol';
        } else {
          totalStr = '${tx.amount.toStringAsFixed(0)} $currencySymbol';
          remainingStr = '${tx.amount.toStringAsFixed(0)} $currencySymbol';
        }

        return [
          DateFormat('yyyy/MM/dd').format(tx.date),
          typeStr,
          descriptionStr,
          totalStr,
          remainingStr,
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blueGrey800,
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(6),
          topRight: pw.Radius.circular(6),
        ),
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FixedColumnWidth(75),
        1: const pw.FixedColumnWidth(90),
        2: const pw.FlexColumnWidth(),
        3: const pw.FixedColumnWidth(85),
        4: const pw.FixedColumnWidth(100),
      },
      headerPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
    );
  }

  pw.Widget _buildBalanceFooter(double netDebt, String currencySymbol, bool isRtl) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'total_due_balance'.tr(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          pw.Text(
            '$netDebt $currencySymbol',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: netDebt > 0 ? PdfColors.red800 : PdfColors.green800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> exportCustomerTransactionsToPdf(
    Customer customer,
    List<AppTransaction> transactions,
  ) async {
    final pdf = await generateCustomerTransactionsPdf(customer, transactions);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'customer_${customer.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _buildPdfHeader(ReportFilter filter, pw.MemoryImage? logo, bool isRtl) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('business_performance_report'.tr(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('${'report_period'.tr()}: ${DateFormat('yyyy-MM-dd').format(filter.startDate)} - ${DateFormat('yyyy-MM-dd').format(filter.endDate)}'),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logo != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Image(logo, width: 40, height: 40),
                ),
              pw.Text(
                _store.storeName ?? 'app_name'.tr(),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              if (_store.phone != null) pw.Text(_store.phone!, style: const pw.TextStyle(fontSize: 8)),
              pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfMetricCard(String title, double value, String currency) {
    return pw.Container(
      width: 170,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700)),
          pw.SizedBox(height: 5),
          pw.Text(value.toStringAsFixed(0), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(currency, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  Future<pw.Document> generateSingleTransactionInvoicePdf(
    AppTransaction transaction, {
    Customer? customer,
  }) async {
    final pdf = pw.Document();
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    final logo = await _getLogo();

    final settings = sl<SettingsService>().settings;
    final isRtl = settings.languageCode == 'ar';

    final double netTotal = transaction.amount;
    final String amountInWords = NumberToWordsArabic.convertToWords(netTotal, transaction.currency);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          // 1. Header Box (with thick black border and rounded corners)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(15)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left English Store Info Column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("١", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        "SPECIALST IN NETWORK SYSTEMS",
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "Shabwa Ataq",
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "specialst in network system",
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        "٧٧٥٢٧٦٦٩٩-٧٧٠٩٨٠٠٠٣",
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "٠٥٢٠٤٦١٥",
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // Center Logo & Title Column
                pw.Column(
                  children: [
                    if (logo != null)
                      pw.Image(logo, width: 45, height: 45)
                    else
                      pw.Container(
                        width: 40,
                        height: 40,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                          shape: pw.BoxShape.circle,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text("R", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text("أمان تك", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("تواصل للحلول المتكاملة", style: const pw.TextStyle(fontSize: 7)),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "فاتورة المبيعات",
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                // Right Arabic Store Info Column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        _store.storeName ?? "امان تكنولوجي",
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "متخصصون في انظمة الشبكات",
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "شبوة عتق جولة الثقافة - جوار التميز للصرافة",
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        "شبكات-انظمة مراقبةوتحكم والطاقة المتجددة",
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                      pw.Text(
                        "كمبيوترات طابعات احبار",
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        "٧٧٠٩٨٠٠٠٣ - ٧٧٥٢٧٦٦٩٩",
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // 2. Main Box (containing Metadata, Table, and Summary with rounded corners & black border)
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(15)),
            ),
            child: pw.Column(
              children: [
                // Metadata Row 1
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "العملة : ${transaction.currency}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                      pw.Text(
                        "رقم المرجع : ${transaction.id != null ? (transaction.id! * 1000 + 492) : '١٤٩٢'}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                      pw.Text(
                        "التاريخ : ${DateFormat('yyyy/MM/dd').format(transaction.date)}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                      pw.Text(
                        "نوع الفاتورة : ${transaction.paidAmount >= transaction.amount ? 'نقداً' : 'آجل'}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                      pw.Text(
                        "رقم الفاتورة : ${transaction.id ?? '١٣٣٦'}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                // Metadata Row 2
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 10, right: 10, bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.SizedBox(width: 80),
                      pw.Text(
                        "اسم العميل : ${customer?.name ?? 'المهندس احمد العجي'}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                      pw.Text(
                        "المخزن : ${_store.address ?? 'مخزن الثقافة'}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                // Items Table
                pw.TableHelper.fromTextArray(
                  headers: [
                    'رقم الصنف',
                    'اسم الصنف',
                    'الوحدة',
                    'الكمية',
                    'ك.المجانية',
                    'السعر',
                    'الإجمالي'
                  ],
                  data: transaction.items.map((item) {
                    final codeStr = '005-001-${item.productId.toString().padLeft(4, '0')}';
                    return [
                      codeStr,
                      item.productName,
                      'حبة',
                      item.quantity.toString(),
                      '',
                      item.price.toStringAsFixed(2),
                      item.total.toStringAsFixed(2),
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                    fontSize: 9,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xffa0c0e0),
                  ),
                  cellStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  cellAlignment: pw.Alignment.center,
                  cellAlignments: {
                    1: pw.Alignment.centerRight, // Item name right-aligned in Arabic
                  },
                  columnWidths: {
                    0: const pw.FixedColumnWidth(80),
                    1: const pw.FlexColumnWidth(),
                    2: const pw.FixedColumnWidth(40),
                    3: const pw.FixedColumnWidth(40),
                    4: const pw.FixedColumnWidth(50),
                    5: const pw.FixedColumnWidth(60),
                    6: const pw.FixedColumnWidth(70),
                  },
                  headerPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                ),
                pw.SizedBox(height: 8),

                // Summary Row (Subtotal & Discount)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text("الإجمالي :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              pw.SizedBox(width: 8),
                              pw.Container(
                                width: 70,
                                alignment: pw.Alignment.centerLeft,
                                child: pw.Text(
                                  transaction.amount.toStringAsFixed(2),
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red800),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 2),
                          pw.Row(
                            children: [
                              pw.Text("الخصم :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              pw.SizedBox(width: 8),
                              pw.Container(
                                width: 70,
                                alignment: pw.Alignment.centerLeft,
                                child: pw.Text(
                                  "0.00",
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red800),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // Spelled-out words and total numeric (split container)
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: 1.5),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      // Right Side: Amount in Words (occupies full width except total numeric)
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text(
                            amountInWords,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red800),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ),
                      // Split vertical line
                      pw.Container(width: 1.5, height: 25, color: PdfColors.black),
                      // Left Side: Total Numeric Amount (aligned left)
                      pw.Container(
                        width: 70,
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          transaction.amount.toStringAsFixed(2),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 35),

          // 3. Signatures row (outside the main details box at the bottom)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("مدير المبيعات", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text("مدير الحسابات", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text("المخازن", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text("مندوب المبيعات", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text("المحاسب", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text("العميل", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<void> exportSingleTransactionInvoiceToPdf(
    AppTransaction transaction, {
    Customer? customer,
  }) async {
    final pdf = await generateSingleTransactionInvoicePdf(transaction, customer: customer);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoice_${transaction.id ?? "new"}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}

