import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../bookings/domain/booking.dart';
import 'scan_detail_row.dart';

class ScanVerificationSheet extends StatelessWidget {
  final Booking? booking;
  final String code;
  final VoidCallback onScanNext;
  final VoidCallback onViewDetails;
  final VoidCallback onTryAgain;

  const ScanVerificationSheet({
    super.key,
    required this.booking,
    required this.code,
    required this.onScanNext,
    required this.onViewDetails,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (booking != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: booking!.status == 'confirmed'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  booking!.status == 'confirmed'
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 48,
                  color: booking!.status == 'confirmed'
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              booking!.status == 'confirmed'
                  ? 'Booking Verified'
                  : 'Booking Status: ${booking!.status.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ScanDetailRow(
              icon: Icons.person_outline,
              label: 'Customer',
              value: booking!.userId, // Use name if available
            ),
            const SizedBox(height: 12),
            ScanDetailRow(
              icon: Icons.stadium_outlined,
              label: 'Venue',
              value: booking!.venueName,
            ),
            const SizedBox(height: 12),
            ScanDetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date & Time',
              value:
                  '${booking!.date}\n${booking!.startTime} - ${booking!.endTime}',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onScanNext,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Scan Next'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onViewDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 48, color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Invalid QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No booking found for the scanned code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Code: $code',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTryAgain,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.grey.shade900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
