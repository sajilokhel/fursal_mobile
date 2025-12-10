import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import '../../../core/theme.dart';
import '../../venues/data/venue_repository.dart';
import '../../venues/domain/venue.dart';
import '../../venues/domain/venue_slot.dart';

class ManagerVenueEditScreen extends ConsumerStatefulWidget {
  final String venueId;
  final int? initialTab;

  const ManagerVenueEditScreen({
    super.key,
    required this.venueId,
    this.initialTab,
  });

  @override
  ConsumerState<ManagerVenueEditScreen> createState() =>
      _ManagerVenueEditScreenState();
}

class _ManagerVenueEditScreenState extends ConsumerState<ManagerVenueEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // State variables for form fields
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _addressController;

  LatLng? _selectedLocation;
  bool _isInitialized = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // Availability tab state - start from today
  late DateTime _selectedWeekStart;

  // Fixed slot width for horizontal scrolling
  static const double _slotWidth = 80.0;
  static const double _timeColumnWidth = 50.0;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab?.clamp(0, 3) ?? 0;
    _tabController =
        TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _addressController = TextEditingController();
    // Start from today (strip time)
    final now = DateTime.now();
    _selectedWeekStart = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venuesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Venue',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Images'),
            Tab(text: 'Location'),
            Tab(text: 'Availability'),
          ],
        ),
      ),
      body: venueAsync.when(
        data: (venues) {
          final venue = venues.firstWhere(
            (v) => v.id == widget.venueId,
            orElse: () => const Venue(
              id: '',
              name: '',
              description: '',
              latitude: 0,
              longitude: 0,
              imageUrls: [],
              attributes: {},
              pricePerHour: 0,
              managedBy: '',
              createdAt: '',
            ),
          );

          if (venue.id.isEmpty) {
            return const Center(child: Text('Venue not found'));
          }

          // Initialize controllers only once
          if (!_isInitialized) {
            _nameController.text = venue.name;
            _descriptionController.text = venue.description ?? '';
            _priceController.text = venue.pricePerHour.toString();
            _addressController.text = venue.address ?? '';

            if (venue.latitude != 0 && venue.longitude != 0) {
              _selectedLocation = LatLng(venue.latitude, venue.longitude);
            }

            _isInitialized = true;
          }

          return TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildOverviewTab(venue),
              _buildImagesTab(venue),
              _buildLocationTab(venue),
              _buildAvailabilityTab(venue),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _saveVenue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Save Changes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Future<void> _saveVenue() async {
    // Only validate form if it exists (user might be on a different tab)
    final formState = _formKey.currentState;
    if (formState != null && !formState.validate()) {
      // Switch to overview tab to show validation errors
      _tabController.animateTo(0);
      return;
    }

    final venuesState = ref.read(venuesProvider);
    if (!venuesState.hasValue) return;

    try {
      final venue =
          venuesState.value!.firstWhere((v) => v.id == widget.venueId);

      final updatedVenue = Venue(
        id: venue.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        pricePerHour: double.parse(_priceController.text.trim()),
        latitude: _selectedLocation?.latitude ?? venue.latitude,
        longitude: _selectedLocation?.longitude ?? venue.longitude,
        address: _addressController.text.trim(),
        imageUrls: venue.imageUrls,
        attributes: venue.attributes,
        managedBy: venue.managedBy,
        createdAt: venue.createdAt,
        averageRating: venue.averageRating,
        reviewCount: venue.reviewCount,
      );

      await ref.read(venueRepositoryProvider).updateVenue(updatedVenue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venue updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating venue: $e')),
        );
      }
    }
  }

  Widget _buildOverviewTab(Venue venue) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Venue Name',
              hint: 'e.g., Downtown Futsal',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe your venue...',
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _priceController,
              label: 'Price per Hour',
              hint: '0.00',
              prefixText: '\$',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // TODO: Add Attribute management here
          ],
        ),
      ),
    );
  }

  Widget _buildImagesTab(Venue venue) {
    if (venue.imageUrls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No images added yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _pickAndUploadImage(venue),
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Images'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: Colors.black87),
              ),
            ),
            if (_isUploading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Venue Images (${venue.imageUrls.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: () => _pickAndUploadImage(venue),
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: Colors.black87),
              ),
            ],
          ),
        ),
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: venue.imageUrls.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      venue.imageUrls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _deleteImage(venue, venue.imageUrls[index]),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadImage(Venue venue) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final file = File(image.path);
      final downloadUrl = await ref
          .read(venueRepositoryProvider)
          .uploadVenueImage(file, venue.id);

      // Create updated venue with new image URL
      final updatedVenue = Venue(
        id: venue.id,
        name: venue.name,
        description: venue.description,
        latitude: venue.latitude,
        longitude: venue.longitude,
        address: venue.address,
        imageUrls: [...venue.imageUrls, downloadUrl],
        pricePerHour: venue.pricePerHour,
        attributes: venue.attributes,
        managedBy: venue.managedBy,
        createdAt: venue.createdAt,
        averageRating: venue.averageRating,
        reviewCount: venue.reviewCount,
      );

      // Update in Firestore
      await ref.read(venueRepositoryProvider).updateVenue(updatedVenue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteImage(Venue venue, String imageUrl) async {
    try {
      final updatedImages = List<String>.from(venue.imageUrls);
      updatedImages.remove(imageUrl);

      final updatedVenue = Venue(
        id: venue.id,
        name: venue.name,
        description: venue.description,
        latitude: venue.latitude,
        longitude: venue.longitude,
        address: venue.address,
        imageUrls: updatedImages,
        pricePerHour: venue.pricePerHour,
        attributes: venue.attributes,
        managedBy: venue.managedBy,
        createdAt: venue.createdAt,
        averageRating: venue.averageRating,
        reviewCount: venue.reviewCount,
      );

      await ref.read(venueRepositoryProvider).updateVenue(updatedVenue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing image: $e')),
        );
      }
    }
  }

  Widget _buildLocationTab(Venue venue) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _addressController,
                label: 'Address (Optional)',
                hint: 'e.g., Kumaripati, Lalitpur',
              ),
              const SizedBox(height: 16),
              const Text(
                'Map Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap on the map to update location',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _selectedLocation ??
                        const LatLng(27.7172, 85.3240), // Default to Kathmandu
                    initialZoom: 13.0,
                    onTap: (position, latlng) {
                      setState(() {
                        _selectedLocation = latlng;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.fursal_mobile',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on,
                                color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.black),
                    onPressed: () {
                      // TODO: Implement get current location
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityTab(Venue venue) {
    final venueSlotsAsync = ref.watch(venueSlotsProvider(venue.id));

    return Column(
      children: [
        // Header with week navigation
        _buildWeekHeader(),
        // Legend
        _buildSlotLegend(),
        // Slot grid
        Expanded(
          child: venueSlotsAsync.when(
            data: (venueSlots) => venueSlots != null
                ? _buildSlotGrid(venueSlots)
                : const Center(child: Text('No slot data available')),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _selectedWeekStart =
                  _selectedWeekStart.subtract(const Duration(days: 7));
            }),
          ),
          Text(
            '${dateFormat.format(_selectedWeekStart)} - ${dateFormat.format(weekEnd)}, ${_selectedWeekStart.year}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _selectedWeekStart =
                  _selectedWeekStart.add(const Duration(days: 7));
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Available', Colors.green.shade100, Colors.green),
          const SizedBox(width: 16),
          _buildLegendItem('Booked', Colors.amber.shade100, Colors.amber),
          const SizedBox(width: 16),
          _buildLegendItem('Physical', Colors.green, Colors.green),
          const SizedBox(width: 16),
          _buildLegendItem('Blocked', Colors.red.shade100, Colors.red),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color bgColor, Color borderColor) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSlotGrid(VenueSlotData venueSlots) {
    final config = venueSlots.config;
    final timeSlots = _generateTimeSlots(config);
    final weekDays =
        List.generate(7, (i) => _selectedWeekStart.add(Duration(days: i)));
    final today = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate slot width based on available space
        // Use fixed width for scrolling, or fit to screen if possible
        final availableWidth =
            constraints.maxWidth - _timeColumnWidth - 16; // 16 for padding
        final fittedSlotWidth = availableWidth / 7;
        final useFixedWidth =
            fittedSlotWidth < 60; // If too small, use horizontal scroll
        final slotWidth = useFixedWidth ? _slotWidth : fittedSlotWidth;
        final totalWidth = _timeColumnWidth + (7 * slotWidth) + 16;

        Widget buildContent() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day headers
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: _timeColumnWidth), // Time column spacer
                  ...weekDays.map((day) {
                    final isToday = day.year == today.year &&
                        day.month == today.month &&
                        day.day == today.day;
                    final isOperating =
                        config.daysOfWeek.contains(day.weekday % 7);
                    return SizedBox(
                      width: slotWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isToday ? Colors.orange : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('E').format(day),
                              style: TextStyle(
                                fontSize: 12,
                                color: isToday
                                    ? Colors.white
                                    : (isOperating
                                        ? Colors.black
                                        : Colors.grey),
                              ),
                            ),
                            Text(
                              day.day.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isToday
                                    ? Colors.white
                                    : (isOperating
                                        ? Colors.black
                                        : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              // Time slots grid
              ...timeSlots.map((time) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: _timeColumnWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            time,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      ),
                      ...weekDays.map((day) {
                        final dateStr = DateFormat('yyyy-MM-dd').format(day);
                        final isOperating =
                            config.daysOfWeek.contains(day.weekday % 7);

                        if (!isOperating) {
                          return SizedBox(
                            width: slotWidth,
                            child: Container(
                              height: 44,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: Text('No slots',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 10)),
                              ),
                            ),
                          );
                        }

                        final status =
                            _getSlotStatus(venueSlots, dateStr, time);
                        return SizedBox(
                          width: slotWidth,
                          child: GestureDetector(
                            onTap: () =>
                                _onSlotTap(venueSlots, dateStr, time, status),
                            child: _buildSlotCell(time, status),
                          ),
                        );
                      }),
                    ],
                  )),
            ],
          );
        }

        if (useFixedWidth) {
          // Needs horizontal scroll
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: totalWidth,
                child: buildContent(),
              ),
            ),
          );
        } else {
          // Fits on screen, no horizontal scroll needed
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: buildContent(),
          );
        }
      },
    );
  }

  List<String> _generateTimeSlots(VenueConfig config) {
    final slots = <String>[];
    final startParts = config.startTime.split(':');
    final endParts = config.endTime.split(':');

    int startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    while (startMinutes < endMinutes) {
      final hours = startMinutes ~/ 60;
      final mins = startMinutes % 60;
      slots.add(
          '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}');
      startMinutes += config.slotDuration;
    }
    return slots;
  }

  String _getSlotStatus(VenueSlotData data, String date, String time) {
    // Check blocked
    if (data.blocked.any((s) => s.date == date && s.startTime == time)) {
      return 'blocked';
    }
    // Check booked
    final booking = data.bookings
        .where((s) =>
            s.date == date && s.startTime == time && s.status != 'cancelled')
        .firstOrNull;
    if (booking != null) {
      return booking.bookingType == 'physical' ? 'physical' : 'booked';
    }
    // Check held
    final now = DateTime.now();
    if (data.held.any((s) =>
        s.date == date &&
        s.startTime == time &&
        s.holdExpiresAt.toDate().isAfter(now))) {
      return 'held';
    }
    // Check reserved
    if (data.reserved.any((s) => s.date == date && s.startTime == time)) {
      return 'reserved';
    }
    return 'available';
  }

  Widget _buildSlotCell(String time, String status) {
    Color bgColor;
    Color borderColor;
    String label;

    switch (status) {
      case 'blocked':
        bgColor = Colors.red.shade50;
        borderColor = Colors.red;
        label = 'Blocked';
        break;
      case 'booked':
        bgColor = Colors.amber.shade100;
        borderColor = Colors.amber.shade700;
        label = 'Booked';
        break;
      case 'physical':
        bgColor = Colors.green;
        borderColor = Colors.green.shade700;
        label = 'Physical';
        break;
      case 'held':
        bgColor = Colors.orange.shade100;
        borderColor = Colors.orange;
        label = 'Held';
        break;
      case 'reserved':
        bgColor = Colors.purple.shade100;
        borderColor = Colors.purple;
        label = 'Reserved';
        break;
      default:
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        label = 'Available';
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(time,
                style: TextStyle(
                    fontSize: 10,
                    color:
                        status == 'physical' ? Colors.white : Colors.black87)),
            Text(label,
                style: TextStyle(
                    fontSize: 8,
                    color:
                        status == 'physical' ? Colors.white70 : Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _onSlotTap(VenueSlotData data, String date, String time, String status) {
    // Show action dialog based on status
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Slot: $date at $time'),
              subtitle: Text('Status: ${status.toUpperCase()}'),
            ),
            const Divider(),
            if (status == 'available') ...[
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block this slot'),
                onTap: () {
                  Navigator.pop(ctx);
                  _blockSlot(date, time);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.green),
                title: const Text('Create physical booking'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPhysicalBookingDialog(date, time);
                },
              ),
            ],
            if (status == 'blocked')
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Unblock this slot'),
                onTap: () {
                  Navigator.pop(ctx);
                  _unblockSlot(date, time);
                },
              ),
            if (status == 'booked' || status == 'physical')
              ListTile(
                leading: const Icon(Icons.info, color: Colors.blue),
                title: const Text('View booking details'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBookingDetails(data, date, time);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(VenueSlotData data, String date, String time) {
    // Find the booking for this slot
    final booking = data.bookings.firstWhere(
      (b) => b.date == date && b.startTime == time,
      orElse: () => BookedSlot(date: date, startTime: time),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              booking.bookingType == 'physical'
                  ? Icons.person
                  : Icons.phone_android,
              color: booking.bookingType == 'physical'
                  ? Colors.green
                  : Colors.amber,
            ),
            const SizedBox(width: 8),
            Text(booking.bookingType == 'physical'
                ? 'Physical Booking'
                : 'Online Booking'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Date', date),
              _buildDetailRow('Time', time),
              _buildDetailRow(
                  'Status', (booking.status ?? 'confirmed').toUpperCase()),
              if (booking.customerName != null)
                _buildDetailRow('Customer', booking.customerName!),
              if (booking.customerPhone != null &&
                  booking.customerPhone!.isNotEmpty)
                _buildDetailRow('Phone', booking.customerPhone!),
              if (booking.notes != null && booking.notes!.isNotEmpty)
                _buildDetailRow('Notes', booking.notes!),
              if (booking.bookingId != null)
                _buildDetailRow('Booking ID', booking.bookingId!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _blockSlot(String date, String time) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      final token = await user.getIdToken();
      const baseUrl =
          'http://192.168.1.90:3000'; // TODO: Use environment config

      final response = await http.post(
        Uri.parse('$baseUrl/api/slots/block'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'venueId': widget.venueId,
          'date': date,
          'startTime': time,
        }),
      );

      if (response.statusCode == 200) {
        // Refresh the venue slots
        ref.invalidate(venueSlotsProvider(widget.venueId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Slot $date $time blocked successfully')),
          );
        }
      } else {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to block slot';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unblockSlot(String date, String time) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      final token = await user.getIdToken();
      const baseUrl = 'http://192.168.1.90:3000';

      final response = await http.post(
        Uri.parse('$baseUrl/api/slots/unblock'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'venueId': widget.venueId,
          'date': date,
          'startTime': time,
        }),
      );

      if (response.statusCode == 200) {
        ref.invalidate(venueSlotsProvider(widget.venueId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Slot $date $time unblocked successfully')),
          );
        }
      } else {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to unblock slot';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showPhysicalBookingDialog(String date, String time) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Physical Booking - $date $time'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  hintText: 'Enter customer name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional notes',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Customer name is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Create Booking'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _createPhysicalBooking(
        date,
        time,
        nameController.text,
        phoneController.text,
        notesController.text,
      );
    }
  }

  Future<void> _createPhysicalBooking(
    String date,
    String startTime,
    String customerName,
    String customerPhone,
    String notes,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();
      const baseUrl = 'http://192.168.1.90:3000';

      // Calculate end time (1 hour later by default)
      final startParts = startTime.split(':');
      final endHour = (int.parse(startParts[0]) + 1) % 24;
      final endTime = '${endHour.toString().padLeft(2, '0')}:${startParts[1]}';

      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings/physical'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'venueId': widget.venueId,
          'date': date,
          'startTime': startTime,
          'endTime': endTime,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        ref.invalidate(venueSlotsProvider(widget.venueId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Physical booking created for $customerName')),
          );
        }
      } else {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to create booking';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixText: prefixText,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black87),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }
}
