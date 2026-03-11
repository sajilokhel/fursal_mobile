import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../../core/theme.dart';
import '../../../core/config.dart';
import '../../venues/data/venue_repository.dart';
import '../../venues/domain/venue.dart';
import '../../venues/domain/venue_slot.dart';
import 'widgets/blocking_reason_dialog.dart';

class ManagerVenueSlotsScreen extends ConsumerStatefulWidget {
  final String venueId;

  const ManagerVenueSlotsScreen({super.key, required this.venueId});

  @override
  ConsumerState<ManagerVenueSlotsScreen> createState() =>
      _ManagerVenueSlotsScreenState();
}

class _ManagerVenueSlotsScreenState
    extends ConsumerState<ManagerVenueSlotsScreen> {
  late DateTime _selectedWeekStart;
  bool _isLoading = false;
  static const double _slotWidth = 80.0;
  static const double _timeColumnWidth = 50.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeekStart = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final venueSlotsAsync = ref.watch(venueSlotsProvider(widget.venueId));
    final venueAsync = ref.watch(venuesProvider);

    final venueName = venueAsync.valueOrNull
            ?.firstWhere(
              (v) => v.id == widget.venueId,
              orElse: () => const Venue(
                id: '',
                name: 'Venue Slots',
                latitude: 0,
                longitude: 0,
                imageUrls: [],
                attributes: {},
                pricePerHour: 0,
                managedBy: '',
                createdAt: '',
              ),
            )
            .name ??
        'Venue Slots';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          venueName,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSlotLegend(),
              _buildWeekHeader(),
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
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            '${dateFormat.format(_selectedWeekStart)} – ${dateFormat.format(weekEnd)}, ${_selectedWeekStart.year}',
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _buildLegendItem('Available', Colors.green.shade50, Colors.green.shade300),
          _buildLegendItem('Booked', Colors.amber.shade100, Colors.amber.shade700),
          _buildLegendItem('Physical', Colors.green, Colors.green.shade700),
          _buildLegendItem('Blocked', Colors.red.shade50, Colors.red),
          _buildLegendItem('Held', Colors.orange.shade100, Colors.orange),
          _buildLegendItem('Reserved', Colors.purple.shade100, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color bgColor, Color borderColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
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
        final availableWidth = constraints.maxWidth - _timeColumnWidth - 16;
        final fittedSlotWidth = availableWidth / 7;
        final useFixedWidth = fittedSlotWidth < 60;
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
                  const SizedBox(width: _timeColumnWidth),
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
              // Time slot rows
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

                        // Check if this slot is in the past
                        final timeParts = time.split(':');
                        final slotDateTime = DateTime(
                          day.year, day.month, day.day,
                          int.parse(timeParts[0]),
                          int.parse(timeParts[1]),
                        );
                        final isPast = slotDateTime.isBefore(today);

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
                                child: Text('—',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 10)),
                              ),
                            ),
                          );
                        }

                        if (isPast) {
                          return SizedBox(
                            width: slotWidth,
                            child: Container(
                              height: 44,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Center(
                                child: Text('—',
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
    int startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
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
    if (data.blocked.any((s) => s.date == date && s.startTime == time)) {
      return 'blocked';
    }
    final booking = data.bookings
        .where((s) =>
            s.date == date && s.startTime == time && s.status != 'cancelled')
        .firstOrNull;
    if (booking != null) {
      return booking.bookingType == 'physical' ? 'physical' : 'booked';
    }
    final now = DateTime.now();
    if (data.held.any((s) =>
        s.date == date &&
        s.startTime == time &&
        s.holdExpiresAt.toDate().isAfter(now))) {
      return 'held';
    }
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
        label = 'Free';
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
            Text(
              time,
              style: TextStyle(
                  fontSize: 10,
                  color:
                      status == 'physical' ? Colors.white : Colors.black87),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 8,
                  color:
                      status == 'physical' ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _onSlotTap(
      VenueSlotData data, String date, String time, String status) {
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
                onTap: () async {
                  Navigator.pop(ctx);
                  final reason = await showDialog<String>(
                    context: context,
                    builder: (context) => const BlockingReasonDialog(),
                  );
                  if (reason != null) {
                    _blockSlot(date, time, reason: reason);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.green),
                title: const Text('Create physical booking'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPhysicalBookingDialog(date, time, data);
                },
              ),
            ],
            if (status == 'blocked')
              ListTile(
                leading:
                    const Icon(Icons.check_circle, color: Colors.green),
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
              _detailRow('Date', date),
              _detailRow('Time', time),
              _detailRow(
                  'Status', (booking.status ?? 'confirmed').toUpperCase()),
              if (booking.customerName != null)
                _detailRow('Customer', booking.customerName!),
              if (booking.customerPhone != null &&
                  booking.customerPhone!.isNotEmpty)
                _detailRow('Phone', booking.customerPhone!),
              if (booking.notes != null && booking.notes!.isNotEmpty)
                _detailRow('Notes', booking.notes!),
              if (booking.bookingId != null)
                _detailRow('Booking ID', booking.bookingId!),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _blockSlot(String date, String time, {String? reason}) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }
      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/slots/block'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'venueId': widget.venueId,
          'date': date,
          'startTime': time,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        ref.invalidate(venueSlotsProvider(widget.venueId));
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Slot $date $time blocked')),
          );
        }
      } else {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to block slot';
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unblockSlot(String date, String time) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }
      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/slots/unblock'),
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
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Slot $date $time unblocked')),
          );
        }
      } else {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to unblock slot';
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showPhysicalBookingDialog(
      String date, String time, VenueSlotData venueSlots) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Physical Booking\n$date at $time',
            style: const TextStyle(fontSize: 16)),
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
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Customer name is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _createPhysicalBooking(
        date,
        time,
        nameController.text.trim(),
        phoneController.text.trim(),
        notesController.text.trim(),
        config: venueSlots.config,
      );
    }
  }

  Future<void> _createPhysicalBooking(
    String date,
    String startTime,
    String customerName,
    String customerPhone,
    String notes, {
    required VenueConfig config,
  }) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }
      final token = await user.getIdToken();

      // Calculate endTime from slot duration
      final startParts = startTime.split(':');
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = startMinutes + config.slotDuration;
      final endTime =
          '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:${(endMinutes % 60).toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/bookings/physical'),
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        ref.invalidate(venueSlotsProvider(widget.venueId));
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Physical booking created for $customerName')),
          );
        }
      } else {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to create booking';
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
