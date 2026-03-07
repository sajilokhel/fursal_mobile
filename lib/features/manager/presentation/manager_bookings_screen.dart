import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bookings/data/booking_repository.dart';
import '../../bookings/domain/booking.dart';
import 'widgets/booking_detail_sheet.dart';
import 'widgets/booking_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../venues/data/venue_repository.dart';
import '../../../core/theme.dart';

// ── Status grouping helpers ──────────────────────────────────────────────────

bool _isConfirmed(String s) =>
    s.toLowerCase() == 'confirmed' || s.toLowerCase() == 'booked';
bool _isPending(String s) => s.toLowerCase() == 'pending';

List<Booking> _group(List<Booking> all, bool Function(String) test) =>
    all.where((b) => test(b.status)).toList();

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

              final confirmed = _group(filtered, _isConfirmed);
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
                                ..._cards(context, confirmed),
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

  List<Widget> _cards(BuildContext ctx, List<Booking> list) {
    return [
      for (final b in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BookingCard(
            booking: b,
            onTap: () => _openDetail(ctx, b),
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
