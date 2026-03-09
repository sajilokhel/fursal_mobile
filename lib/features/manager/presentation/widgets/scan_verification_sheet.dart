import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../bookings/domain/booking.dart';
import 'booking_detail_sheet.dart';

// ---------------------------------------------------------------------------
// Result model
// ---------------------------------------------------------------------------

class VerificationResult {
  final Booking? booking;
  final String? customerName;
  final String? customerEmail;
  final String? venueAddress;
  final bool isStale;
  final String? errorMessage;

  const VerificationResult({
    this.booking,
    this.customerName,
    this.customerEmail,
    this.venueAddress,
    this.isStale = false,
    this.errorMessage,
  });
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class ScanVerificationSheet extends StatefulWidget {
  final String code;
  final Future<VerificationResult> future;
  final VoidCallback onScanNext;
  final VoidCallback onTryAgain;

  const ScanVerificationSheet({
    super.key,
    required this.code,
    required this.future,
    required this.onScanNext,
    required this.onTryAgain,
  });

  @override
  State<ScanVerificationSheet> createState() => _ScanVerificationSheetState();
}

class _ScanVerificationSheetState extends State<ScanVerificationSheet>
    with SingleTickerProviderStateMixin {
  VerificationResult? _result;
  bool _loading = true;
  Object? _fatalError;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    widget.future.then((result) {
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
        _fadeController.forward();
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _fatalError = e;
          _loading = false;
        });
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Content area
            Expanded(
              child: _loading
                  ? _LoadingView()
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: _ResultView(
                        result: _result,
                        fatalError: _fatalError,
                        scrollController: scrollController,
                        onScanNext: onScanNext,
                        onTryAgain: onTryAgain,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback get onScanNext => widget.onScanNext;
  VoidCallback get onTryAgain => widget.onTryAgain;
}

// ---------------------------------------------------------------------------
// Loading view
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Verifying QR Code...',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Checking booking with server',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Result dispatcher
// ---------------------------------------------------------------------------

class _ResultView extends StatelessWidget {
  final VerificationResult? result;
  final Object? fatalError;
  final ScrollController scrollController;
  final VoidCallback onScanNext;
  final VoidCallback onTryAgain;

  const _ResultView({
    required this.result,
    required this.fatalError,
    required this.scrollController,
    required this.onScanNext,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return _ErrorBody(
        message: fatalError?.toString() ?? 'Unknown error occurred.',
        scrollController: scrollController,
        onTryAgain: onTryAgain,
      );
    }
    final booking = result!.booking;
    if (booking == null) {
      return _ErrorBody(
        message: result!.errorMessage ?? 'No booking found for this QR code.',
        scrollController: scrollController,
        onTryAgain: onTryAgain,
      );
    }
    return _BookingBody(
      booking: booking,
      customerName: result!.customerName,
      customerEmail: result!.customerEmail,
      venueAddress: result!.venueAddress,
      isStale: result!.isStale,
      scrollController: scrollController,
      onScanNext: onScanNext,
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  final String message;
  final ScrollController scrollController;
  final VoidCallback onTryAgain;

  const _ErrorBody({
    required this.message,
    required this.scrollController,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: Colors.red.shade600,
          child: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Invalid QR Code',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Icon(Icons.qr_code_scanner,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTryAgain,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Booking success body
// ---------------------------------------------------------------------------

class _BookingBody extends StatelessWidget {
  final Booking booking;
  final String? customerName;
  final String? customerEmail;
  final String? venueAddress;
  final bool isStale;
  final ScrollController scrollController;
  final VoidCallback onScanNext;

  const _BookingBody({
    required this.booking,
    this.customerName,
    this.customerEmail,
    this.venueAddress,
    required this.isStale,
    required this.scrollController,
    required this.onScanNext,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirmed = booking.status.toLowerCase() == 'confirmed';
    final headerColor = isConfirmed && !isStale
        ? Colors.green.shade600
        : Colors.orange.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: headerColor,
          child: Row(
            children: [
              Icon(
                isConfirmed && !isStale
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConfirmed && !isStale ? 'Valid Booking' : 'Warning',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  if (isStale)
                    const Text(
                      'QR timestamp is older than 24 hours',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date / Time / Amount / Status grid
                Row(
                  children: [
                    Expanded(
                        child: _infoCell(
                            'DATE', booking.date, Icons.calendar_today)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _infoCell(
                            'TIME',
                            '${booking.startTime} – ${booking.endTime}',
                            Icons.access_time)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _infoCell(
                            'AMOUNT',
                            'Rs. ${booking.amount.toStringAsFixed(0)}',
                            Icons.credit_card,
                            valueColor: Colors.green.shade700)),
                    const SizedBox(width: 12),
                    Expanded(child: _statusCell(booking.status)),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Compact customer row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_outline,
                          size: 18, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName ?? booking.userName ?? '—',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          if ((customerEmail ?? '').isNotEmpty)
                            Text(
                              customerEmail!,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onScanNext,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Scan Next'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _openDetail(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => BookingDetailSheet(
          booking: booking,
          initialCustomerName: customerName,
          initialCustomerEmail: customerEmail,
        ),
      ),
    );
  }

  Widget _infoCell(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 14, color: valueColor ?? AppTheme.primaryColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: valueColor ?? Colors.black87)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCell(String status) {
    final isConf = status.toLowerCase() == 'confirmed';
    final bg = isConf ? Colors.green.shade50 : Colors.orange.shade50;
    final fg = isConf ? Colors.green.shade700 : Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATUS',
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(status,
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
