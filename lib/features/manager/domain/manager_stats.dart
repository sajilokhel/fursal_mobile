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

    num _n(dynamic v) => v is num ? v : 0;

    return ManagerStats(
      totalBookings: (_n(s['totalBookings'])).toInt(),
      physicalBookings: (_n(s['physicalBookings'])).toInt(),
      onlineBookings: (_n(s['onlineBookings'])).toInt(),
      totalIncome: (_n(s['totalIncome'])).toDouble(),
      physicalIncome: (_n(s['physicalIncome'])).toDouble(),
      onlineIncome: (_n(s['onlineIncome'])).toDouble(),
      safeOnlineIncome: (_n(s['safeOnlineIncome'])).toDouble(),
      commissionPercentage: (_n(s['commissionPercentage'])).toDouble(),
      commissionAmount: (_n(s['commissionAmount'])).toDouble(),
      netIncome: (_n(s['netIncome'])).toDouble(),
      totalPaidOut: (_n(d['totalPaidOut'])).toDouble(),
      heldByManager: (_n(d['heldByManager'])).toDouble(),
      heldByAdmin: (_n(d['heldByAdmin'])).toDouble(),
      totalToBePaid: (_n(d['totalToBePaid'])).toDouble(),
      actualPaymentToBePaid: (_n(d['actualPaymentToBePaid'])).toDouble(),
      cancellationLimit: (_n(json['cancellationLimit'])).toInt(),
    );
  }
}
