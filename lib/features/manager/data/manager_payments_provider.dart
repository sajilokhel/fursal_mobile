import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import '../domain/manager_payment_data.dart';

final managerPaymentsProvider =
    FutureProvider.family<ManagerPaymentData, String>((ref, managerId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not authenticated');

  final token = await user.getIdToken();
  final response = await http.get(
    Uri.parse('${AppConfig.apiUrl}/manager/payments'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ManagerPaymentData.fromJson(json);
  } else {
    String msg = 'Failed to load payments (${response.statusCode})';
    try {
      final ct = response.headers['content-type'] ?? '';
      if (ct.contains('application/json')) {
        final body = jsonDecode(response.body);
        msg = body['error'] ?? msg;
      }
    } catch (_) {}
    throw Exception(msg);
  }
});
