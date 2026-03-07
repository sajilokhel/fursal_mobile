import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../bookings/domain/booking.dart';

class ScanVerificationSheet extends StatelessWidget {
  final Booking? booking;
  final String code;
  final String? customerName;
  final String? customerEmail;
  final String? venueAddress;
  final bool isStale;
  final String? errorMessage;
  final VoidCallback onScanNext;
  final VoidCallback onViewDetails;
  final VoidCallback onTryAgain;

  const ScanVerificationSheet({
    super.key,
    required this.booking,
    required this.code,
    this.customerName,
    this.customerEmail,
    this.venueAddress,
    this.isStale = false,
    this.errorMessage,
    required this.onScanNext,
    required this.onViewDetails,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = booking != null;
    final isConfirmed = booking?.status.toLowerCase() == 'confirmed';
    final headerColor =
        isValid && isConfirmed && !isStale ? Colors.green.shade600 : Colors.orange.shade700;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
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

            // Header banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: isValid ? headerColor : Colors.red.shade600,
              child: Row(
                children: [
                  Icon(
                    isValid && isConfirmed && !isStale
                        ? Icons.check_circle
                        : isValid
                            ? Icons.warning_amber_rounded
                            : Icons.error_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isValid && isConfirmed && !isStale
                            ? 'Valid Booking'
                            : isValid
                                ? 'Warning'
                                : 'Invalid QR Code',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
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

            if (!isValid) ...[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage ?? 'No booking found for this QR code.',
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
            ] else ...[
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date / Time / Amount / Status grid
                      Row(
                        children: [
                          Expanded(
                              child: _infoCell('DATE',
                                  booking!.date, Icons.calendar_today)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _infoCell(
                                  'TIME',
                                  '${booking!.startTime} – ${booking!.endTime}',
                                  Icons.access_time)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _infoCell(
                                  'AMOUNT',
                                  'Rs. ${booking!.amount.toStringAsFixed(0)}',
                                  Icons.credit_card,
                                  valueColor: Colors.green.shade700)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _statusCell(booking!.status)),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(),
                      ),

                      // Customer Details
                      _sectionHeader(Icons.person_outline, 'Customer Details'),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailLine('Name',
                                customerName ?? booking!.userName ?? '—'),
                            const SizedBox(height: 6),
                            _detailLine('Email', customerEmail ?? '—'),
                            const SizedBox(height: 6),
                            _detailLine('User ID', booking!.userId,
                                mono: true),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(),
                      ),

                      // Venue
                      _sectionHeader(Icons.place_outlined, 'Venue'),
                      const SizedBox(height: 10),
                      Text(booking!.venueName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      if (venueAddress != null) ...[
                        const SizedBox(height: 4),
                        Text(venueAddress!,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ],

                      const SizedBox(height: 20),
                      // Booking ID
                      Center(
                        child: Text(
                          'Booking ID: ${booking!.id}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onScanNext,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: const Text('Scan Next'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onViewDetails,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: const Text('View Bookings'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(status,
                style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _detailLine(String label, String value, {bool mono = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 13),
        children: [
          TextSpan(
              text: '$label: ',
              style: TextStyle(color: Colors.grey.shade500)),
          TextSpan(
              text: value,
              style: mono
                  ? const TextStyle(fontFamily: 'monospace', fontSize: 11)
                  : const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
