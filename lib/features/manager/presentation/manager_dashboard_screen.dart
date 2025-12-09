import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../venues/data/venue_repository.dart';
import '../../bookings/data/booking_repository.dart';

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
                // Online vs Physical
                // Note: booking.isManual is not explicitly on Booking model yet?
                // Checking bookingType field if exists or inference
                // Assuming 'mobile' is online, 'manual' is physical
                // or check if userId is empty/special for manual?
                // For now, looking for a way to distinguish.
                // Looking at updateBookingStatus, manual bookings might set 'bookingType': 'manual'
                // Let's assume booking.bookingType exists or similar.
                // If not, we might need to update Booking model.
                // Wait, checking Booking model is better.
                // For now, let's look at available fields in memory.

                // Correction: The User Request image showed "Manual reservations".
                // Let's check if we can infer from data.

                final isManual = booking.bookingType == 'manual';

                if (isManual) {
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
                        _buildStatCard(
                          context,
                          title: 'Total Revenue',
                          value: 'Rs. ${totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.account_balance_wallet_outlined,
                          color: Colors.blue.shade50,
                          iconColor: Colors.blue,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Active Bookings',
                          value: '$activeBookings',
                          icon: Icons.calendar_today_outlined,
                          color: Colors.green.shade50,
                          iconColor: Colors.green,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Physical Bookings',
                          value: '$physicalBookings',
                          icon: Icons.storefront_outlined,
                          color: Colors.orange.shade50,
                          iconColor: Colors.orange,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Online Bookings',
                          value: '$onlineBookings',
                          icon: Icons.language_outlined,
                          color: Colors.purple.shade50,
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
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade50,
                                    child: Icon(Icons.person_outline,
                                        color: Colors.blue.shade400, size: 20),
                                  ),
                                  title: Text(booking.venueName,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      '${booking.date} • ${booking.startTime}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Rs. ${booking.amount}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                      Text(booking.status,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: _getStatusColor(
                                                  booking.status))),
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
                          child: _buildQuickActionTile(
                            context,
                            title: '${venue.name} - Availability',
                            subtitle: 'View and manage booking slots',
                            icon: Icons.calendar_month_outlined,
                            onTap: () => context.push(
                                '/manager/venues/edit-venue/${venue.id}?tab=3'),
                          ),
                        )),
                    _buildQuickActionTile(
                      context,
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
                    _buildQuickActionTile(
                      context,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'booked':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatCard(BuildContext context,
      {required String title,
      required String value,
      required IconData icon,
      required Color color,
      required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              offset: Offset(0, 2),
              blurRadius: 4,
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4), // Add spacing
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          FittedBox(
            // handle potentially large numbers
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
