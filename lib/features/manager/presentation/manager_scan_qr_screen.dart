import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../bookings/domain/booking.dart';
import '../../../core/config.dart';
import '../../../core/theme.dart';
import 'widgets/qr_scanner_overlay_shape.dart';
import 'widgets/scan_verification_sheet.dart' show ScanVerificationSheet, VerificationResult;

class ManagerScanQRScreen extends ConsumerStatefulWidget {
  const ManagerScanQRScreen({super.key});

  @override
  ConsumerState<ManagerScanQRScreen> createState() =>
      _ManagerScanQRScreenState();
}

class _ManagerScanQRScreenState extends ConsumerState<ManagerScanQRScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstWhere(
      (b) => b.rawValue != null,
      orElse: () => const Barcode(),
    );
    final code = barcode.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);
    controller.stop(); // stop camera while sheet is open

    // Kick off verification — sheet receives the Future and handles loading
    final future = _verifyQR(code);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => ScanVerificationSheet(
        code: code,
        future: future,
        onScanNext: () {
          Navigator.of(ctx).pop();
          _resetScanner();
        },
        onViewDetails: () {
          Navigator.of(ctx).pop();
          _resetScanner();
          context.push('/manager/bookings');
        },
        onTryAgain: () {
          Navigator.of(ctx).pop();
          _resetScanner();
        },
      ),
    ).then((_) => _resetScanner());
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    controller.start();
  }

  Future<VerificationResult> _verifyQR(String code) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/invoices/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'qr': code}),
      );

      if (response.statusCode == 200) {
        final ct = response.headers['content-type'] ?? '';
        if (ct.contains('application/json')) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final bookingMap = json['booking'] as Map<String, dynamic>?;
          Booking? booking;
          if (bookingMap != null) {
            booking = Booking.fromMap({
              ...bookingMap,
              'id': bookingMap['id'] ?? '',
            });
          }
          final userMap = json['user'] as Map<String, dynamic>?;
          final venueMap = json['venue'] as Map<String, dynamic>?;
          return VerificationResult(
            booking: booking,
            customerName: userMap?['displayName'] as String? ??
                userMap?['name'] as String?,
            customerEmail: userMap?['email'] as String?,
            venueAddress: venueMap?['address'] as String?,
            isStale: json['stale'] == true,
          );
        }
      }

      // Non-200 or non-JSON — try to read error message
      String? errorMessage;
      try {
        final ct = response.headers['content-type'] ?? '';
        if (ct.contains('application/json')) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = json['error'] as String?;
        }
      } catch (_) {}
      return VerificationResult(
          errorMessage: errorMessage ?? 'Server error ${response.statusCode}');
    } catch (e) {
      return VerificationResult(errorMessage: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Scan QR', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/manager');
            }
          },
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.amber);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                return const Icon(Icons.cameraswitch_outlined,
                    color: Colors.white);
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              final isFront = state.cameraDirection == CameraFacing.front;
              // If front camera, mirror the preview horizontally so it feels natural
              final transform = isFront
                  ? Matrix4.rotationY(3.14159) // pi
                  : Matrix4.identity();

              // When mirroring, we rotate around center.
              return Transform(
                alignment: Alignment.center,
                transform: transform,
                child: MobileScanner(
                  controller: controller,
                  onDetect: _handleBarcode,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 40),
                          const SizedBox(height: 16),
                          Text(
                            'Camera Error: ${error.errorCode}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          // Overlay
          Container(
            decoration: const ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: AppTheme.primaryColor,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Align QR code within the frame',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black,
                          offset: Offset(0, 1),
                        )
                      ]),
                ),
                SizedBox(height: 8),
                Text(
                  'Scanning will start automatically',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
