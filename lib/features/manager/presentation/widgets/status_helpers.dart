import 'package:flutter/material.dart';

/// Returns the appropriate color for a booking status.
/// Used across multiple screens for consistent status styling.
Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    case 'cancelled':
    case 'cancelled (user)':
    case 'expired':
      return Colors.red;
    case 'booked':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}
