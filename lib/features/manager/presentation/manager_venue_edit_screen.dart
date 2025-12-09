import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme.dart';
import '../../venues/data/venue_repository.dart';
import '../../venues/domain/venue.dart';

class ManagerVenueEditScreen extends ConsumerStatefulWidget {
  final String venueId;

  const ManagerVenueEditScreen({
    super.key,
    required this.venueId,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _addressController = TextEditingController();
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
    return const Center(child: Text('Availability Scheduler - Coming Soon'));
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
