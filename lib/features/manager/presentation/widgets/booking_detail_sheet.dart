import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../bookings/data/booking_repository.dart';
import '../../../bookings/domain/booking.dart';
import '../../../../core/config.dart';
import '../../../../core/theme.dart';

class BookingDetailSheet extends ConsumerStatefulWidget {
  final Booking booking;
  /// Pre-filled customer name from QR verify API — skips the Firestore fetch.
  final String? initialCustomerName;
  /// Pre-filled customer email from QR verify API — skips the Firestore fetch.
  final String? initialCustomerEmail;
  /// Called after a successful mark-paid API call (e.g. to invalidate providers).
  final VoidCallback? onMarkPaidSuccess;

  const BookingDetailSheet({
    required this.booking,
    this.initialCustomerName,
    this.initialCustomerEmail,
    this.onMarkPaidSuccess,
    super.key,
  });

  @override
  ConsumerState<BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends ConsumerState<BookingDetailSheet> {
  AuthUser? _user;
  bool _isLoadingUser = true;
  bool _markingPaid = false;

  // Fresh copy of the booking fetched from Firestore on open so payment
  // status is always up-to-date (QR payload may be from before payment).
  Booking? _freshBooking;
  bool _fetchingPaymentStatus = true;

  @override
  void initState() {
    super.initState();
    // Skip Firestore user fetch if caller already supplied customer data
    if (widget.initialCustomerName != null ||
        widget.initialCustomerEmail != null) {
      _isLoadingUser = false;
    } else {
      _fetchUser();
    }
    // Always re-fetch the booking itself so we get the current payment status
    _fetchFreshBooking();
  }

  Future<void> _fetchFreshBooking() async {
    final fresh = await ref
        .read(bookingRepositoryProvider)
        .getBookingById(widget.booking.id);
    if (mounted) {
      setState(() {
        _freshBooking = fresh;
        _fetchingPaymentStatus = false;
      });
    }
  }

  // The freshest booking data available — falls back to widget.booking while loading.
  Booking get _activeBooking => _freshBooking ?? widget.booking;

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  double get _dueAmount {
    final b = _activeBooking;
    // Trust the explicit dueAmount from Firestore when present (set/cleared by API)
    if (b.dueAmount != null) return b.dueAmount!;
    // Fall back to computed value for older records
    final isPhysical =
        b.bookingType == 'physical' || b.bookingType == 'manual';
    if (isPhysical) return b.amount;
    return b.amount - (b.esewaAmount ?? 0);
  }

  bool get _hasDue =>
      !_fetchingPaymentStatus &&
      _dueAmount > 0 &&
      _activeBooking.status.toLowerCase() != 'cancelled' &&
      !_activeBooking.isFullyPaid;

  String get _displayName =>
      widget.initialCustomerName ?? _user?.displayName ?? 'Guest User';

  String get _displayEmail =>
      widget.initialCustomerEmail ?? _user?.email ?? '—';

  // ── Mark-paid ─────────────────────────────────────────────────────────────

  Future<void> _markPaid() async {
    final booking = _activeBooking;
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rs. ${_dueAmount.toStringAsFixed(0)} due from $_displayName',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('How was it paid?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PayMethodButton(
                    label: 'Cash',
                    icon: Icons.payments_outlined,
                    onTap: () => Navigator.pop(ctx, 'cash'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PayMethodButton(
                    label: 'Online',
                    icon: Icons.phone_android,
                    onTap: () => Navigator.pop(ctx, 'online'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (method == null || !mounted) return;

    setState(() => _markingPaid = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      final client = http.Client();
      http.Response resp;
      try {
        final uri = Uri.parse(
            '${AppConfig.apiUrl}/manager/bookings/${booking.id}/mark-paid');
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final encodedBody = jsonEncode({'paymentMethod': method});

        Future<http.Response> doPost(Uri target) async {
          final req = http.Request('POST', target)
            ..followRedirects = false
            ..headers.addAll(headers)
            ..body = encodedBody;
          return http.Response.fromStream(await client.send(req));
        }

        resp = await doPost(uri);
        if ((resp.statusCode == 307 || resp.statusCode == 308) &&
            resp.headers['location'] != null) {
          final loc = resp.headers['location']!;
          final redirUri = Uri.parse(loc).isAbsolute
              ? Uri.parse(loc)
              : Uri.parse('${AppConfig.backendBaseUrl}$loc');
          resp = await doPost(redirUri);
        }
      } finally {
        client.close();
      }

      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Marked as paid ✅'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ));
        widget.onMarkPaidSuccess?.call();
        if (mounted) Navigator.of(context).pop();
      } else {
        String errMsg = 'Failed (${resp.statusCode})';
        try {
          final ct = resp.headers['content-type'] ?? '';
          if (ct.contains('application/json')) {
            final body = jsonDecode(resp.body);
            errMsg = body['error'] ?? errMsg;
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errMsg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final booking = _activeBooking;
    final isOnline = booking.bookingType != 'manual' &&
        booking.bookingType != 'physical';
    final statusColor = _statusColor(booking.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
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
          const SizedBox(height: 20),

          // ── Hero amount + status ─────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rs. ${booking.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (_hasDue) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Rs. ${_dueAmount.toStringAsFixed(0)} due',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Booking Details ──────────────────────────────────────────────
          _sectionTitle('Booking Details'),
          const SizedBox(height: 12),
          _detailCard([
            _row('Venue', booking.venueName),
            _row('Date', booking.date),
            _row('Time', '${booking.startTime} – ${booking.endTime}'),
            _row('Booking ID', booking.id, mono: true),
          ]),

          const SizedBox(height: 20),

          // ── Payment Information ──────────────────────────────────────────
          _sectionTitle('Payment'),
          const SizedBox(height: 12),
          if (_fetchingPaymentStatus)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 10),
                  Text('Checking payment status…',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            )
          else
            _detailCard([
              _row('Method',
                  isOnline ? 'Online (eSewa)' : 'Physical / Cash'),
              if (booking.esewaAmount != null && booking.esewaAmount! > 0)
                _row('Paid via eSewa',
                    'Rs. ${booking.esewaAmount!.toStringAsFixed(0)}'),
              // Due amount rows
              if (_hasDue)
                _row('Due Amount',
                    'Rs. ${_dueAmount.toStringAsFixed(0)}',
                    valueColor: Colors.orange.shade700),
              if (!_hasDue && booking.isFullyPaid && booking.duePaymentMethod != null)
                _row('Due Paid',
                    'Rs. ${(widget.booking.dueAmount ?? _dueAmount).toStringAsFixed(0)} via ${booking.duePaymentMethod}',
                    valueColor: Colors.green.shade700),
              if (booking.duePaidAt != null)
                _row('Due Paid On',
                    DateFormat('MMM d, y  HH:mm')
                        .format(booking.duePaidAt!.toDate())),
              if (booking.esewaTransactionCode != null)
                _row('Transaction Ref', booking.esewaTransactionCode!,
                    mono: true),
              _row(
                'Payment Date',
                booking.paymentTimestamp != null
                    ? DateFormat('MMM d, y  HH:mm')
                        .format(booking.paymentTimestamp!.toDate())
                    : '—',
              ),
            ]),

          const SizedBox(height: 20),

          // ── Customer Details ─────────────────────────────────────────────
          _sectionTitle('Customer'),
          const SizedBox(height: 12),
          if (_isLoadingUser)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator()))
          else
            _detailCard([
              _row('Name', _displayName),
              _row('Email', _displayEmail),
              _row('User ID', booking.userId, mono: true),
            ]),

          const SizedBox(height: 28),

          // ── Mark as Paid button ──────────────────────────────────────────
          if (_hasDue)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _markingPaid ? null : _markPaid,
                icon: _markingPaid
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_markingPaid ? 'Processing…' : 'Mark as Paid'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'booked':
        return Colors.green.shade600;
      case 'pending':
        return Colors.orange.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
            letterSpacing: 0.3),
      );

  Widget _detailCard(List<Widget> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Divider(height: 1, color: Colors.grey.shade200),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool mono = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? Colors.black87,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pay method dialog button ──────────────────────────────────────────────────

class _PayMethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PayMethodButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.green.shade700, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
