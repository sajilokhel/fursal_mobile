import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import '../domain/manager_stats.dart';

final managerStatsProvider =
    FutureProvider.family<ManagerStats, String>((ref, managerId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not authenticated');

  final token = await user.getIdToken();
  final response = await http.get(
    Uri.parse('${AppConfig.apiUrl}/managers/$managerId/stats'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ManagerStats.fromJson(json);
  } else {
    final body = jsonDecode(response.body);
    throw Exception(body['error'] ?? 'Failed to load stats');
  }
});
