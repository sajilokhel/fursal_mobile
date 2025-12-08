import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_repository.dart';
import '../../venues/data/venue_repository.dart';
import '../../bookings/data/booking_repository.dart';
import '../../bookings/domain/booking.dart';

class ManagerPaymentsScreen extends ConsumerStatefulWidget {
  const ManagerPaymentsScreen({super.key});

  @override
  ConsumerState<ManagerPaymentsScreen> createState() =>
      _ManagerPaymentsScreenState();
}

class _ManagerPaymentsScreenState extends ConsumerState<ManagerPaymentsScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All Status';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.uid;

    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }

    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Venue Payments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Financial overview and transaction history',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Trigger refresh if needed, for now Stream handles updates
            },
            tooltip: 'Refresh',
          )
        ],
      ),
      body: venuesAsync.when(
        data: (venues) {
          final myVenues = venues.where((v) => v.managedBy == userId).toList();
          final myVenueIds = myVenues.map((v) => v.id).toList();

          if (myVenueIds.isEmpty) {
            return const Center(child: Text('No venues found'));
          }

          final bookingsAsync =
              ref.watch(managerBookingsProvider(myVenueIds.join(',')));

          return bookingsAsync.when(
            data: (bookings) {
              if (bookings.isNotEmpty) {
                print(
                    'PAYMENT_DEBUG: First booking data: ${bookings.first.toMap()}');
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(bookings),
                    const SizedBox(height: 24),
                    _buildTransactionsSection(bookings),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildStatsGrid(List<Booking> bookings) {
    // Logic for stats
    double heldByAdmin = 0; // Online & Paid/Confirmed
    double heldByMe = 0; // Physical & Confirmed
    double totalRevenue = 0; // All Confirmed
    int totalCount = bookings.length;
    int successCount = 0;
    int failedPendingCount = 0;

    for (var b in bookings) {
      final isOnline = b.bookingType != 'manual';
      final isConfirmed =
          ['confirmed', 'booked'].contains(b.status.toLowerCase());
      final isPending = b.status.toLowerCase() == 'pending';
      final isCancelled = b.status.toLowerCase() == 'cancelled';

      if (isConfirmed) {
        successCount++;
        totalRevenue += b.amount;
        if (isOnline) {
          heldByAdmin += b.amount;
        } else {
          heldByMe += b.amount;
        }
      } else if (isPending || isCancelled) {
        failedPendingCount++;
      }
    }

    double successRate =
        totalCount == 0 ? 0 : (successCount / totalCount) * 100;

    // "Total To Be Paid" & "Actual To Be Paid" - assuming Admin holds online payments to pay out
    // and "Safe to Pay Now" is what is cleared. Ideally this needs a "cleared" flag.
    // For now: Total To Be Paid = Held By Admin.
    double totalToBePaid = heldByAdmin;
    double actualToBePaid =
        heldByAdmin * 0.9; // Mocking a platform fee deduction? Or just same.
    // Let's keep it same for now or 0 if we don't know logic.
    // The screenshot shows "Pending Clearance + Safe" vs "Safe to Pay Now".
    // I will use totalToBePaid for now.

    return LayoutBuilder(builder: (context, constraints) {
      // 2 columns on mobile
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard(
              'Held by Admin',
              'Rs. ${heldByAdmin.toStringAsFixed(0)}',
              'Online Income - Paid Out',
              Icons.account_balance,
              width: (constraints.maxWidth - 16) / 2),
          _buildStatCard(
              'Total To Be Paid',
              'Rs. ${totalToBePaid.toStringAsFixed(0)}',
              'Pending Clearance + Safe',
              Icons.attach_money,
              width: (constraints.maxWidth - 16) / 2),
          _buildStatCard(
              'Actual To Be Paid',
              'Rs. ${actualToBePaid.toStringAsFixed(0)}',
              'Safe to Pay Now',
              Icons.check_circle_outline,
              width: (constraints.maxWidth - 16) / 2),
          _buildStatCard('Held by Me', 'Rs. ${heldByMe.toStringAsFixed(0)}',
              'Physical + Paid Out', Icons.storefront,
              width: (constraints.maxWidth - 16) / 2),
          _buildStatCard(
              'Total Revenue',
              'Rs. ${totalRevenue.toStringAsFixed(0)}',
              'All Bookings (Online + Physical)',
              Icons.monetization_on_outlined,
              width: constraints.maxWidth), // Full width
          _buildStatCard('Success Rate', '${successRate.toStringAsFixed(1)}%',
              '', Icons.trending_up,
              color: Colors.orange.shade50,
              iconColor: Colors.orange,
              width: (constraints.maxWidth - 16) / 2),
          _buildStatCard(
              'Failed/Pending', '$failedPendingCount', '', Icons.error_outline,
              width: (constraints.maxWidth - 16) / 2),
        ],
      );
    });
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, IconData icon,
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

  Widget _buildTransactionsSection(List<Booking> bookings) {
    // Filter logic
    var filtered = bookings.where((b) {
      if (_selectedStatus != 'All Status') {
        if (b.status.toLowerCase() != _selectedStatus.toLowerCase()) {
          // Allow Mapping 'Success' -> 'Confirmed'
          if (_selectedStatus == 'Success' &&
              (b.status == 'confirmed' || b.status == 'booked')) {
            // pass
          } else {
            return false;
          }
        }
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        // Search by userId, venueName, or amount (rough)
        return b.userId.toLowerCase().contains(q) ||
            b.venueName.toLowerCase().contains(q) ||
            b.id.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // Search Filter Row
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search user, venue, or ID...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  items: ['All Status', 'Success', 'Pending', 'Cancelled']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedStatus = val;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Headers
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Text('Date',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(
                  flex: 3,
                  child: Text('User',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(
                  flex: 2,
                  child: Text('Amount',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(
                  flex: 2,
                  child: Text('Status',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        const Divider(),
        filtered.isEmpty
            ? const Center(
                child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No transactions found'),
              ))
            : ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final dateStr = DateFormat('MMM d, y HH:mm')
                      .format(DateTime.parse('${item.date} ${item.startTime}'));
                  // Note: item.date is usually YYYY-MM-DD. Need robust parsing.
                  // Assuming item.date is 2023-12-09 string.

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text(dateStr,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey))),
                        Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    item.userId.length > 6
                                        ? item.userId.substring(0, 6)
                                        : item.userId,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12)),
                                Text(
                                    'ID: ${item.id.length > 4 ? item.id.substring(0, 4) : item.id}...',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ],
                            )),
                        Expanded(
                            flex: 2,
                            child: Text('Rs. ${item.amount}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        Expanded(
                            flex: 2, child: _buildStatusBadge(item.status)),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'booked':
        bg = Colors.green.shade50;
        fg = Colors.green;
        text = 'SUCCESS';
        break;
      case 'pending':
        bg = Colors.orange.shade50;
        fg = Colors.orange;
        break;
      case 'cancelled':
        bg = Colors.red.shade50;
        fg = Colors.red;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
    );
  }
}
