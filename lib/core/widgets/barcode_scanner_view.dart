import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/colors.dart';

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key});

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  MobileScannerController? controller;
  bool _isScanned = false;

  bool get _isUnsupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    if (!_isUnsupportedPlatform) {
      controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnsupportedPlatform) {
      return _buildFallbackScanner();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on),
            iconSize: 32.0,
            onPressed: () => controller?.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.camera_rear),
            iconSize: 32.0,
            onPressed: () => controller?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (controller != null)
            MobileScanner(
              controller: controller!,
              onDetect: (capture) {
                if (_isScanned) return;
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    _isScanned = true;
                    // Stop the camera gracefully to release buffer locks before popping
                    controller?.stop();
                    Navigator.pop(context, code);
                  }
                }
              },
            ),
          // Custom Overlay
          Center(
            child: Container(
              width: 250.w,
              height: 250.w,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 4),
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
          ),
          Positioned(
            bottom: 50.h,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Align barcode within the frame',
                style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackScanner() {
    final TextEditingController textController = TextEditingController();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.textPrimary,
      ),
      backgroundColor: colors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.barcode_reader,
                size: 80.r,
                color: colors.textSecondary,
              ),
              SizedBox(height: 24.h),
              Text(
                'Scanning not supported on this platform',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Please enter or scan the barcode manually below:',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Container(
                constraints: BoxConstraints(maxWidth: 400.w),
                child: TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Barcode Number',
                    hintText: 'e.g. 1234567890',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        final code = textController.text.trim();
                        if (code.isNotEmpty) {
                          Navigator.pop(context, code);
                        }
                      },
                    ),
                  ),
                  onSubmitted: (code) {
                    final trimmed = code.trim();
                    if (trimmed.isNotEmpty) {
                      Navigator.pop(context, trimmed);
                    }
                  },
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () {
                  final code = textController.text.trim();
                  if (code.isNotEmpty) {
                    Navigator.pop(context, code);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
