import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:http/http.dart' as http;
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_user.dart';
import '../data/manager_stats_provider.dart';
import '../data/manager_payments_provider.dart';
import '../../venues/data/venue_repository.dart';
import '../../bookings/data/booking_repository.dart';
import '../../bookings/domain/booking.dart';
import '../../../core/config.dart';
import 'widgets/booking_detail_sheet.dart';

class ManagerPaymentsScreen extends ConsumerStatefulWidget {
  const ManagerPaymentsScreen({super.key});

  @override
  ConsumerState<ManagerPaymentsScreen> createState() =>
      _ManagerPaymentsScreenState();
}

class _ManagerPaymentsScreenState
    extends ConsumerState<ManagerPaymentsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.uid;

    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }

    final venuesAsync = ref.watch(venuesProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final statsAsync = ref.watch(managerStatsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Financials & due collections',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(managerStatsProvider(userId));
              ref.invalidate(managerPaymentsProvider(userId));
              final vAsync = ref.read(venuesProvider);
              vAsync.whenData((venues) {
                final ids = venues
                    .where((v) => v.managedBy == userId)
                    .map((v) => v.id)
                    .join(',');
                if (ids.isNotEmpty) {
                  ref.invalidate(managerBookingsProvider(ids));
                }
              });
            },
          ),
        ],
      ),
      body: venuesAsync.when(
        data: (allVenues) {
          final myVenueIds = allVenues
              .where((v) => v.managedBy == userId)
              .map((v) => v.id)
              .toList();

          if (myVenueIds.isEmpty) {
            return const Center(child: Text('No venues found'));
          }

          final bookingsAsync =
              ref.watch(managerBookingsProvider(myVenueIds.join(',')));

          return bookingsAsync.when(
            data: (bookings) {
              // Confirmed bookings with outstanding dues
              final dueBookings = bookings.where((b) {
                if (!_isConfirmed(b.status)) return false;
                if (b.paymentStatus == 'full') return false;
                final isPhys =
                    b.bookingType == 'physical' || b.bookingType == 'manual';
                final due = isPhys
                    ? b.amount
                    : b.amount - (b.esewaAmount ?? 0);
                return due > 0;
              }).toList();

              // Group by venueName
              final grouped = <String, List<Booking>>{};
              for (final b in dueBookings) {
                // Get the actual venue name from the venues list if venueName is an ID
                final venueName = allVenues
                        .where((v) => v.id == b.venueId)
                        .firstOrNull
                        ?.name ??
                    b.venueName;
                grouped.putIfAbsent(venueName, () => []).add(b);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(statsAsync),
                    const SizedBox(height: 20),

                    // ── Transactions button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/manager/transactions'),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('View All Transactions'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Due Payments header ───────────────────────────────
                    Row(
                      children: [
                        const Text('Due Payments',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: dueBookings.isEmpty
                                ? Colors.grey.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${dueBookings.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: dueBookings.isEmpty
                                  ? Colors.grey
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confirmed bookings with cash yet to be collected',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),

                    if (dueBookings.isEmpty)
                      _buildEmptyDue()
                    else ...[
                      for (final entry in grouped.entries) ...[
                        _VenueGroupHeader(
                          venueName: entry.key,
                          count: entry.value.length,
                        ),
                        const SizedBox(height: 8),
                        for (final booking in entry.value)
                          _DuePaymentCard(
                            booking: booking,
                            users: usersAsync.value ?? [],
                            onTap: () => _openDetail(context, booking),
                            onMarkPaid: () =>
                                _markPaid(context, booking, userId),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  bool _isConfirmed(String s) =>
      s.toLowerCase() == 'confirmed' || s.toLowerCase() == 'booked';

  Widget _buildEmptyDue() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              size: 48, color: Colors.green.shade300),
          const SizedBox(height: 12),
          const Text('All dues cleared!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('No confirmed bookings with outstanding dues.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, __) => BookingDetailSheet(booking: booking),
      ),
    );
  }

  Future<void> _markPaid(
      BuildContext context, Booking booking, String userId) async {
    final isPhys =
        booking.bookingType == 'physical' || booking.bookingType == 'manual';
    final due =
        isPhys ? booking.amount : booking.amount - (booking.esewaAmount ?? 0);

    final method = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final users = ref.read(allUsersProvider).value ?? [];
        final actualCustomerName = users
                .where((u) => u.uid == booking.userId)
                .firstOrNull
                ?.displayName ??
            booking.userName ??
            "customer";
        
        return AlertDialog(
          title: const Text('Mark as Paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rs. ${due.toStringAsFixed(0)} due from $actualCustomerName',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('How was it paid?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PayMethodBtn(
                      label: 'Cash',
                      icon: Icons.payments_outlined,
                      onTap: () => Navigator.pop(ctx, 'cash'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PayMethodBtn(
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
        );
      },
    );
    if (method == null || !context.mounted) return;

    try {
      final token =
          await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken();
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
        // follow 307/308 manually: re-POST to Location
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

      if (!context.mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Marked as paid ✅'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        final vAsync = ref.read(venuesProvider);
        vAsync.whenData((venues) {
          final ids = venues
              .where((v) => v.managedBy == userId)
              .map((v) => v.id)
              .join(',');
          if (ids.isNotEmpty) ref.invalidate(managerBookingsProvider(ids));
        });
        ref.invalidate(managerPaymentsProvider(userId));
        ref.invalidate(managerStatsProvider(userId));
      } else {
        String errMsg = 'Failed (${resp.statusCode})';
        try {
          final ct = resp.headers['content-type'] ?? '';
          if (ct.contains('application/json')) {
            final b = jsonDecode(resp.body);
            errMsg = b['error'] ?? errMsg;
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildStatsGrid(AsyncValue statsAsync) {
    return statsAsync.when(
      data: (s) {
        return LayoutBuilder(builder: (context, constraints) {
          final hw = (constraints.maxWidth - 16) / 2;
          final fw = constraints.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _statCard('Held by Admin',
                  'Rs. ${s.heldByAdmin.toStringAsFixed(0)}',
                  'Online income pending payout', Icons.account_balance,
                  width: hw),
              _statCard('Total To Be Paid',
                  'Rs. ${s.totalToBePaid.toStringAsFixed(0)}',
                  'Pending clearance + safe', Icons.attach_money,
                  width: hw),
              _statCard('Safe To Pay Now',
                  'Rs. ${s.actualPaymentToBePaid.toStringAsFixed(0)}',
                  'Past cancellation window', Icons.check_circle_outline,
                  width: hw),
              _statCard('Held by Me',
                  'Rs. ${s.heldByManager.toStringAsFixed(0)}',
                  'Physical + paid out', Icons.storefront,
                  width: hw),
              _statCard('Total Income',
                  'Rs. ${s.totalIncome.toStringAsFixed(0)}',
                  'Online + Physical (all confirmed)',
                  Icons.monetization_on_outlined,
                  width: fw),
              _statCard('Commission',
                  'Rs. ${s.commissionAmount.toStringAsFixed(0)}',
                  '${s.commissionPercentage.toStringAsFixed(1)}% of online income',
                  Icons.percent,
                  color: Colors.orange.shade50,
                  iconColor: Colors.orange,
                  width: hw),
              _statCard('Net Income',
                  'Rs. ${s.netIncome.toStringAsFixed(0)}',
                  'Online income - commission', Icons.trending_up,
                  color: Colors.green.shade50,
                  iconColor: Colors.green,
                  width: hw),
            ],
          );
        });
      },
      loading: () => const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12)),
        child: Text('Could not load stats: $e',
            style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _statCard(String title, String value, String subtitle, IconData icon,
      {double? width, Color? color, Color? iconColor}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(icon, size: 18, color: iconColor ?? Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

// ── Venue group header ────────────────────────────────────────────────────────

class _VenueGroupHeader extends StatelessWidget {
  final String venueName;
  final int count;
  const _VenueGroupHeader({required this.venueName, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.location_on_outlined,
              size: 14, color: Colors.orange.shade700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(venueName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count due',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800)),
        ),
      ],
    );
  }
}

// ── Due payment card ──────────────────────────────────────────────────────────

class _DuePaymentCard extends StatelessWidget {
  final Booking booking;
  final List<AuthUser> users;
  final VoidCallback onTap;
  final VoidCallback onMarkPaid;
  const _DuePaymentCard(
      {required this.booking, required this.users, required this.onTap, required this.onMarkPaid});

  @override
  Widget build(BuildContext context) {
    final isPhys =
        booking.bookingType == 'physical' || booking.bookingType == 'manual';
    final due =
        isPhys ? booking.amount : booking.amount - (booking.esewaAmount ?? 0);
    
    final customerName = users
            .where((u) => u.uid == booking.userId)
            .firstOrNull
            ?.displayName ??
        booking.userName ??
        'Customer';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: Colors.orange),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: Colors.orange.shade50,
                              child: Text(
                                customerName.isNotEmpty
                                    ? customerName[0].toUpperCase()
                                    : 'C',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(customerName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 11, color: Colors.grey.shade400),
                                const SizedBox(width: 3),
                                Text(booking.date,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text('${booking.startTime} – ${booking.endTime}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPhys
                                    ? Colors.teal.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isPhys ? 'Physical' : 'Online',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isPhys
                                        ? Colors.teal
                                        : Colors.blue),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Due Rs. ${due.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700),
                            ),
                          ],
                        ),
                        if (!isPhys && (booking.esewaAmount ?? 0) > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Advance paid: Rs. ${(booking.esewaAmount ?? 0).toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.green),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: onMarkPaid,
                            icon: const Icon(Icons.payments_outlined, size: 15),
                            label: const Text('Mark as Paid'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              backgroundColor: Colors.green.shade50,
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 7),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pay method button ────────────────────────────────────────────────────────

class _PayMethodBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PayMethodBtn(
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
            Icon(icon, color: Colors.green.shade700, size: 22),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
