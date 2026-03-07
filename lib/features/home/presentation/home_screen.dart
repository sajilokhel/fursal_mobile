import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../venues/data/venue_repository.dart';
import '../../venues/domain/venue.dart';
import '../../../shared/widgets/venue_horizontal_card.dart';
import '../../../core/services/location_service.dart';
import 'home_sport_chip.dart';
import 'promo_banner_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedSportIndex = 0;

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(venuesProvider);
    final locationState = ref.watch(locationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: CustomScrollView(
        slivers: [
          // ── Search Bar ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search venues, sports...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),

          // ── Browse by sports ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 4),
              child: Text(
                'Browse by sports',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 82,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                itemCount: kSportItems.length,
                itemBuilder: (context, index) => HomeSportChip(
                  sport: kSportItems[index],
                  isSelected: _selectedSportIndex == index,
                  onTap: () => setState(() => _selectedSportIndex = index),
                ),
              ),
            ),
          ),

          // ── Promo Banner ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: PromoBannerCard(
                onBookNow: () => context.go('/venues'),
              ),
            ),
          ),

          // ── Location permission banner (if denied) ──────────
          if (locationState.isDenied)
            SliverToBoxAdapter(
              child: _LocationDeniedBanner(
                onRetry: () => ref.read(locationProvider.notifier).retry(),
              ),
            ),

          // ── Venue Sections ──────────────────────────────────
          venuesAsync.when(
            data: (venues) => _buildVenueSections(venues, locationState, theme),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueSections(
    List<Venue> venues,
    LocationState locationState,
    ThemeData theme,
  ) {
    // ── Sport-filtered set (used by "Near You") ──────────────
    final filtered = _selectedSportIndex == 0
        ? venues
        : venues.where((v) {
            final sportName =
                kSportItems[_selectedSportIndex].name.toLowerCase();
            return v.attributes.keys
                .any((k) => k.toLowerCase().contains(sportName));
          }).toList();

    // ── Nearby: top 5 by distance (GPS) or fallback by newest ──
    List<Venue> nearbyVenues;
    bool usingGps = false;
    if (locationState.hasLocation) {
      usingGps = true;
      final pos = locationState.position!;
      final withDist = filtered.map((v) {
        final dist =
            distanceKm(pos.latitude, pos.longitude, v.latitude, v.longitude);
        return _VenueWithDist(v, dist);
      }).toList()
        ..sort((a, b) => a.dist.compareTo(b.dist));
      nearbyVenues = withDist.take(5).map((e) => e.venue).toList();
    } else {
      // Fallback: first 5 in the list (or sorted by rating as a reasonable default)
      nearbyVenues = (List<Venue>.from(filtered)
            ..sort((a, b) => b.averageRating.compareTo(a.averageRating)))
          .take(5)
          .toList();
    }

    // ── Highest rated (all venues, top 10) ──────────────────
    final topRated = (List<Venue>.from(venues)
          ..sort((a, b) => b.averageRating.compareTo(a.averageRating)))
        .take(10)
        .toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        // Venues Near You
        _SectionHeader(
          icon: Icons.location_on,
          title: usingGps ? 'Venues Near You' : 'Top Venues',
          subtitle:
              usingGps ? 'Top 5 closest to you' : 'Enable location for nearby',
        ),
        if (nearbyVenues.isEmpty)
          _EmptySection(
              usingGps ? 'No venues found nearby' : 'No venues available')
        else
          _HorizontalVenueList(
            venues: nearbyVenues,
            onTap: (v) => context.go('/home/venue/${v.id}'),
          ),

        // Highest Rated
        const _SectionHeader(
          icon: Icons.star_rounded,
          title: 'Highest Rated Venues',
          subtitle: 'Best reviewed spots',
        ),
        if (topRated.isEmpty)
          const _EmptySection('No rated venues yet')
        else
          _HorizontalVenueList(
            venues: topRated,
            onTap: (v) => context.go('/home/venue/${v.id}'),
          ),

        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Helper data class ────────────────────────────────────────
class _VenueWithDist {
  final Venue venue;
  final double dist;
  _VenueWithDist(this.venue, this.dist);
}

// ── Sub-widgets ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HorizontalVenueList extends StatelessWidget {
  final List<Venue> venues;
  final void Function(Venue) onTap;

  const _HorizontalVenueList({required this.venues, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 255,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: venues.length,
        itemBuilder: (context, index) => VenueHorizontalCard(
          venue: venues[index],
          onTap: () => onTap(venues[index]),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }
}

class _LocationDeniedBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _LocationDeniedBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_outlined,
              color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Location access denied. Showing top-rated venues instead.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
