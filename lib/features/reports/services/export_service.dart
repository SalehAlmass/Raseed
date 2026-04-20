
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/report_models.dart';
import '../../../core/utils/currency_helper.dart';
import 'package:intl/intl.dart';

class ExportService {
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

  pw.Widget _buildPdfHeader(ReportFilter filter) {
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
              pw.Text('RASEED App', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
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
