import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // For iOS, we need to request permissions.
    // We can do this on init or on demand. Doing it here for simplicity.
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      // onDidReceiveNotificationResponse: ... handle tap
    );
  }

  Future<void> scheduleBookingNotification({
    required int id,
    required String venueName,
    required DateTime bookingTime,
  }) async {
    // Schedule 1 hour before booking
    final scheduledTime = bookingTime.subtract(const Duration(hours: 1));

    // If time is already passed, don't schedule
    if (scheduledTime.isBefore(DateTime.now())) {
      print('Notification time $scheduledTime is in past, skipping');
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      'Upcoming Game!',
      'You have a booking at $venueName in 1 hour (${_formatTime(bookingTime)}).',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'booking_reminders',
          'Booking Reminders',
          channelDescription: 'Notifications for upcoming bookings',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('Scheduled notification for $venueName at $scheduledTime');
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> cancelid(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
