import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../bookings/domain/booking.dart';

class BookingDetailSheet extends ConsumerStatefulWidget {
  final Booking booking;

  const BookingDetailSheet({required this.booking, super.key});

  @override
  ConsumerState<BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends ConsumerState<BookingDetailSheet> {
  AuthUser? _user;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    final user = await ref
        .read(authRepositoryProvider)
        .getUserData(widget.booking.userId);
    if (mounted) {
      setState(() {
        _user = user;
        _isLoadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final isOnline = booking.bookingType != 'manual';
    final isPaid =
        ['confirmed', 'booked'].contains(booking.status.toLowerCase());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Center(
            child: Column(
              children: [
                Text(
                  booking.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs. ${booking.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Booking Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildDetailRow('Venue', booking.venueName),
          _buildDetailRow('Date', booking.date),
          _buildDetailRow('Time', '${booking.startTime} - ${booking.endTime}'),
          _buildDetailRow('Booking ID', booking.id),
          const SizedBox(height: 24),
          const Text('Payment Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildDetailRow(
              'Method', isOnline ? 'Online (eSewa)' : 'Physical / Cash'),
          if (booking.esewaTransactionCode != null)
            _buildDetailRow('Transaction Ref', booking.esewaTransactionCode!),
          _buildDetailRow(
              'Payment Date',
              booking.paymentTimestamp != null
                  ? DateFormat('MMM d, y HH:mm')
                      .format(booking.paymentTimestamp!.toDate())
                  : '-'),
          const SizedBox(height: 24),
          const Text('Customer Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_isLoadingUser)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildDetailRow('Name', _user?.displayName ?? 'Guest User'),
            _buildDetailRow('Email', _user?.email ?? '-'),
            _buildDetailRow('User ID', booking.userId),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          SelectableText(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
