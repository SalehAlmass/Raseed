import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_transaction.dart';
import '../models/customer.dart';
import '../utils/currency_helper.dart';

class ReceiptService {
  Future<void> printReceipt(AppTransaction transaction, {Customer? customer}) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    // Receipt Size: 80mm width (approx 226 points)
    const pageWidth = 80 * PdfPageFormat.mm;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(pageWidth, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Text('RASEED App', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('تطبيق رصيد لإدارة المخزون', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              
              // Transaction Info
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(transaction.date)}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('رقم العملية: #${transaction.id ?? "NEW"}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (customer != null) ...[
                pw.SizedBox(height: 5),
                pw.Text('العميل: ${customer.name}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Items Table
              pw.SizedBox(height: 5),
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('الصنف', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('الكمية', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('الإجمالي', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
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
                      pw.Expanded(flex: 2, child: pw.Text(item.total.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                )),
              
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Totals
              pw.SizedBox(height: 5),
              _buildTotalRow('الإجمالي الكلي:', transaction.amount),
              if (transaction.paidAmount > 0)
                _buildTotalRow('المبلغ المدفوع:', transaction.paidAmount),
              if (transaction.amount - transaction.paidAmount > 0)
                _buildTotalRow('المبلغ المتبقي (دين):', transaction.amount - transaction.paidAmount, isBold: true),
              
              pw.SizedBox(height: 20),
              pw.Text('شكراً لزيارتكم!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('www.raseed.com', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
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
