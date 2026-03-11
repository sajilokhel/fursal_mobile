import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'logger_service.dart';

class BookingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> holdSlot({
    required String venueId,
    required String slotId,
    required String date,
    required String startTime,
    required String bookingId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();

    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/slots/hold');
    final bodyMap = {
      'venueId': venueId,
      'slotId': slotId,
      'date': date,
      'startTime': startTime,
      'bookingId': bookingId,
    };
    final body = jsonEncode(bodyMap);

    await LoggerService().info('holdSlot: request', meta: {
      'uri': uri.toString(),
      'body': bodyMap,
      'userId': user.uid,
    });

    final resp = await _postWithRedirects(uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body);

    await LoggerService().info('holdSlot: response', meta: {
      'status': resp.statusCode,
      'body': resp.body,
    });

    // If slot not found, try again without slotId (some backends identify slots by venue/date/time)
    if (resp.statusCode == 404 && resp.body.contains('Slot not found')) {
      await LoggerService().info(
          'holdSlot: slot not found with slotId, retrying without slotId',
          meta: {
            'originalBody': bodyMap,
            'status': resp.statusCode,
            'body': resp.body,
          });

      final fallbackBodyMap = Map<String, dynamic>.from(bodyMap)
        ..remove('slotId');
      final fallbackBody = jsonEncode(fallbackBodyMap);
      final resp2 = await _postWithRedirects(uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: fallbackBody);

      await LoggerService()
          .info('holdSlot: response (retry without slotId)', meta: {
        'status': resp2.statusCode,
        'body': resp2.body,
      });

      if (resp2.statusCode != 200 && resp2.statusCode != 201) {
        await LoggerService().error('holdSlot failed (retry)', meta: {
          'status': resp2.statusCode,
          'body': resp2.body,
        });
        throw Exception('Hold slot failed: ${resp2.statusCode} ${resp2.body}');
      }

      return jsonDecode(resp2.body) as Map<String, dynamic>;
    }

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      await LoggerService().error('holdSlot failed', meta: {
        'status': resp.statusCode,
        'body': resp.body,
      });
      throw Exception('Hold slot failed: ${resp.statusCode} ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBooking({
    required Map<String, dynamic> booking,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/bookings');
    await LoggerService().info('createBooking: request', meta: {
      'uri': uri.toString(),
      'booking': booking,
      'userId': user.uid,
    });

    final resp = await _postWithRedirects(uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(booking));

    await LoggerService().info('createBooking: response', meta: {
      'status': resp.statusCode,
      'body': resp.body,
    });

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      await LoggerService().error('createBooking failed', meta: {
        'status': resp.statusCode,
        'body': resp.body,
      });
      throw Exception('Create booking failed: ${resp.statusCode} ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Create booking via backend API using venueId and slotId.
  /// Returns the backend response (expected to include bookingId).
  Future<Map<String, dynamic>> createBookingViaApi({
    required String venueId,
    required String date,
    required String startTime,
    String? endTime,
    required double amount,
    String? venueName,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/bookings');
    final bodyMap = {
      'venueId': venueId,
      'date': date,
      'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'amount': amount,
      if (venueName != null) 'venueName': venueName,
      if (metadata != null) 'metadata': metadata,
    };
    final body = jsonEncode(bodyMap);

    await LoggerService().info('createBookingViaApi: request', meta: {
      'uri': uri.toString(),
      'body': bodyMap,
      'userId': user.uid,
    });

    final resp = await _postWithRedirects(uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body);

    await LoggerService().info('createBookingViaApi: response', meta: {
      'status': resp.statusCode,
      'body': resp.body,
    });
    if (resp.statusCode != 200 &&
        resp.statusCode != 201 &&
        resp.statusCode != 201) {
      await LoggerService().error('createBookingViaApi failed', meta: {
        'status': resp.statusCode,
        'body': resp.body,
      });
      String msg = resp.body;
      try {
        final parsed = jsonDecode(resp.body);
        if (parsed is Map && parsed['error'] != null) {
          msg = parsed['error'].toString();
        }
      } catch (_) {}
      throw Exception('Create booking failed: ${resp.statusCode} $msg');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Verify eSewa payment for a booking
  Future<Map<String, dynamic>> verifyEsewaPayment({
    required String transactionUuid,
    required String productCode,
    required double totalAmount,
  }) async {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/payment/verify');
    final body = jsonEncode({
      'transactionUuid': transactionUuid,
      'productCode': productCode,
      'totalAmount': totalAmount,
    });

    await LoggerService().info('verifyEsewaPayment: request', meta: {
      'uri': uri.toString(),
      'body': body,
    });

    // This endpoint doesn't require a Bearer token according to docs
    final resp = await _postWithRedirects(uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body);

    await LoggerService().info('verifyEsewaPayment: response', meta: {
      'status': resp.statusCode,
      'body': resp.body,
    });

    if (resp.statusCode != 200) {
      throw Exception('Payment verification failed: ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Download invoice for a booking ID. Returns the raw bytes of the PDF.
  Future<List<int>> downloadInvoice(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/invoices/$bookingId');

    await LoggerService().info('downloadInvoice: request', meta: {
      'uri': uri.toString(),
      'bookingId': bookingId,
    });

    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $idToken',
    });

    if (resp.statusCode != 200) {
      await LoggerService().error('downloadInvoice failed', meta: {
        'status': resp.statusCode,
        'body': resp.body,
      });
      throw Exception('Failed to download invoice: ${resp.statusCode}');
    }

    return resp.bodyBytes;
  }

  /// Verify a QR code payload (base64 string) via the backend.
  Future<Map<String, dynamic>> verifyInvoiceQr(String qr) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/invoices/verify');
    final body = jsonEncode({'qr': qr});

    await LoggerService().info('verifyInvoiceQr: request', meta: {
      'uri': uri.toString(),
    });

    final resp = await _postWithRedirects(uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body);

    if (resp.statusCode != 200) {
      await LoggerService().error('verifyInvoiceQr failed', meta: {
        'status': resp.statusCode,
        'body': resp.body,
      });
      throw Exception('Failed to verify invoice: ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Helper to POST while following redirect locations up to [maxRedirects].
  Future<http.Response> _postWithRedirects(Uri uri,
      {required Map<String, String> headers,
      required String body,
      int maxRedirects = 5}) async {
    Uri current = uri;
    for (int i = 0; i <= maxRedirects; i++) {
      final resp = await http.post(current, headers: headers, body: body);
      if (resp.statusCode == 307 ||
          resp.statusCode == 302 ||
          resp.statusCode == 301) {
        final loc = resp.headers['location'];
        if (loc == null) return resp;
        // Resolve relative redirect
        current =
            Uri.parse(loc).isAbsolute ? Uri.parse(loc) : current.resolve(loc);
        await LoggerService().info('redirect',
            meta: {'to': current.toString(), 'code': resp.statusCode});
        // continue loop to re-post to new location
        continue;
      }
      return resp;
    }
    throw Exception('Too many redirects');
  }

  Future<Map<String, dynamic>> applyCoupon({
    required String bookingId,
    required String code,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final uri =
        Uri.parse('${AppConfig.backendBaseUrl}/api/bookings/apply-coupon');
    final bodyMap = {
      'bookingId': bookingId,
      'code': code,
    };
    final body = jsonEncode(bodyMap);

    await LoggerService().info('applyCoupon: request', meta: {
      'uri': uri.toString(),
      'body': bodyMap,
    });

    final resp = await _postWithRedirects(uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body);

    await LoggerService().info('applyCoupon: response', meta: {
      'status': resp.statusCode,
      'body': resp.body,
    });

    if (resp.statusCode != 200) {
      String msg = resp.body;
      try {
        final parsed = jsonDecode(resp.body);
        if (parsed is Map && parsed['message'] != null) {
          msg = parsed['message'];
        } else if (parsed is Map && parsed['error'] != null) {
          msg = parsed['error'];
        }
      } catch (_) {}
      throw Exception(msg);
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
