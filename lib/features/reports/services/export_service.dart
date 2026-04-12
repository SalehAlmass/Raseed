
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
    sheet.appendRow([
      TextCellValue('Report Period: ${DateFormat('yyyy-MM-dd').format(filter.startDate)} to ${DateFormat('yyyy-MM-dd').format(filter.endDate)}'),
    ]);
    sheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);

    // Summary
    sheet.appendRow([TextCellValue('Total Sales'), DoubleCellValue(report.totalSales)]);
    sheet.appendRow([TextCellValue('Total Profit'), DoubleCellValue(report.totalProfit)]);
    sheet.appendRow([TextCellValue('Total Debt'), DoubleCellValue(report.totalDebt)]);

    sheet.appendRow([TextCellValue('')]); // Spacer

    // Sales Trend
    sheet.appendRow([TextCellValue('Sales Trend')]);
    sheet.appendRow([TextCellValue('Date/Period'), TextCellValue('Amount')]);
    for (var m in report.salesTrend) {
      sheet.appendRow([TextCellValue(m.label), DoubleCellValue(m.value)]);
    }

    sheet.appendRow([TextCellValue('')]); // Spacer

    // Top Products
    sheet.appendRow([TextCellValue('Top Products')]);
    for (var m in report.topProducts) {
      sheet.appendRow([TextCellValue(m.label), DoubleCellValue(m.value)]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Financial Report Excel');
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
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Period: ${DateFormat('yyyy-MM-dd').format(filter.startDate)} - ${DateFormat('yyyy-MM-dd').format(filter.endDate)}'),
          pw.SizedBox(height: 20),
          
          // Summary Grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfMetricCard('Total Sales', report.totalSales, filter.currency ?? 'YER'),
              _buildPdfMetricCard('Total Profit', report.totalProfit, filter.currency ?? 'YER'),
              _buildPdfMetricCard('Total Debt', report.totalDebt, filter.currency ?? 'YER'),
            ],
          ),
          pw.SizedBox(height: 30),

          pw.Text('Sales Trend', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Label', 'Amount'],
            data: report.salesTrend.map((m) => [m.label, m.value.toStringAsFixed(2)]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 30),

          pw.Text('Top 5 Products', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Total Sales'],
            data: report.topProducts.map((m) => [m.label, m.value.toStringAsFixed(2)]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  pw.Widget _buildPdfMetricCard(String title, double value, String currency) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Text(value.toStringAsFixed(2), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(currency, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}
