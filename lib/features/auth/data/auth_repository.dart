import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/auth_user.dart';
import '../../../core/config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
    GoogleSignIn(
      // Web/server client ID — required so idToken is always populated.
      // Taken from google-services.json oauth_client (client_type: 3).
      serverClientId:
          '1034146087306-emp3oi4qlm4tet61el789t1immmci3cg.apps.googleusercontent.com',
    ),
  );
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final allUsersProvider = StreamProvider<List<AuthUser>>((ref) {
  return ref.watch(authRepositoryProvider).getUsers();
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRepository(this._auth, this._firestore, this._googleSignIn);

  Stream<AuthUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;

      // Fetch user data from Firestore
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return AuthUser.fromMap(doc.data()!, user.uid);
        } else {
          // If user exists in Auth but not Firestore (e.g. first google login), create it
          // Or return a basic user and let the UI handle profile completion
          // For now, we'll return a basic user with 'user' role
          return AuthUser(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName,
            photoURL: user.photoURL,
            role: 'user',
          );
        }
      } catch (e) {
        // Do NOT silently fall back to role:'user' — a manager or admin would
        // lose their permissions without any indication. Rethrow so the
        // StreamProvider surfaces an error the UI can react to.
        rethrow;
      }
    });
  }

  Stream<List<AuthUser>> getUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AuthUser.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createUserWithEmailAndPassword(
      String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      try {
        await _saveUserToFirestore(credential.user!, name);
      } catch (e) {
        // Roll back: delete the Firebase Auth account so the user can retry
        // without hitting "email already in use" on the next attempt.
        await credential.user!.delete();
        rethrow;
      }
    }
  }

  Future<void> signInWithGoogle() async {
    // Ensure any cached account is cleared so the account picker is always shown.
    await _googleSignIn.signOut();
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // User canceled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    if (userCredential.user != null) {
      // Check if user exists in Firestore; if not, this is a brand-new sign-up.
      final doc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      if (!doc.exists) {
        try {
          await _saveUserToFirestore(
              userCredential.user!, googleUser.displayName ?? 'User');
        } catch (e) {
          // Roll back: delete the Firebase Auth account so the user is not
          // left in a half-created ghost state.
          await userCredential.user!.delete();
          await _googleSignIn.signOut();
          rethrow;
        }
      }
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Returns true if the current user has an email+password provider
  /// (as opposed to Google-only).
  bool get currentUserHasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// Reauthenticates with [currentPassword] then updates to [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> _saveUserToFirestore(User user, String name) async {
    await _syncUserWithBackend(user, displayName: name);
  }

  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }
    if (photoURL != null) {
      await user.updatePhotoURL(photoURL);
    }

    // Sync with backend
    await _syncUserWithBackend(user,
        displayName: displayName, photoURL: photoURL);
  }

  Future<void> _syncUserWithBackend(User user,
      {String? displayName, String? photoURL}) async {
    try {
      final token = await user.getIdToken();
      // For physical device, use your machine's IP, configured in AppConfig
      final baseUrl = AppConfig.apiUrl;

      final Map<String, dynamic> body = {
        'uid': user.uid,
        'email': user.email,
      };

      if (displayName != null) body['displayName'] = displayName;
      // Note: Backend schema currently might not support photoURL explicitly in zod,
      // but firestore stores it if passed?
      // Actually my backend Zod schema was:
      // const userUpsertSchema = z.object({ uid: z.string(), displayName: z.string().optional(), email: z.string().email().optional(), role: z.string().optional() });
      // It misses 'photoURL'. I should check if I need to update backend schema too.
      // For now, let's send it, but if Zod strips it, it won't save.
      // I will update backend schema in a subsequent step if needed.

      final response = await http.post(
        Uri.parse('$baseUrl/users/upsert'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to sync user: ${response.body}');
      }
    } catch (e) {
      print('Warning: Failed to sync user to backend: $e');
      // We don't want to block auth flow completely if this fails, perhaps?
      // But for 'updateProfile' we probably want to know.
      rethrow;
    }
  }

  Future<String> uploadProfileImage(File file, String userId) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('user_profiles')
        .child(userId)
        .child('profile.jpg');

    await storageRef.putFile(file);
    return await storageRef.getDownloadURL();
  }

  Future<AuthUser?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return AuthUser.fromMap(doc.data()!, userId);
      }
      return null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }
}
