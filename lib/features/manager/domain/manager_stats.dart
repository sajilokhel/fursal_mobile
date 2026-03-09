class ManagerStats {
  // stats
  final int totalBookings;
  final int physicalBookings;
  final int onlineBookings;
  final double totalIncome;
  final double physicalIncome;
  final double onlineIncome;
  final double safeOnlineIncome;
  final double commissionPercentage;
  final double commissionAmount;
  final double netIncome;

  // derived
  final double totalPaidOut;
  final double heldByManager;
  final double heldByAdmin;
  final double totalToBePaid;
  final double actualPaymentToBePaid;

  // other
  final int cancellationLimit;

  const ManagerStats({
    required this.totalBookings,
    required this.physicalBookings,
    required this.onlineBookings,
    required this.totalIncome,
    required this.physicalIncome,
    required this.onlineIncome,
    required this.safeOnlineIncome,
    required this.commissionPercentage,
    required this.commissionAmount,
    required this.netIncome,
    required this.totalPaidOut,
    required this.heldByManager,
    required this.heldByAdmin,
    required this.totalToBePaid,
    required this.actualPaymentToBePaid,
    required this.cancellationLimit,
  });

  factory ManagerStats.fromJson(Map<String, dynamic> json) {
    final s = json['stats'] as Map<String, dynamic>? ?? {};
    final d = json['derived'] as Map<String, dynamic>? ?? {};

    num n(dynamic v) => v is num ? v : 0;

    return ManagerStats(
      totalBookings: (n(s['totalBookings'])).toInt(),
      physicalBookings: (n(s['physicalBookings'])).toInt(),
      onlineBookings: (n(s['onlineBookings'])).toInt(),
      totalIncome: (n(s['totalIncome'])).toDouble(),
      physicalIncome: (n(s['physicalIncome'])).toDouble(),
      onlineIncome: (n(s['onlineIncome'])).toDouble(),
      safeOnlineIncome: (n(s['safeOnlineIncome'])).toDouble(),
      commissionPercentage: (n(s['commissionPercentage'])).toDouble(),
      commissionAmount: (n(s['commissionAmount'])).toDouble(),
      netIncome: (n(s['netIncome'])).toDouble(),
      totalPaidOut: (n(d['totalPaidOut'])).toDouble(),
      heldByManager: (n(d['heldByManager'])).toDouble(),
      heldByAdmin: (n(d['heldByAdmin'])).toDouble(),
      totalToBePaid: (n(d['totalToBePaid'])).toDouble(),
      actualPaymentToBePaid: (n(d['actualPaymentToBePaid'])).toDouble(),
      cancellationLimit: (n(json['cancellationLimit'])).toInt(),
    );
  }
}
