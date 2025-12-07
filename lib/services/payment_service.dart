import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'logger_service.dart';

class PaymentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Calls backend `/api/payment/initiate` to get payment params for client.
  /// Expects backend to return JSON with transactionUuid and paymentParams.
  Future<Map<String, dynamic>> initiatePayment({
    required String bookingId,
    String? transactionUuid,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    final idToken = await user.getIdToken();

    final uri = Uri.parse(AppConfig.paymentInitiateUrl());
    final bodyMap = {
      'bookingId': bookingId,
      if (transactionUuid != null) 'transactionUuid': transactionUuid,
    };
    final body = jsonEncode(bodyMap);

    await LoggerService().info('initiatePayment: request', meta: {
      'uri': uri.toString(),
      'body': bodyMap,
      'userId': user.uid,
    });

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: body,
    );

    await LoggerService().info('initiatePayment: response', meta: {
      'status': resp.statusCode,
      'body': resp.body,
    });

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      await LoggerService().error('Payment initiate failed',
          meta: {'status': resp.statusCode, 'body': resp.body});
      throw Exception(
          'Payment initiate failed: ${resp.statusCode} ${resp.body}');
    }

    final Map<String, dynamic> json = jsonDecode(resp.body);
    // Validate expected fields strictly. Backend must return:
    // - 'signature' (string)
    // - 'transactionUuid' (string)
    // - 'paymentParams' (object) containing: amount, totalAmount, successUrl, failureUrl, productCode, transactionUuid
    final List<String> missing = [];

    if (json['signature'] == null || (json['signature'] is! String))
      missing.add('signature');
    if (json['transactionUuid'] == null || (json['transactionUuid'] is! String))
      missing.add('transactionUuid');

    final paymentParams = json['paymentParams'];
    if (paymentParams == null || paymentParams is! Map<String, dynamic>) {
      missing.add('paymentParams');
    } else {
      final requiredPm = [
        'amount',
        'totalAmount',
        'successUrl',
        'failureUrl',
        'productCode',
        'transactionUuid'
      ];
      for (final k in requiredPm) {
        if (!paymentParams.containsKey(k) || paymentParams[k] == null)
          missing.add('paymentParams.$k');
      }
    }

    if (missing.isNotEmpty) {
      await LoggerService().error('Payment initiate missing fields', meta: {
        'missing': missing,
        'response': json,
      });
      throw Exception(
          'Payment initiation response missing required fields: ${missing.join(', ')}');
    }

    // Return the parsed response as-is; caller must use the provided transactionUuid, signature and paymentParams.
    return json;
  }

  /// Calls backend `/api/payment/compute-amount` to compute required payment
  /// for the given venue/date/time/slots. Backend returns an object with
  /// `computed` (and other metadata). We return the parsed JSON as-is.
  Future<Map<String, dynamic>> computeAmount({
    required String venueId,
    required String date,
    required String startTime,
    int slots = 1,
    Map<String, dynamic>? booking,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final uri =
        Uri.parse('${AppConfig.backendBaseUrl}/api/payment/compute-amount');

    final bodyMap = {
      'venueId': venueId,
      'date': date,
      'startTime': startTime,
      'slots': slots,
      if (booking != null) 'booking': booking,
    };

    await LoggerService().info('computeAmount: request', meta: {
      'uri': uri.toString(),
      'body': bodyMap,
      'userId': user.uid,
    });

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(bodyMap),
    );

    await LoggerService().info('computeAmount: response', meta: {
      'status': resp.statusCode,
      'body': resp.body,
    });

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      await LoggerService().error('Compute amount failed',
          meta: {'status': resp.statusCode, 'body': resp.body});
      throw Exception('Compute amount failed: ${resp.statusCode} ${resp.body}');
    }

    final Map<String, dynamic> json = jsonDecode(resp.body);
    return json;
  }

  /// Helper to extract a numeric paid amount from compute response.
  /// Tries several common keys and converts strings to double when needed.
  double extractPaidAmountFromCompute(Map<String, dynamic> computeResp) {
    dynamic candidate;

    // If backend returned a `computed` object, handle common shapes
    if (computeResp.containsKey('computed')) {
      candidate = computeResp['computed'];

      // If computed is a map, try several likely keys in order of priority
      if (candidate is Map<String, dynamic>) {
        if (candidate.containsKey('paidAmount')) {
          candidate = candidate['paidAmount'];
        } else if (candidate.containsKey('advanceAmount')) {
          candidate = candidate['advanceAmount'];
        } else if (candidate.containsKey('totalAmount')) {
          candidate = candidate['totalAmount'];
        } else if (candidate.containsKey('amount')) {
          candidate = candidate['amount'];
        }
      }
    }

    // Fallback to top-level keys if nothing found inside computed
    candidate ??= computeResp['paidAmount'] ??
        computeResp['advanceAmount'] ??
        computeResp['amount'] ??
        computeResp['totalAmount'];

    if (candidate == null) {
      throw Exception('Unable to extract paid amount from compute response');
    }

    if (candidate is num) return candidate.toDouble();
    if (candidate is String) return double.parse(candidate);

    throw Exception('Unsupported paid amount type: ${candidate.runtimeType}');
  }

  /// Sends eSewa response data to backend `/api/payment/verify` for server-side verification.
  /// Expects backend to return JSON indicating verification status and any updated booking info.
  Future<Map<String, dynamic>> verifyPayment({
    required String transactionUuid,
    required String responseData,
    required String productCode,
    required double totalAmount,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/payment/verify');
    final bodyMap = {
      'transactionUuid': transactionUuid,
      'responseData': responseData,
      'productCode': productCode,
      'totalAmount': totalAmount,
    };
    final body = jsonEncode(bodyMap);

    await LoggerService().info('verifyPayment: request', meta: {
      'uri': uri.toString(),
      'body': bodyMap,
      'userId': user.uid,
    });

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: body,
    );

    await LoggerService().info('verifyPayment: response', meta: {
      'status': resp.statusCode,
      'body': resp.body,
    });

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      await LoggerService().error('Payment verify failed',
          meta: {'status': resp.statusCode, 'body': resp.body});
      throw Exception('Payment verify failed: ${resp.statusCode} ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
