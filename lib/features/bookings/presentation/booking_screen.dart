import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/booking_repository.dart';
import '../data/checkout_state.dart';
import '../domain/booking.dart';
import '../../venues/data/venue_repository.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import 'payment_screen.dart';
import 'booking_detail_screen.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  bool _isInitiatingPayment = false;
  final Set<String> _loadingInvoices = {};
  final Set<String> _verifyingPayments = {};
  final Map<String, int> _visibleItemsCount = {
    'Upcoming Bookings': 3,
    'Pending Payments': 3,
    'Completed': 3,
    'Cancelled & Expired': 3,
  };

  void _showMore(String section) {
    setState(() {
      _visibleItemsCount[section] = (_visibleItemsCount[section] ?? 3) + 10;
    });
  }

  Future<void> _downloadAndOpenInvoice(String bookingId) async {
    setState(() => _loadingInvoices.add(bookingId));
    try {
      final bytes = await BookingService().downloadInvoice(bookingId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice-$bookingId.pdf');
      await file.writeAsBytes(bytes);
      
      if (mounted) {
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingInvoices.remove(bookingId));
    }
  }

  Future<void> _verifyPayment(Booking booking) async {
    final uuid = booking.esewaTransactionUuid;
    if (uuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transaction UUID found to verify.')),
      );
      return;
    }

    // Try to get product code from checkout state or booking field
    // Usually it's in AppConfig but let's see if we have it in checkout notifier first
    final productCode = ref.read(checkoutProvider).productCode ?? 'EPAYTEST';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await BookingService().verifyEsewaPayment(
        transactionUuid: uuid,
        productCode: productCode,
        totalAmount: booking.amount,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        _showEsewaVerificationResult(result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment verification failed: $e')),
        );
      }
    }
  }

  void _showEsewaVerificationResult(Map<String, dynamic> result) {
    final verified = result['verified'] == true;
    final status = result['status'] ?? 'UNKNOWN';
    final bookingConfirmed = result['bookingConfirmed'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              verified ? Icons.check_circle : Icons.error_outline,
              color: verified ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Payment Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('eSewa Status: $status'),
            const SizedBox(height: 8),
            if (verified && bookingConfirmed)
              const Text('✅ Your booking has been confirmed!',
                  style: TextStyle(fontWeight: FontWeight.bold))
            else if (verified && !bookingConfirmed)
              const Text('⚠️ Payment received but booking update pending.',
                  style: TextStyle(color: Colors.orange))
            else
              Text('Message: ${result['message'] ?? 'Payment not completed or found.'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Verify QR')),
          body: MobileScanner(
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue;
                if (code != null) {
                  Navigator.of(context).pop(); // Close scanner
                  _verifyQr(code);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _verifyQr(String qr) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await BookingService().verifyInvoiceQr(qr);
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        _showVerificationResult(result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    }
  }

  void _showVerificationResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) {
        final booking = result['booking'] ?? {};
        final venue = result['venue'] ?? {};
        final status = booking['status'] ?? 'N/A';
        final isStale = result['stale'] == true;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                result['ok'] == true ? Icons.check_circle : Icons.error,
                color: result['ok'] == true ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              const Text('Verification Result'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isStale)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '⚠️ WARNING: STALE QR CODE',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              Text('Venue: ${venue['name'] ?? 'N/A'}'),
              Text('Booking ID: ${booking['id'] ?? 'N/A'}'),
              Text('Status: ${status.toString().toUpperCase()}'),
              Text('Date: ${booking['date'] ?? 'N/A'}'),
              Text('Time: ${booking['startTime'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('User: ${result['user']?.toString() ?? 'N/A'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initiatePaymentAndNavigate(Booking booking) async {
    setState(() => _isInitiatingPayment = true);

    try {
      // Reset and set booking in checkout state
      ref.read(checkoutProvider.notifier).reset();
      ref.read(checkoutProvider.notifier).setBooking(booking);

      // Initiate payment
      final paymentService = PaymentService();
      // Ask backend to compute amount (this returns computed metadata)
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
  void initState() {
    super.initState();
    // Booking expiration is now handled by the backend
    // No need to check/expire bookings from the client since Firestore rules
    // deny direct writes to the bookings collection
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Please login to view bookings')));
    }

    final bookingsAsync = ref.watch(userBookingsProvider(user.uid));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Bookings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Bookings Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your sports schedules will appear here.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Find a Venue',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildBookingSection(context, 'Upcoming Bookings',
                  _getUpcomingBookings(bookings)),
              _buildBookingSection(context, 'Pending Payments',
                  _getPaymentPendingBookings(bookings)),
              _buildBookingSection(
                  context, 'Completed', _getCompletedBookings(bookings)),
              _buildBookingSection(context, 'Cancelled & Expired',
                  _getCancelledExpiredBookings(bookings)),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  List<Booking> _getUpcomingBookings(List<Booking> bookings) {
    final now = DateTime.now();
    return bookings.where((b) {
      final startDateTime = _parseDateTime(b.date, b.startTime);
      final isConfirmed = b.status == 'booked' || b.status == 'confirmed';
      // Upcoming: Confirmed AND starting in the future (payment status does not block)
      return isConfirmed && startDateTime.isAfter(now);
    }).toList();
  }

  List<Booking> _getCompletedBookings(List<Booking> bookings) {
    final now = DateTime.now();
    return bookings.where((b) {
      final endDateTime = _parseDateTime(b.date, b.endTime);
      final isConfirmed = b.status == 'booked' || b.status == 'confirmed';
      // Completed: Confirmed AND time has passed
      return isConfirmed && endDateTime.isBefore(now);
    }).toList();
  }

  List<Booking> _getPaymentPendingBookings(List<Booking> bookings) {
    final now = DateTime.now();
    return bookings.where((b) {
      final endDateTime = _parseDateTime(b.date, b.endTime);

      // If time passed, it's expired or missed, not pending payment
      if (endDateTime.isBefore(now)) return false;

      // Specifically check for booking status being pending
      final isPendingStatus =
          b.status == 'pending' || b.status == 'pending_payment';
      
      // Also check if slot hold is still valid
      final isHoldValid =
          b.holdExpiresAt == null || b.holdExpiresAt!.toDate().isAfter(now);

      return isPendingStatus && isHoldValid;
    }).toList();
  }

  List<Booking> _getCancelledExpiredBookings(List<Booking> bookings) {
    final now = DateTime.now();
    return bookings.where((b) {
      final endDateTime = _parseDateTime(b.date, b.endTime);
      final isCancelled = b.status == 'cancelled';
      final isExplicitlyExpired = b.status == 'expired';

      final isPendingButExpired = b.status == 'pending' &&
          ((b.holdExpiresAt != null &&
                  b.holdExpiresAt!.toDate().isBefore(now)) ||
              endDateTime.isBefore(now) // Slot passed but still pending
          );

      return isCancelled || isExplicitlyExpired || isPendingButExpired;
    }).toList();
  }

  DateTime _parseDateTime(String date, String time) {
    try {
      return DateTime.parse('$date $time:00');
    } catch (e) {
      return DateTime.now(); // Fallback
    }
  }

  Widget _buildBookingSection(
      BuildContext context, String title, List<Booking> bookings) {
    if (bookings.isEmpty) return const SizedBox.shrink();

    final visibleCount = _visibleItemsCount[title] ?? 3;
    final visibleBookings = bookings.take(visibleCount).toList();
    final hasMore = bookings.length > visibleCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          listTileTheme: ListTileTheme.of(context).copyWith(
            dense: true,
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          maintainState: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          collapsedShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${bookings.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
          children: [
            ...visibleBookings.map((booking) => _buildBookingCard(booking)),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _showMore(title),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Text(
                      'Show More (${bookings.length - visibleCount})',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final theme = Theme.of(context);
    final isUpcoming = _getUpcomingBookings([booking]).isNotEmpty;
    final isPendingPayment = _getPaymentPendingBookings([booking]).isNotEmpty;
    final isCompleted = _getCompletedBookings([booking]).isNotEmpty;
    final isCancelled = _getCancelledExpiredBookings([booking]).isNotEmpty;

    String statusText = 'Unknown';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;

    if (isUpcoming) {
      statusText = 'Confirmed';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (isPendingPayment) {
      statusText = 'Pending Payment';
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
    } else if (isCompleted) {
      statusText = 'Completed';
      statusColor = Colors.blue;
      statusIcon = Icons.done;
    } else if (isCancelled) {
      statusText = booking.status == 'cancelled' ? 'Cancelled' : 'Expired';
      statusColor = Colors.red.shade400;
      statusIcon = Icons.cancel_outlined;
    }

    return InkWell(
      onTap: () {
        if (isPendingPayment) {
          _initiatePaymentAndNavigate(booking);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BookingDetailScreen(booking: booking),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (booking.venueName.startsWith('Venue #'))
                        ref.watch(venueProvider(booking.venueId)).when(
                              data: (venue) => Text(
                                venue?.name ?? booking.venueName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              loading: () => Text(
                                booking.venueName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              error: (_, __) => Text(
                                booking.venueName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                      else
                        Text(
                          booking.venueName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${booking.date} • ${booking.startTime}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPendingPayment)
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isInitiatingPayment
                            ? null
                            : () => _initiatePaymentAndNavigate(booking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isInitiatingPayment
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Pay Now',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _verifyPayment(booking),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh, size: 14),
                            SizedBox(width: 4),
                            Text('Verify', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey.shade400),
              ],
            ),
            if (isUpcoming || isCompleted) ...[
              const Divider(height: 1, indent: 72),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _loadingInvoices.contains(booking.id)
                          ? null
                          : () => _downloadAndOpenInvoice(booking.id),
                      icon: _loadingInvoices.contains(booking.id)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.blue))
                          : const Icon(Icons.download, size: 14),
                      label: const Text('Download Invoice',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.blue.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
