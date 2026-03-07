import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts any Timestamp-like value from Firestore or a JSON API response
/// into a Firestore [Timestamp].
/// Handles:
///  - native [Timestamp]
///  - JSON map  {"_seconds":…,"_nanoseconds":…}  or  {"seconds":…,"nanoseconds":…}
///  - ISO-8601 string
///  - null → falls back to [fallback] (default: Timestamp.now())
Timestamp _toTimestamp(dynamic v, {Timestamp? fallback}) {
  if (v is Timestamp) return v;
  if (v is Map) {
    final sec = (v['_seconds'] ?? v['seconds'] ?? 0) as int;
    final ns = (v['_nanoseconds'] ?? v['nanoseconds'] ?? 0) as int;
    return Timestamp(sec, ns);
  }
  if (v is String) {
    try {
      return Timestamp.fromDate(DateTime.parse(v));
    } catch (_) {}
  }
  return fallback ?? Timestamp.now();
}

Timestamp? _toTimestampOrNull(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v;
  if (v is Map) {
    final sec = (v['_seconds'] ?? v['seconds'] ?? 0) as int;
    final ns = (v['_nanoseconds'] ?? v['nanoseconds'] ?? 0) as int;
    return Timestamp(sec, ns);
  }
  if (v is String) {
    try {
      return Timestamp.fromDate(DateTime.parse(v));
    } catch (_) {}
  }
  return null;
}

class Booking {
  final String id;
  final String venueId;
  final String venueName;
  final String userId;
  final String? userName;
  final String? userPhone;
  final String date;
  final String startTime;
  final String endTime;
  final double amount;
  final String status; // 'pending', 'confirmed', 'cancelled', 'completed'
  final Timestamp createdAt;
  final Timestamp? holdExpiresAt;
  final String? bookingType;
  final String? notes;
  final String? paymentStatusField; // Direct payment status from Firestore
  final double? esewaAmount;
  final Timestamp? esewaInitiatedAt;
  final String? esewaStatus;
  final String? esewaTransactionCode;
  final String? esewaTransactionUuid;
  final Timestamp? paymentTimestamp;
  final Timestamp? verifiedAt;

  Booking({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.userId,
    this.userName,
    this.userPhone,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.holdExpiresAt,
    this.bookingType,
    this.notes,
    this.paymentStatusField,
    this.esewaAmount,
    this.esewaInitiatedAt,
    this.esewaStatus,
    this.esewaTransactionCode,
    this.esewaTransactionUuid,
    this.paymentTimestamp,
    this.verifiedAt,
  });

  // Computed property for UI compatibility
  String get paymentStatus =>
      paymentStatusField ?? (esewaStatus == 'COMPLETE' ? 'paid' : 'pending');
  String? get paymentId => esewaTransactionCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venueId': venueId,
      'venueName': venueName,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'amount': amount,
      'status': status,
      'createdAt': createdAt,
      'holdExpiresAt': holdExpiresAt,
      'bookingType': bookingType,
      'notes': notes,
      'paymentStatus': paymentStatusField,
      'esewaAmount': esewaAmount,
      'esewaInitiatedAt': esewaInitiatedAt,
      'esewaStatus': esewaStatus,
      'esewaTransactionCode': esewaTransactionCode,
      'esewaTransactionUuid': esewaTransactionUuid,
      'paymentTimestamp': paymentTimestamp,
      'verifiedAt': verifiedAt,
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] ?? '',
      venueId: map['venueId'] ?? '',
      venueName: map['venueName'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'],
      userPhone: map['userPhone'],
      date: map['date'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      createdAt: _toTimestamp(map['createdAt']),
      holdExpiresAt: _toTimestampOrNull(map['holdExpiresAt']),
      bookingType: map['bookingType'],
      notes: map['notes'],
      paymentStatusField: map['paymentStatus'],
      esewaAmount: (map['esewaAmount'] ?? 0).toDouble(),
      esewaInitiatedAt: _toTimestampOrNull(map['esewaInitiatedAt']),
      esewaStatus: map['esewaStatus'],
      esewaTransactionCode: map['esewaTransactionCode'],
      esewaTransactionUuid: map['esewaTransactionUuid'],
      paymentTimestamp: _toTimestampOrNull(map['paymentTimestamp']),
      verifiedAt: _toTimestampOrNull(map['verifiedAt']),
    );
  }
}
