import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../venues/data/venue_repository.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/venue_list_card.dart';

class ManagerHomeScreen extends ConsumerWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(venuesProvider);
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.uid;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Venues',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: OutlinedButton.icon(
              onPressed: () {
                context.push('/manager/venues/create-venue');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Venue'),
            ),
          ),
        ],
      ),
      body: venuesAsync.when(
        data: (venues) {
          // Filter venues managed by current user
          final myVenues = venues.where((v) => v.managedBy == userId).toList();

          if (myVenues.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_outlined,
                          size: 48, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No venues yet',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get started by creating your first venue',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push('/manager/venues/create-venue');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create New Venue'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myVenues.length,
            itemBuilder: (context, index) {
              final venue = myVenues[index];
              return VenueListCard(
                venue: venue,
                buttonLabel: 'Edit Venue',
                buttonIcon: Icons.edit_outlined,
                onTap: () {
                  context.push('/manager/venues/edit-venue/${venue.id}');
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
