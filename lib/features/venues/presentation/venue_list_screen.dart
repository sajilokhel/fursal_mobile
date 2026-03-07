import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/venue_repository.dart';
import '../domain/venue.dart';
import 'widgets/venue_card.dart';
import 'widgets/venue_map_view.dart';
import '../../home/presentation/home_sport_chip.dart';
import '../../../../core/theme.dart';

class VenueListScreen extends ConsumerStatefulWidget {
  const VenueListScreen({super.key});

  @override
  ConsumerState<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends ConsumerState<VenueListScreen> {
  bool _isMapView = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedSportIndex = 0; // 0 = All

  // Filter & Sort State
  RangeValues _priceRange = const RangeValues(0, 5000);
  final double _maxPrice = 5000;
  final double _minPrice = 0;
  final Set<String> _selectedAmenities = {};
  String _sortOption =
      'rating'; // 'rating', 'nearest', 'price_low', 'price_high'

  // Available amenities for filtering
  final List<String> _availableAmenities = [
    'Parking',
    'Changing Room',
    'Shower',
    'Canteen',
    'Floodlights',
    'Lockers'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // List/Map Toggle
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    _buildToggleButton(
                      title: 'List',
                      icon: Icons.list,
                      isSelected: !_isMapView,
                      onTap: () => setState(() => _isMapView = false),
                      isLeft: true,
                    ),
                    _buildToggleButton(
                      title: 'Map',
                      icon: Icons.map_outlined,
                      isSelected: _isMapView,
                      onTap: () => setState(() => _isMapView = true),
                      isLeft: false,
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar & Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search venues or sports...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showFilterBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(Icons.tune, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Browse by Sports row
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kSportItems.length,
                itemBuilder: (context, index) {
                  final sport = kSportItems[index];
                  final isSelected = _selectedSportIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSportIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(sport.emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            sport.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: venuesAsync.when(
                data: (venues) {
                  // Filter by sport
                  var filteredBySport = _selectedSportIndex == 0
                      ? venues
                      : venues.where((v) {
                          final sportName = kSportItems[_selectedSportIndex]
                              .name
                              .toLowerCase();
                          return v.attributes.keys
                              .any((k) => k.toLowerCase().contains(sportName));
                        }).toList();

                  // 1. Filter by search, price, amenities
                  var filteredVenues = filteredBySport.where((venue) {
                    if (_searchQuery.isNotEmpty &&
                        !venue.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase())) {
                      return false;
                    }
                    if (venue.pricePerHour < _priceRange.start ||
                        venue.pricePerHour > _priceRange.end) {
                      return false;
                    }
                    if (_selectedAmenities.isNotEmpty) {
                      for (var amenity in _selectedAmenities) {
                        bool hasAmenity = venue.attributes.keys.any((key) =>
                            key.toLowerCase().contains(amenity.toLowerCase()));
                        if (!hasAmenity) return false;
                      }
                    }
                    return true;
                  }).toList();

                  // 2. Sort
                  filteredVenues.sort((a, b) {
                    switch (_sortOption) {
                      case 'price_low':
                        return a.pricePerHour.compareTo(b.pricePerHour);
                      case 'price_high':
                        return b.pricePerHour.compareTo(a.pricePerHour);
                      case 'rating':
                      default:
                        return b.averageRating.compareTo(a.averageRating);
                    }
                  });

                  if (_isMapView) {
                    return VenueMapView(
                      venues: filteredVenues,
                      onVenueSelected: (venue) =>
                          _showVenuePreview(context, venue),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filteredVenues.length} Venues Available',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            _buildSortButton(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: filteredVenues.length,
                          itemBuilder: (context, index) {
                            final venue = filteredVenues[index];
                            return VenueCard(
                              venue: venue,
                              onSeeDetails: () =>
                                  context.go('/home/venue/${venue.id}'),
                              onViewOnMap: () =>
                                  setState(() => _isMapView = true),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.horizontal(
              left: isLeft ? const Radius.circular(11) : Radius.zero,
              right: !isLeft ? const Radius.circular(11) : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    String sortLabel;
    IconData sortIcon;

    switch (_sortOption) {
      case 'price_low':
        sortLabel = 'Price Low → High';
        sortIcon = Icons.currency_rupee;
        break;
      case 'price_high':
        sortLabel = 'Price High → Low';
        sortIcon = Icons.currency_rupee;
        break;
      case 'nearest':
        sortLabel = 'Nearest';
        sortIcon = Icons.location_on;
        break;
      case 'rating':
      default:
        sortLabel = 'Top Rated';
        sortIcon = Icons.star;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: PopupMenuButton<String>(
        onSelected: (String value) {
          setState(() {
            _sortOption = value;
          });
        },
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          _buildPopupItem('Top Rated', Icons.star, 'rating'),
          const PopupMenuDivider(),
          _buildPopupItem('Nearest', Icons.location_on, 'nearest'),
          const PopupMenuDivider(),
          _buildPopupItem(
              'Price Low → High', Icons.currency_rupee, 'price_low'),
          const PopupMenuDivider(),
          _buildPopupItem(
              'Price High → Low', Icons.currency_rupee, 'price_high'),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sort by: ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              Icon(sortIcon, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
              Text(
                sortLabel,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      String label, IconData icon, String value) {
    bool isSelected = _sortOption == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (isSelected)
            const Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _priceRange = RangeValues(_minPrice, _maxPrice);
                            _selectedAmenities.clear();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('Price Range',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rs. ${_priceRange.start.round()}'),
                      Text('Rs. ${_priceRange.end.round()}'),
                    ],
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: _minPrice,
                    max: _maxPrice,
                    divisions: 50,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (values) {
                      setModalState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Amenities',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableAmenities.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVenuePreview(BuildContext context, Venue venue) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: VenueCard(
          venue: venue,
          onSeeDetails: () {
            Navigator.pop(context);
            context.go('/home/venue/${venue.id}');
          },
          onViewOnMap: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
