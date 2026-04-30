
import 'dart:io';
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
import 'package:easy_localization/easy_localization.dart';

class ExportService {
  StoreProfile get _store => sl<SettingsService>().settings.storeProfile;

  pw.MemoryImage? _getLogo() {
    if (_store.logoPath != null && File(_store.logoPath!).existsSync()) {
      return pw.MemoryImage(File(_store.logoPath!).readAsBytesSync());
    }
    return null;
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
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildPdfHeader(filter),
          pw.SizedBox(height: 20),
          
          // Summary Grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfMetricCard('Total Sales', report.totalSales, filter.currency ?? 'YER'),
              _buildPdfMetricCard('Total Profit', report.totalProfit, filter.currency ?? 'YER'),
              _buildPdfMetricCard('Inventory Value', report.inventoryValue, filter.currency ?? 'YER'),
            ],
          ),
          pw.SizedBox(height: 30),

          pw.Text('Product Performance', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Sold', 'Revenue', 'Cost', 'Profit'],
            data: report.productPerformance.map((p) => [
              p.productName, 
              p.soldCount.toString(),
              p.totalRevenue.toStringAsFixed(0),
              p.totalCost.toStringAsFixed(0),
              p.netProfit.toStringAsFixed(0)
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          
          pw.SizedBox(height: 30),
          pw.Text('Dead Stock Analysis', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Stock', 'Days Inactive'],
            data: report.deadStock.map((d) => [
              d.name,
              d.remainingStock.toString(),
              '${d.daysSinceLastSale} days'
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
          ),

          pw.SizedBox(height: 30),
          pw.Text('Debt Movement', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              ['Total Current Debt', report.debtMovement.totalCurrent.toStringAsFixed(0)],
              ['New Debt (Period)', report.debtMovement.newDebt.toStringAsFixed(0)],
              ['Collected Debt (Period)', report.debtMovement.collectedDebt.toStringAsFixed(0)],
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'bi_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  Future<void> exportCustomerTransactionsToPdf(
    Customer customer,
    List<AppTransaction> transactions,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildCustomerPdfHeader(customer),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['التاريخ', 'النوع', 'البيان', 'المبلغ'],
            data: transactions.map((tx) {
              final isRefund = tx.type == TransactionType.refund;
              final isSale = tx.type == TransactionType.sale;
              final typeStr = isSale
                  ? 'دين (فاتورة)'
                  : (isRefund ? 'إرجاع' : 'تسديد (قبض)');
              return [
                DateFormat('yyyy-MM-dd').format(tx.date),
                typeStr,
                tx.note ?? '',
                '${tx.amount.toStringAsFixed(0)} ${CurrencyHelper.getSymbol(tx.currency)}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellAlignment: pw.Alignment.centerRight,
            columnWidths: {
              0: const pw.FixedColumnWidth(100),
              1: const pw.FixedColumnWidth(100),
              2: const pw.FlexColumnWidth(),
              3: const pw.FixedColumnWidth(120),
            },
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'إجمالي الرصيد المستحق:',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${customer.totalDebt.toStringAsFixed(0)} YER',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red900,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'customer_${customer.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _buildCustomerPdfHeader(Customer customer) {
    final logo = _getLogo();
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'statement_of_account'.tr(),
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('${'customer_name'.tr()}: ${customer.name}'),
              if (customer.phone.isNotEmpty) pw.Text('${'phone_number'.tr()}: ${customer.phone}'),
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

  pw.Widget _buildPdfHeader(ReportFilter filter) {
    final logo = _getLogo();
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Business Performance Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Period: ${DateFormat('yyyy-MM-dd').format(filter.startDate)} - ${DateFormat('yyyy-MM-dd').format(filter.endDate)}'),
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
              pw.Text(_store.storeName ?? 'RASEED App', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
}
