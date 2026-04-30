import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/app_transaction.dart';
import '../models/customer.dart';
import '../models/app_settings.dart';
import 'settings_service.dart';
import '../di/injection_container.dart';
import 'package:intl/intl.dart';

class PrinterService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  Future<void> printReceipt({
    required BluetoothDevice device,
    required AppTransaction transaction,
    Customer? customer,
    required PaperSize paperSize,
  }) async {
    bool? isConnected = await _bluetooth.isConnected;
    if (!isConnected!) {
      await _bluetooth.connect(device);
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    final settings = sl<SettingsService>().settings;
    final store = settings.storeProfile;

    // Header
    bytes += generator.text(store.storeName ?? 'RASEED App',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));
    
    if (store.phone != null) {
      bytes += generator.text(store.phone!, styles: const PosStyles(align: PosAlign.center));
    }
    if (store.address != null) {
      bytes += generator.text(store.address!, styles: const PosStyles(align: PosAlign.center));
    }
    
    bytes += generator.hr();
    
    // Transaction Details
    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(transaction.date)}');
    bytes += generator.text('Invoice: #${transaction.id ?? "NEW"}');
    if (customer != null) {
      bytes += generator.text('Customer: ${customer.name}');
    }
    
    bytes += generator.hr();

    // Items
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: 'Total', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);

    for (var item in transaction.items) {
      bytes += generator.row([
        PosColumn(text: item.productName, width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: item.quantity.toString(), width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: item.total.toStringAsFixed(0), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    // Totals
    bytes += generator.row([
      PosColumn(text: 'Total Amount:', width: 8, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: transaction.amount.toStringAsFixed(0), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    if (transaction.paidAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Paid:', width: 8, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: transaction.paidAmount.toStringAsFixed(0), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    double remaining = transaction.amount - transaction.paidAmount;
    if (remaining > 0) {
      bytes += generator.row([
        PosColumn(text: 'Remaining:', width: 8, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: remaining.toStringAsFixed(0), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.feed(2);
    bytes += generator.text('Thank you for shopping!', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(3);
    bytes += generator.cut();

    await _bluetooth.writeBytes(Uint8List.fromList(bytes));
  }
}
