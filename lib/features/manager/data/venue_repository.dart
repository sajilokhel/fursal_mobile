import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/venue.dart';

// For physical device, use your machine's IP. For Android emulator use 10.0.2.2
// TODO: Move to environment variable for production
const String _baseUrl = 'https://www.sajilokhel.com/api';

final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  return VenueRepository(FirebaseAuth.instance);
});

class VenueRepository {
  final FirebaseAuth _auth;

  VenueRepository(this._auth);

  Future<String> createVenue(Venue venue) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();

    final response = await http.post(
      Uri.parse('$_baseUrl/venues'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(venue.toMap()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['venueId'];
    } else {
      throw Exception('Failed to create venue: ${response.body}');
    }
  }
}
