import 'package:flutter/material.dart';
import '../../../bookings/domain/booking.dart';
import 'status_helpers.dart';

/// Distinct manager booking card with status-coloured left accent,
/// clear customer/time/amount hierarchy, and a Physical/Online badge.
class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;

  const BookingCard({super.key, required this.booking, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(booking.status);
    final isCancelled = booking.status.toLowerCase() == 'cancelled' ||
        booking.status.toLowerCase() == 'expired';
    final isPhysical =
        booking.bookingType == 'physical' || booking.bookingType == 'manual';
    final customerName = booking.userName ?? 'Customer';
    final amountPaid = booking.esewaAmount ?? 0;
    final amountDue =
        isPhysical ? booking.amount : (booking.amount - amountPaid);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Colour accent strip ──────────────────────────
                Container(width: 5, color: statusColor),

                // ── Card content ─────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Status chip  +  Physical/Online badge
                        Row(
                          children: [
                            _StatusChip(
                                label: booking.status.toUpperCase(),
                                color: statusColor),
                            const SizedBox(width: 8),
                            _TypeBadge(isPhysical: isPhysical),
                            const Spacer(),
                            // Date
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  booking.date,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 2: Customer name (prominent)
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: statusColor.withOpacity(0.12),
                              child: Text(
                                customerName.isNotEmpty
                                    ? customerName[0].toUpperCase()
                                    : 'C',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                customerName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Row 3: Venue name (smaller)
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                booking.venueName,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 4: Time  |  Amount
                        Row(
                          children: [
                            // Time
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${booking.startTime} – ${booking.endTime}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                            // Amount
                            if (!isCancelled) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: amountDue > 0
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      amountDue > 0
                                          ? Icons.hourglass_top_rounded
                                          : Icons.check_circle_rounded,
                                      size: 12,
                                      color: amountDue > 0
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      amountDue > 0
                                          ? 'Due Rs. ${amountDue.toStringAsFixed(0)}'
                                          : 'Paid Rs. ${booking.amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: amountDue > 0
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Advance paid row (online only)
                        if (!isPhysical && amountPaid > 0) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 17),
                            child: Text(
                              'Advance paid: Rs. ${amountPaid.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.green),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final bool isPhysical;
  const _TypeBadge({required this.isPhysical});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isPhysical ? Colors.teal.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPhysical ? Icons.storefront_outlined : Icons.phone_android,
            size: 10,
            color: isPhysical ? Colors.teal : Colors.blue,
          ),
          const SizedBox(width: 3),
          Text(
            isPhysical ? 'Physical' : 'Online',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isPhysical ? Colors.teal : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
