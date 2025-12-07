import 'dart:typed_data';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'logger_service.dart';

class InvoiceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetch invoice PDF bytes for given booking id. Returns raw bytes.
  Future<Uint8List> fetchInvoiceBytes(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/invoices/$bookingId');

    await LoggerService().info('fetchInvoice: request', meta: {
      'uri': uri.toString(),
      'userId': user.uid,
    });

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    await LoggerService().info('fetchInvoice: response', meta: {
      'status': resp.statusCode,
      'body': resp.headers['content-type'] ?? 'no-ct',
    });

    if (resp.statusCode != 200) {
      String msg = resp.body;
      try {
        final parsed = jsonDecode(resp.body);
        if (parsed is Map && parsed['error'] != null) msg = parsed['error'].toString();
      } catch (_) {}
      throw Exception('Failed to download invoice: ${resp.statusCode} $msg');
    }

    return resp.bodyBytes;
  }
}
