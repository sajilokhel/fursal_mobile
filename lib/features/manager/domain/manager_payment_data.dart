/// Models for GET /api/manager/payments response.

class DuePaymentRecord {
  final String id;
  final String bookingId;
  final String venueId;
  final String venueName;
  final String? userId;
  final String userName;
  final String userEmail;
  final String managerId;
  final double amount;
  final String paymentMethod;
  final String bookingDate;
  final String bookingStartTime;
  final String bookingEndTime;
  final String? createdAt;

  const DuePaymentRecord({
    required this.id,
    required this.bookingId,
    required this.venueId,
    required this.venueName,
    this.userId,
    required this.userName,
    required this.userEmail,
    required this.managerId,
    required this.amount,
    required this.paymentMethod,
    required this.bookingDate,
    required this.bookingStartTime,
    required this.bookingEndTime,
    this.createdAt,
  });

  factory DuePaymentRecord.fromJson(Map<String, dynamic> j) =>
      DuePaymentRecord(
        id: j['id'] ?? '',
        bookingId: j['bookingId'] ?? '',
        venueId: j['venueId'] ?? '',
        venueName: j['venueName'] ?? '',
        userId: j['userId'],
        userName: j['userName'] ?? '',
        userEmail: j['userEmail'] ?? '',
        managerId: j['managerId'] ?? '',
        amount: (j['amount'] ?? 0).toDouble(),
        paymentMethod: j['paymentMethod'] ?? '',
        bookingDate: j['bookingDate'] ?? '',
        bookingStartTime: j['bookingStartTime'] ?? '',
        bookingEndTime: j['bookingEndTime'] ?? '',
        createdAt: j['createdAt'],
      );
}

/// A raw eSewa / online payment transaction record from Firestore.
class PaymentRecord {
  final String id;
  final Map<String, dynamic> raw;

  const PaymentRecord({required this.id, required this.raw});

  factory PaymentRecord.fromJson(Map<String, dynamic> j) =>
      PaymentRecord(id: j['id'] ?? '', raw: j);

  String get venueName => raw['venueName'] ?? raw['venue'] ?? '';
  String get userName =>
      raw['userName'] ?? raw['customerName'] ?? raw['userId'] ?? '';
  double get amount => (raw['amount'] ?? 0).toDouble();
  String get status =>
      raw['paymentStatus'] ?? raw['esewaStatus'] ?? raw['status'] ?? '';
  String? get createdAt => raw['createdAt'];
  String get bookingId => raw['bookingId'] ?? raw['id'] ?? '';
  String get bookingDate => raw['date'] ?? raw['bookingDate'] ?? '';
  String get paymentMethod => raw['paymentMethod'] ?? 'eSewa';
}

class ManagerPaymentData {
  final List<PaymentRecord> payments;
  final List<DuePaymentRecord> duePayments;

  const ManagerPaymentData(
      {required this.payments, required this.duePayments});

  factory ManagerPaymentData.fromJson(Map<String, dynamic> j) =>
      ManagerPaymentData(
        payments: (j['payments'] as List? ?? [])
            .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        duePayments: (j['duePayments'] as List? ?? [])
            .map((e) => DuePaymentRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
