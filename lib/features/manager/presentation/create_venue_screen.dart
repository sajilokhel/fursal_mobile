import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/theme.dart';
import '../../../core/sport_types.dart';
import '../../venues/data/venue_repository.dart';

class CreateVenueScreen extends ConsumerStatefulWidget {
  const CreateVenueScreen({super.key});

  @override
  ConsumerState<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends ConsumerState<CreateVenueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final MapController _mapController = MapController();

  // Basic Info
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedSportType = 'futsal';

  // Location
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  LatLng? _selectedLocation;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  // Slot Config
  TimeOfDay _openingTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);
  final _slotDurationController = TextEditingController(text: '60');
  final List<bool> _daysOfWeek = List.filled(7, true);

  // Images
  final List<File> _pendingImages = [];
  final ImagePicker _picker = ImagePicker();

  // Submission
  bool _isSubmitting = false;
  String _submitStatus = '';

  static const List<String> _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    _slotDurationController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=10'),
        headers: {'User-Agent': 'Fursal/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _handleSelectResult(dynamic result) {
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final newLocation = LatLng(lat, lon);

    setState(() {
      _selectedLocation = newLocation;
      _addressController.text = result['display_name'] ?? '';
      _searchResults = [];
      _searchController.clear();
    });

    _mapController.move(newLocation, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create New Venue',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Basic Info'),
            Tab(text: 'Location'),
            Tab(text: 'Slot Config'),
            Tab(text: 'Images'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildBasicInfoTab(),
              _buildLocationTab(),
              _buildSlotConfigTab(),
              _buildImagesTab(),
            ],
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _submitStatus,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5))
          ],
        ),
        child: Row(
          children: [
            if (_tabController.index > 0) ...[
              OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _tabController.animateTo(_tabController.index - 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black87),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('← Back'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onNextOrSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  disabledBackgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.6),
                ),
                child: Text(
                  _tabController.index < 3
                      ? 'Next: ${_getNextStepName()} →'
                      : 'Create Venue',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNextStepName() {
    switch (_tabController.index) {
      case 0:
        return 'Location';
      case 1:
        return 'Slot Config';
      case 2:
        return 'Images';
      default:
        return '';
    }
  }

  void _onNextOrSubmit() {
    if (_tabController.index == 0) {
      if (!_formKey.currentState!.validate()) return;
    }
    if (_tabController.index < 3) {
      _tabController.animateTo(_tabController.index + 1);
    } else {
      _submitForm();
    }
  }

  // ─── BASIC INFO ────────────────────────────────────────────────────────────

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fill in the basic details for your new venue.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _label('Venue Name *'),
            TextFormField(
              controller: _nameController,
              decoration: _inputDeco('e.g., Champion Sports Arena'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Venue name is required' : null,
            ),
            const SizedBox(height: 16),
            _label('Description'),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _inputDeco('Describe your venue...'),
            ),
            const SizedBox(height: 16),
            _label('Price per Hour (NPR) *'),
            TextFormField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDeco('e.g., 1500'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Price is required';
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('Sport Type'),
            DropdownButtonFormField<String>(
              initialValue: _selectedSportType,
              decoration: _inputDeco('Select sport type'),
              items: kAllSports
                  .map((sport) => DropdownMenuItem(
                      value: sport.id,
                      child: Text('${sport.emoji}  ${sport.name}')))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSportType = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── LOCATION ──────────────────────────────────────────────────────────────

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Search Location'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: _inputDeco('e.g., Downtown Sports Arena'),
                        onSubmitted: (v) => _searchLocation(v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSearching
                          ? null
                          : () => _searchLocation(_searchController.text),
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search),
                      style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor),
                    ),
                  ],
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(result['display_name'] ?? '',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(result['type'] ?? '',
                              style: const TextStyle(fontSize: 11)),
                          onTap: () => _handleSelectResult(result),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                _label('Address (Auto-filled)'),
                TextField(
                  controller: _addressController,
                  decoration: _inputDeco('Address will be set from search...'),
                ),
                if (_selectedLocation != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Selected: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: 400,
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
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _selectedLocation ?? const LatLng(27.7172, 85.3240),
                      initialZoom: 13.0,
                      onTap: (_, latlng) =>
                          setState(() => _selectedLocation = latlng),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.fursal_mobile',
                      ),
                      if (_selectedLocation != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on,
                                color: Colors.red, size: 40),
                          ),
                        ]),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location, color: Colors.black),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SLOT CONFIG ───────────────────────────────────────────────────────────

  Widget _buildSlotConfigTab() {
    final duration = int.tryParse(_slotDurationController.text) ?? 0;
    final openMinutes = _openingTime.hour * 60 + _openingTime.minute;
    final closeMinutes = _closingTime.hour * 60 + _closingTime.minute;
    final totalMinutes = closeMinutes - openMinutes;
    final slotsPerDay = (duration > 0 && totalMinutes > 0)
        ? (totalMinutes / duration).floor()
        : 0;
    final activeDays = _daysOfWeek.where((d) => d).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Opening Time *'),
                    _timePicker(
                      time: _openingTime,
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: _openingTime);
                        if (picked != null) setState(() => _openingTime = picked);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Closing Time *'),
                    _timePicker(
                      time: _closingTime,
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: _closingTime);
                        if (picked != null) setState(() => _closingTime = picked);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Slot Duration (minutes) *'),
          TextField(
            controller: _slotDurationController,
            keyboardType: TextInputType.number,
            decoration: _inputDeco('e.g., 60'),
            onChanged: (_) => setState(() {}),
          ),
          if (slotsPerDay > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$slotsPerDay slots per day (${_fmt(_openingTime)} - ${_fmt(_closingTime)})',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          _label('Operating Days *'),
          ...List.generate(
            7,
            (i) => CheckboxListTile(
              value: _daysOfWeek[i],
              onChanged: (val) => setState(() => _daysOfWeek[i] = val ?? false),
              title: Text(_dayNames[i], style: const TextStyle(fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configuration Summary:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                    '• Operating Hours: ${_fmt(_openingTime)} - ${_fmt(_closingTime)}'),
                Text('• Slot Duration: $duration minutes'),
                Text('• Slots per day: $slotsPerDay'),
                Text('• Operating Days: $activeDays day(s)/week'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timePicker({required TimeOfDay time, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(time.format(context), style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ─── IMAGES ────────────────────────────────────────────────────────────────

  Widget _buildImagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Venue Images (${_pendingImages.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                onPressed: _isSubmitting ? null : _pickImage,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Add'),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.black87),
              ),
            ],
          ),
        ),
        if (_pendingImages.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_not_supported_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No images added yet',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Images are optional',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Images'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.black87)),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: _pendingImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_pendingImages[index],
                          fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _pendingImages.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle),
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

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    setState(() => _pendingImages.add(File(image.path)));
  }

  // ─── SUBMIT ────────────────────────────────────────────────────────────────

  Future<void> _submitForm() async {
    final duration = int.tryParse(_slotDurationController.text.trim());
    if (duration == null || duration <= 0) {
      _tabController.animateTo(2);
      _showSnack('Please enter a valid slot duration');
      return;
    }

    final openMinutes = _openingTime.hour * 60 + _openingTime.minute;
    final closeMinutes = _closingTime.hour * 60 + _closingTime.minute;
    if (closeMinutes <= openMinutes) {
      _tabController.animateTo(2);
      _showSnack('Closing time must be after opening time');
      return;
    }

    final activeDayIndices = [
      for (int i = 0; i < 7; i++)
        if (_daysOfWeek[i]) i
    ];
    if (activeDayIndices.isEmpty) {
      _tabController.animateTo(2);
      _showSnack('Select at least one operating day');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitStatus = 'Starting submission...';
    });

    try {
      final repo = ref.read(venueRepositoryProvider);

      // 1. Upload images first (if any)
      final List<String> uploadedUrls = [];
      if (_pendingImages.isNotEmpty) {
        for (int i = 0; i < _pendingImages.length; i++) {
          setState(() => _submitStatus =
              'Uploading image ${i + 1} of ${_pendingImages.length}...');
          // Use 'temp' or dummy ID for filename generation since venue doesn't exist yet
          final url = await repo.uploadVenueImage(_pendingImages[i], 'new');
          uploadedUrls.add(url);
        }
      }

      setState(() => _submitStatus = 'Creating venue profile...');

      final slotConfig = {
        'startTime': _fmt(_openingTime),
        'endTime': _fmt(_closingTime),
        'slotDuration': duration,
        'daysOfWeek': activeDayIndices,
      };

      // 2. Create venue with the URLs already included
      await repo.createVenue(
        name: _nameController.text.trim(),
        pricePerHour: double.parse(_priceController.text.trim()),
        slotConfig: slotConfig,
        description: _descriptionController.text.trim(),
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
        address: _addressController.text.trim(),
        sportType: _selectedSportType,
        imageUrls: uploadedUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Venue created successfully!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitStatus = '';
        });
        if (e is VenueDebugException) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(e.title,
                  style:
                      const TextStyle(color: Colors.red, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('URL:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SelectableText(e.url,
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text('Status Code:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${e.statusCode}'),
                    const SizedBox(height: 8),
                    const Text('Request Body:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SelectableText(e.requestBody,
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace')),
                    const SizedBox(height: 8),
                    const Text('Server Response:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SelectableText(e.responseBody,
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close')),
              ],
            ),
          );
        } else {
          _showSnack('Error: $e');
        }
      }
    }
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
      );
}
