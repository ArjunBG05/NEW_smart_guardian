import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final String role; // 'patient' or 'guardian'

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
  });

  /// Never contains the password.
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };
}