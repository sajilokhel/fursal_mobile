import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../bookings/data/booking_repository.dart';
import '../../bookings/domain/booking.dart';
import 'widgets/booking_detail_sheet.dart';
import 'widgets/booking_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../venues/data/venue_repository.dart';
import '../../../core/theme.dart';
import '../../../core/config.dart';

// ── Status grouping helpers ──────────────────────────────────────────────────

bool _isConfirmed(String s) =>
    s.toLowerCase() == 'confirmed' || s.toLowerCase() == 'booked';
bool _isPending(String s) => s.toLowerCase() == 'pending';

List<Booking> _group(List<Booking> all, bool Function(String) test) =>
    all.where((b) => test(b.status)).toList();

/// Parses a booking date string (YYYY-MM-DD) into DateTime.
DateTime _parseDate(String date) {
  try {
    return DateTime.parse(date);
  } catch (_) {
    return DateTime(2000);
  }
}

/// Sort confirmed bookings: upcoming (nearest first) then past (most recent first).
List<Booking> _sortConfirmedByProximity(List<Booking> list) {
  final today = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final upcoming = list
      .where((b) => !_parseDate(b.date).isBefore(today))
      .toList()
    ..sort((a, b) => _parseDate(a.date).compareTo(_parseDate(b.date)));
  final past = list
      .where((b) => _parseDate(b.date).isBefore(today))
      .toList()
    ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));
  return [...upcoming, ...past];
}

// ── Main screen ─────────────────────────────────────────────────────────────

class ManagerBookingsScreen extends ConsumerStatefulWidget {
  const ManagerBookingsScreen({super.key});

  @override
  ConsumerState<ManagerBookingsScreen> createState() =>
      _ManagerBookingsScreenState();
}

class _ManagerBookingsScreenState
    extends ConsumerState<ManagerBookingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        builder: (_, _sc) => BookingDetailSheet(booking: booking),
      ),
    );
  }

  /// Shows a payment method picker then calls the mark-paid API.
  Future<void> _markPaid(BuildContext context, Booking booking) async {
    // 1 — pick payment method
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rs. ${(booking.bookingType == "physical" || booking.bookingType == "manual" ? booking.amount : booking.amount - (booking.esewaAmount ?? 0)).toStringAsFixed(0)} due from ${booking.userName ?? "customer"}',
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
    if (method == null || !context.mounted) return;

    // 2 — call API
    try {
      final token =
          await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      // Use http.Request with followRedirects=false so we receive the 308
      // response and can manually re-POST instead of having the client
      // silently convert it to a GET.
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
        ref.invalidate(managerBookingsProvider);
      } else {
        // Safely try to extract an error message from JSON; fall back to
        // the raw status code if the body is HTML or not valid JSON.
        String errMsg = 'Failed (${resp.statusCode})';
        try {
          final ct = resp.headers['content-type'] ?? '';
          if (ct.contains('application/json')) {
            final body = jsonDecode(resp.body);
            errMsg = body['error'] ?? errMsg;
          } else {
            // HTML redirect or unexpected response — show status code only.
            errMsg = 'Server error ${resp.statusCode}. Check API url config.';
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.uid;

    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }

    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Manage Bookings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: venuesAsync.when(
        data: (allVenues) {
          final myVenueIds = allVenues
              .where((v) => v.managedBy == userId)
              .map((v) => v.id)
              .toList();

          if (myVenueIds.isEmpty) {
            return const Center(
                child: Text('No venues found. Create a venue first.'));
          }

          final bookingsAsync =
              ref.watch(managerBookingsProvider(myVenueIds.join(',')));

          return bookingsAsync.when(
            data: (bookings) {
              final filtered = bookings.where((b) {
                if (_searchQuery.isEmpty) return true;
                final q = _searchQuery.toLowerCase();
                return b.venueName.toLowerCase().contains(q) ||
                    b.date.contains(q) ||
                    b.status.toLowerCase().contains(q) ||
                    (b.userName?.toLowerCase().contains(q) ?? false);
              }).toList();

              final confirmed =
                  _sortConfirmedByProximity(_group(filtered, _isConfirmed));
              final pending = _group(filtered, _isPending);
              final others = filtered
                  .where((b) => !_isConfirmed(b.status) && !_isPending(b.status))
                  .toList();

              return Column(
                children: [
                  // ── Search bar ────────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by customer, venue, date…',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 1),
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),

                  // ── Summary chips ─────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: Row(
                      children: [
                        _SummaryChip(
                          label: 'Confirmed',
                          count: confirmed.length,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          label: 'Pending',
                          count: pending.length,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          label: 'Other',
                          count: others.length,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

                  // ── Grouped list ──────────────────────────────────────────
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 60, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No bookings found'
                                      : 'No matching bookings',
                                  style: TextStyle(
                                      color: Colors.grey.shade500, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              if (confirmed.isNotEmpty) ...[
                                _SectionHeader(
                                  label: 'Confirmed',
                                  count: confirmed.length,
                                  color: Colors.green,
                                  icon: Icons.check_circle_outline,
                                ),
                                const SizedBox(height: 10),
                                ..._cards(context, confirmed, markPaid: true),
                                const SizedBox(height: 16),
                              ],
                              if (pending.isNotEmpty) ...[
                                _SectionHeader(
                                  label: 'Pending',
                                  count: pending.length,
                                  color: Colors.orange,
                                  icon: Icons.hourglass_top_rounded,
                                ),
                                const SizedBox(height: 10),
                                ..._cards(context, pending),
                                const SizedBox(height: 16),
                              ],
                              if (others.isNotEmpty) ...[
                                _SectionHeader(
                                  label: 'Cancelled / Other',
                                  count: others.length,
                                  color: Colors.redAccent,
                                  icon: Icons.cancel_outlined,
                                ),
                                const SizedBox(height: 10),
                                ..._cards(context, others),
                              ],
                            ],
                          ),
                  ),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  List<Widget> _cards(BuildContext ctx, List<Booking> list,
      {bool markPaid = false}) {
    return [
      for (final b in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BookingCard(
            booking: b,
            onTap: () => _openDetail(ctx, b),
            onMarkPaid: markPaid ? () => _markPaid(ctx, b) : null,
          ),
        ),
    ];
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SectionHeader(
      {required this.label,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
        const SizedBox(width: 8),
        // count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const Expanded(child: Divider(indent: 12)),
      ],
    );
  }
}

// ── Summary chip ─────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: $count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Pay method button ─────────────────────────────────────────────────────────

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
