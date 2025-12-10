import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bookings/data/booking_repository.dart';
import 'widgets/booking_detail_sheet.dart';
import 'widgets/booking_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../venues/data/venue_repository.dart';
import '../../../core/theme.dart';

class ManagerBookingsScreen extends ConsumerStatefulWidget {
  const ManagerBookingsScreen({super.key});

  @override
  ConsumerState<ManagerBookingsScreen> createState() =>
      _ManagerBookingsScreenState();
}

class _ManagerBookingsScreenState extends ConsumerState<ManagerBookingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      backgroundColor: Colors.white,
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
          final myVenues =
              allVenues.where((v) => v.managedBy == userId).toList();
          final myVenueIds = myVenues.map((v) => v.id).toList();

          if (myVenueIds.isEmpty) {
            return const Center(
                child: Text('No venues found. Create a venue first.'));
          }

          final bookingsAsync =
              ref.watch(managerBookingsProvider(myVenueIds.join(',')));

          return bookingsAsync.when(
            data: (bookings) {
              final filteredBookings = bookings.where((booking) {
                if (_searchQuery.isEmpty) return true;
                final query = _searchQuery.toLowerCase();
                return booking.venueName.toLowerCase().contains(query) ||
                    booking.date.contains(query) ||
                    booking.status.toLowerCase().contains(query);
              }).toList();

              return Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search bookings...',
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
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: filteredBookings.isEmpty
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
                                      color: Colors.grey.shade500,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filteredBookings.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20)),
                                      ),
                                      builder: (context) =>
                                          DraggableScrollableSheet(
                                        initialChildSize: 0.7,
                                        minChildSize: 0.5,
                                        maxChildSize: 0.95,
                                        expand: false,
                                        builder: (context, _) =>
                                            BookingDetailSheet(
                                                booking:
                                                    filteredBookings[index]),
                                      ),
                                    );
                                  },
                                  child: BookingCard(
                                      booking: filteredBookings[index]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
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
