import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uploadthing/uploadthing.dart';
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

class VenueDebugException implements Exception {
  final String title;
  final String url;
  final String requestBody;
  final int statusCode;
  final String responseBody;

  const VenueDebugException({
    required this.title,
    required this.url,
    required this.requestBody,
    required this.statusCode,
    required this.responseBody,
  });

  @override
  String toString() => '$title (HTTP $statusCode)';
}

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

  /// Returns the slot document ID from the `slots` collection for a given
  /// venue/date/startTime combination. Returns null if not found or on error.
  Future<String?> getSlotId(
      String venueId, String date, String startTime) async {
    try {
      final snapshot = await _firestore
          .collection('slots')
          .where('venueId', isEqualTo: venueId)
          .where('date', isEqualTo: date)
          .where('startTime', isEqualTo: startTime)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (_) {
      return null;
    }
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

    // Whitelisted fields: name, description, pricePerHour, advancePercentage, platformCommission, imageUrls, attributes, address, latitude, longitude, sportType
    final body = venue.toMap();
    final url = '$baseUrl/venues/${venue.id}';
    final requestBodyJson = jsonEncode(body);

    http.Response response;
    try {
      response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBodyJson,
      );
    } catch (networkError) {
      throw VenueDebugException(
        title: 'Network Error',
        url: url,
        requestBody: requestBodyJson,
        statusCode: 0,
        responseBody: networkError.toString(),
      );
    }

    if (response.statusCode != 200) {
      throw VenueDebugException(
        title: 'Server Rejected Update',
        url: url,
        requestBody: requestBodyJson,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<String> uploadVenueImage(File file, String venueId) async {
    const apiKey = String.fromEnvironment(
      'UPLOADTHING_SECRET'    );

    final ut = UploadThing(apiKey);
    final renamed = File(file.path.replaceAll(
      RegExp(r'[^/]+$'),
      'venue_${venueId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    ));
    await renamed.writeAsBytes(await file.readAsBytes());

    final success = await ut.uploadFiles([renamed]);
    if (!success || ut.uploadedFilesData.isEmpty) {
      throw Exception('UploadThing upload failed');
    }

    final fileData = ut.uploadedFilesData.first;
    final url = fileData['ufsUrl'] ?? fileData['url'] ?? '';
    if (url.isEmpty) throw Exception('UploadThing returned no URL');
    return url;
  }
}
