import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../domain/venue.dart';
import '../domain/review.dart';
import '../domain/venue_slot.dart';
import '../../../core/config.dart';

final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  return VenueRepository(FirebaseFirestore.instance);
});

final venuesProvider = StreamProvider<List<Venue>>((ref) {
  return ref.watch(venueRepositoryProvider).getVenues();
});

final venueProvider = StreamProvider.family<Venue?, String>((ref, id) {
  return ref.watch(venueRepositoryProvider).getVenue(id);
});

final venueSlotsProvider =
    StreamProvider.family<VenueSlotData?, String>((ref, venueId) {
  return ref.watch(venueRepositoryProvider).getVenueSlots(venueId);
});

final venueReviewsProvider =
    StreamProvider.family<List<Review>, String>((ref, venueId) {
  return ref.watch(venueRepositoryProvider).getReviews(venueId);
});

class VenueRepository {
  final FirebaseFirestore _firestore;

  VenueRepository(this._firestore);

  Stream<List<Venue>> getVenues() {
    return _firestore.collection('venues').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Venue.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Stream<Venue?> getVenue(String id) {
    return _firestore.collection('venues').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Venue.fromMap(doc.data()!, doc.id);
    });
  }

  Stream<List<Review>> getReviews(String venueId) {
    return _firestore
        .collection('venues')
        .doc(venueId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Review.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Stream<VenueSlotData?> getVenueSlots(String venueId) {
    return _firestore
        .collection('venueSlots')
        .doc(venueId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return VenueSlotData.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> addReview({
    required String venueId,
    required double rating,
    required String comment,
    String? bookingId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/venues/$venueId/reviews'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'rating': rating,
        'comment': comment,
        if (bookingId != null) 'bookingId': bookingId,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to submit review');
    }
  }

  Future<void> holdSlot(String venueId, HeldSlot heldSlot) async {
    final docRef = _firestore.collection('venueSlots').doc(venueId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception("Venue slots not found");
      }

      final data = VenueSlotData.fromMap(snapshot.data()!, snapshot.id);

      // Check if slot is already booked or blocked
      bool isBooked = data.bookings.any((b) =>
          b.date == heldSlot.date &&
          b.startTime == heldSlot.startTime &&
          b.status != 'cancelled');

      bool isBlocked = data.blocked.any(
          (b) => b.date == heldSlot.date && b.startTime == heldSlot.startTime);

      bool isHeld = data.held.any((h) =>
          h.date == heldSlot.date &&
          h.startTime == heldSlot.startTime &&
          h.holdExpiresAt.toDate().isAfter(DateTime.now()));

      if (isBooked || isBlocked || isHeld) {
        throw Exception("Slot is no longer available");
      }

      List<HeldSlot> currentHeld = List.from(data.held);
      // Remove expired holds for this slot if any (though isHeld check handles valid ones)
      currentHeld.removeWhere(
          (h) => h.date == heldSlot.date && h.startTime == heldSlot.startTime);

      currentHeld.add(heldSlot);

      transaction.update(docRef, {
        'held': currentHeld
            .map((e) => {
                  'date': e.date,
                  'startTime': e.startTime,
                  'userId': e.userId,
                  'holdExpiresAt': e.holdExpiresAt,
                  'bookingId': e.bookingId,
                  'createdAt': e.createdAt,
                })
            .toList(),
      });
    });
  }

  Future<void> updateVenue(Venue venue) async {
    // Use backend API instead of direct Firestore write
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();
    final baseUrl = AppConfig.apiUrl;

    // Include venue ID in the body for updates
    final body = {
      'id': venue.id, // Important: Include ID for updates
      ...venue.toMap(),
    };

    print('Sending venue update: $body'); // Debug log

    final response = await http.post(
      Uri.parse('$baseUrl/venues'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    print('Response: ${response.statusCode} - ${response.body}'); // Debug log

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to update venue: ${response.body}');
    }
  }

  Future<String> uploadVenueImage(File file, String venueId) async {
    // Use backend upload API instead of direct Firebase Storage
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();
    final baseUrl = AppConfig.apiUrl;

    // Create multipart request
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: 'venue_${venueId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['url'] as String;
    } else {
      throw Exception('Failed to upload image: ${response.body}');
    }
  }
}
