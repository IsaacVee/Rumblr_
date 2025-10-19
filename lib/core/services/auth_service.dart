import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rumblr/core/models/fighter_membership.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      rethrow;
    }
  }

  // Register a new user with email, password, and username
  Future<User?> register(String email, String password, String username) async {
    try {
      // Create user with email and password
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Write user data to Firestore
        await _firestore.collection('fighters').doc(user.uid).set({
          'email': email,
          'username': username,
          'displayName': username,
          'eloRatings': {'mma': 1500},
          'gymId': null,
          'membershipType': FighterMembershipType.independent.id,
          'membershipStatus': FighterMembershipStatus.pending.id,
          'membership': {
            'type': FighterMembershipType.independent.id,
            'status': FighterMembershipStatus.pending.id,
          },
          'billingState': BillingState.trialing.id,
          'role': FighterRole.fighter.id,
          'blockedUserIds': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } catch (e) {
      debugPrint('Registration failed: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
