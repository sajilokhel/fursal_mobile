import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../bookings/data/booking_repository.dart';
import '../../bookings/domain/booking.dart';
import '../../../core/theme.dart';
import 'widgets/qr_scanner_overlay_shape.dart';
import 'widgets/scan_verification_sheet.dart';

class ManagerScanQRScreen extends ConsumerStatefulWidget {
  const ManagerScanQRScreen({super.key});

  @override
  ConsumerState<ManagerScanQRScreen> createState() =>
      _ManagerScanQRScreenState();
}

class _ManagerScanQRScreenState extends ConsumerState<ManagerScanQRScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final code = barcode.rawValue!;

        setState(() {
          _isProcessing = true;
        });

        // Feedback sound or vibration could go here

        try {
          // Fetch booking
          final booking =
              await ref.read(bookingRepositoryProvider).getBookingById(code);

          if (mounted) {
            _showVerificationSheet(context, booking, code);
          }
        } catch (e) {
          if (mounted) {
            _showVerificationSheet(context, null, code);
          }
        }
        break; // Process only first valid code
      }
    }
  }

  void _showVerificationSheet(
      BuildContext context, Booking? booking, String code) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false, // Prevent accidental dismissal during processing
      builder: (ctx) => ScanVerificationSheet(
        booking: booking,
        code: code,
        onScanNext: () {
          setState(() {
            _isProcessing = false;
          });
          Navigator.of(ctx).pop();
        },
        onViewDetails: () {
          context.push('/manager/bookings');
          setState(() {
            _isProcessing = false;
          });
          Navigator.of(ctx).pop();
        },
        onTryAgain: () {
          setState(() {
            _isProcessing = false;
          });
          Navigator.of(ctx).pop();
        },
      ),
    ).then((_) {
      // Reset processing state if sheet is dismissed by other means
      if (_isProcessing) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
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
          onPressed: () => context.pop(),
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
