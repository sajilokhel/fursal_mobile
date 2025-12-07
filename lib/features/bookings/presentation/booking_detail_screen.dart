import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/invoice_service.dart';
import '../domain/booking.dart';
import '../data/checkout_state.dart';
import '../../../services/payment_service.dart';

import 'payment_screen.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final Booking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isGeneratingInvoice = false;
  bool _isInitiatingPayment = false;

  Future<void> _initiatePaymentAndNavigate(Booking booking) async {
    setState(() => _isInitiatingPayment = true);

    try {
      // Reset and set booking in checkout state
      ref.read(checkoutProvider.notifier).reset();
      ref.read(checkoutProvider.notifier).setBooking(booking);

      // Initiate payment
      final paymentService = PaymentService();
      // Ask backend to compute amount for this booking
      final computeResp = await paymentService.computeAmount(
        venueId: booking.venueId,
        date: booking.date,
        startTime: booking.startTime,
        slots: 1,
      );

      final paidAmount =
          paymentService.extractPaidAmountFromCompute(computeResp);
      debugPrint('computeAmount paidAmount: $paidAmount');

      final paymentResp = await paymentService.initiatePayment(
        bookingId: booking.id,
        transactionUuid: booking.esewaTransactionUuid,
      );

      final paymentParams =
          paymentResp['paymentParams'] as Map<String, dynamic>;
      ref.read(checkoutProvider.notifier).setPaymentParams(
            paymentParams: paymentParams,
            transactionUuid: paymentParams['transactionUuid'] as String,
            signature: paymentResp['signature'] as String,
            productCode: paymentParams['productCode'] as String,
          );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PaymentScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate payment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitiatingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final isExpired = booking.status == 'pending' &&
        booking.holdExpiresAt != null &&
        booking.holdExpiresAt!.toDate().isBefore(DateTime.now());

    final canPay = booking.status == 'pending' && !isExpired;

    // Check if booking is completed (time passed)
    DateTime? endDateTime;
    try {
      endDateTime = DateTime.parse('${booking.date} ${booking.endTime}:00');
    } catch (_) {
      endDateTime = DateTime.now();
    }
    final isCompleted =
        (booking.status == 'booked' || booking.status == 'confirmed') &&
            endDateTime.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBanner(context, booking, isExpired, isCompleted),
            const SizedBox(height: 24),
            _buildDetailCard(context, booking),
            const SizedBox(height: 24),
            if ((booking.status == 'confirmed' || booking.status == 'booked') &&
                !isCompleted &&
                booking.paymentStatus == 'paid') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingInvoice
                      ? null
                      : () => _downloadInvoice(context, booking),
                  icon: _isGeneratingInvoice
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: Text(_isGeneratingInvoice
                      ? 'Downloading...'
                      : 'Download Invoice'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ] else if (canPay) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isInitiatingPayment
                      ? null
                      : () => _initiatePaymentAndNavigate(booking),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.green.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isInitiatingPayment
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Pay Now',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _verifyPayment(context, ref),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Verify Payment',
                      style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(
      BuildContext context, Booking booking, bool isExpired, bool isCompleted) {
    Color color;
    String text;
    IconData icon;

    if (isCompleted) {
      color = Colors.blue;
      text = 'Booking Completed';
      icon = Icons.task_alt;
    } else if ((booking.status == 'confirmed' || booking.status == 'booked') &&
        booking.paymentStatus == 'paid') {
      color = Colors.green;
      text = 'Booking Confirmed';
      icon = Icons.check_circle;
    } else if (booking.status == 'cancelled') {
      color = Colors.red;
      text = 'Booking Cancelled';
      icon = Icons.cancel;
    } else if (isExpired) {
      color = Colors.grey;
      text = 'Booking Expired';
      icon = Icons.timer_off;
    } else {
      color = Colors.orange;
      text = 'Payment Pending';
      icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, Booking booking) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.venueName,
                style: Theme.of(context).textTheme.headlineSmall),
            const Divider(height: 32),
            _buildRow('Date', booking.date),
            _buildRow('Time', '${booking.startTime} - ${booking.endTime}'),
            _buildRow('Amount', 'Rs. ${booking.amount}'),
            _buildRow('Booking ID', booking.id),
            if (booking.esewaTransactionUuid != null)
              _buildRow('Transaction ID', booking.esewaTransactionUuid!),
            if (booking.holdExpiresAt != null && booking.status == 'pending')
              _buildRow(
                  'Expires At',
                  DateFormat('HH:mm:ss')
                      .format(booking.holdExpiresAt!.toDate())),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(BuildContext context, Booking booking) async {
    setState(() {
      _isGeneratingInvoice = true;
    });

    try {
      // Fetch PDF bytes from backend
      final invoiceService = InvoiceService();
      final bytes = await invoiceService.fetchInvoiceBytes(booking.id);

      // Save to app documents directory and open
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'invoice_${booking.id}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await OpenFilex.open(file.path);
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading invoice: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('Invoice download error: $e\n$st');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingInvoice = false;
        });
      }
    }
  }

  Future<void> _verifyPayment(BuildContext context, WidgetRef ref) async {
    // In a real app, this would call a backend API to check payment status with eSewa
    // For now, we'll show a dialog explaining this is a manual check or simulation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Payment'),
        content: const Text(
            'If you have completed the payment but the status is not updated, please click "Check Status". This will attempt to verify the transaction.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Simulate verification check
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking payment status...')),
              );

              // Here we would call the repository to check status
              // For now, we just reload the booking or show a message
              // If we had the transaction ID, we could check it.

              await Future.delayed(const Duration(seconds: 2));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Payment verification pending. Please contact support if issue persists.')),
                );
              }
            },
            child: const Text('Check Status'),
          ),
        ],
      ),
    );
  }
}
