import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../venues/data/venue_repository.dart';
import '../../bookings/data/booking_repository.dart';
import 'widgets/stat_card.dart';
import 'widgets/quick_action_tile.dart';
import 'widgets/status_helpers.dart';

class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.uid;

    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }

    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      body: venuesAsync.when(
        data: (bookings) {
          final myVenues =
              bookings.where((v) => v.managedBy == userId).toList();
          final myVenueIds = myVenues.map((v) => v.id).toList();

          if (myVenueIds.isEmpty) {
            return const Center(child: Text('No venues found'));
          }

          final bookingsAsync =
              ref.watch(managerBookingsProvider(myVenueIds.join(',')));

          return bookingsAsync.when(
            data: (bookings) {
              // Calculate stats
              double totalRevenue = 0;
              int activeBookings = 0;
              int physicalBookings = 0;
              int onlineBookings = 0;

              for (var booking in bookings) {
                // Physical vs Online
                final isPhysical = booking.bookingType == 'manual' ||
                    booking.bookingType == 'physical';

                if (isPhysical) {
                  physicalBookings++;
                } else {
                  onlineBookings++;
                }

                // Active Bookings
                if (['booked', 'confirmed', 'pending']
                    .contains(booking.status.toLowerCase())) {
                  activeBookings++;
                }

                // Revenue (only confirmed/paid)
                if (['confirmed', 'booked']
                    .contains(booking.status.toLowerCase())) {
                  totalRevenue += booking.amount;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Statistics Cards
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(
                          title: 'Total Revenue',
                          value: 'Rs. ${totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.account_balance_wallet_outlined,
                          backgroundColor: Colors.blue.shade50,
                          iconColor: Colors.blue,
                        ),
                        StatCard(
                          title: 'Active Bookings',
                          value: '$activeBookings',
                          icon: Icons.calendar_today_outlined,
                          backgroundColor: Colors.green.shade50,
                          iconColor: Colors.green,
                        ),
                        StatCard(
                          title: 'Physical Bookings',
                          value: '$physicalBookings',
                          icon: Icons.storefront_outlined,
                          backgroundColor: Colors.orange.shade50,
                          iconColor: Colors.orange,
                        ),
                        StatCard(
                          title: 'Online Bookings',
                          value: '$onlineBookings',
                          icon: Icons.language_outlined,
                          backgroundColor: Colors.purple.shade50,
                          iconColor: Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Recent Bookings Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Bookings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    bookings.isEmpty
                        ? Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Center(
                              child: Text(
                                'No bookings found.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: bookings.take(5).length,
                            itemBuilder: (context, index) {
                              final booking = bookings[index];
                              final isPhysical =
                                  booking.bookingType == 'physical' ||
                                      booking.bookingType == 'manual';
                              final customerName =
                                  booking.userName ?? 'Customer';

                              // Calculate amount to pay
                              final amountPaid = booking.esewaAmount ?? 0;
                              final amountToPay = isPhysical
                                  ? booking.amount
                                  : (booking.amount - amountPaid);

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top row: Venue + Status
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              booking.venueName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  getStatusColor(booking.status)
                                                      .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              booking.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: getStatusColor(
                                                    booking.status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Customer + Booking type
                                      Row(
                                        children: [
                                          Icon(
                                            isPhysical
                                                ? Icons.person
                                                : Icons.phone_android,
                                            size: 16,
                                            color: isPhysical
                                                ? Colors.green
                                                : Colors.amber,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            customerName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isPhysical
                                                  ? Colors.green.shade50
                                                  : Colors.amber.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isPhysical
                                                  ? 'Physical'
                                                  : 'Online',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isPhysical
                                                    ? Colors.green
                                                    : Colors.amber.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Date/Time + Amount
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${booking.date} • ${booking.startTime}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                amountToPay > 0
                                                    ? 'Due: Rs. ${amountToPay.toStringAsFixed(0)}'
                                                    : 'Paid',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: amountToPay > 0
                                                      ? Colors.orange
                                                      : Colors.green,
                                                ),
                                              ),
                                              if (!isPhysical && amountPaid > 0)
                                                Text(
                                                  'Paid: Rs. ${amountPaid.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Venue Availability links for each venue
                    ...myVenues.map((venue) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: QuickActionTile(
                            title: '${venue.name} - Availability',
                            subtitle: 'View and manage booking slots',
                            icon: Icons.calendar_month_outlined,
                            onTap: () => context.push(
                                '/manager/venues/edit-venue/${venue.id}?tab=3'),
                          ),
                        )),
                    QuickActionTile(
                      title: 'Venue Settings',
                      subtitle: 'Update price, description, and amenities',
                      icon: Icons.settings_outlined,
                      onTap: () {
                        if (myVenues.isNotEmpty) {
                          context.push(
                              '/manager/venues/edit-venue/${myVenues.first.id}');
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    QuickActionTile(
                      title: 'All Bookings',
                      subtitle: 'View and manage all booking history',
                      icon: Icons.history_outlined,
                      onTap: () {},
                    ),
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
}
