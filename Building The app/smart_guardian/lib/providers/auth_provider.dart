import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../services/phone_otp_service.dart';

class AuthProvider extends ChangeNotifier {
  UserRole _selectedRole = UserRole.patient;
  bool _isLoading = false;
  String? _errorMessage;

  UserRole get selectedRole => _selectedRole;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setRole(UserRole role) {
    _selectedRole = role;
    notifyListeners();
  }

  Future<bool> login({
  required String email,
  required String password,
}) async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'Please enter both email and password';
      return false;
    }

    // 1. Login using Firebase Authentication
    final credential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      _errorMessage = 'Login failed. Please try again.';
      return false;
    }

    // 2. Get this user's profile from Firestore
    final profileDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    // 3. Make sure the profile exists
    if (!profileDoc.exists) {
      await FirebaseAuth.instance.signOut();

      _errorMessage =
          'User profile not found. Please contact the administrator.';
      return false;
    }

    // 4. Read the role stored in Firestore
    final data = profileDoc.data();

    final role = data?['role'];

    if (role != 'patient' && role != 'guardian') {
      await FirebaseAuth.instance.signOut();

      _errorMessage = 'Invalid user role. Please contact the administrator.';
      return false;
    }

    // 5. Convert Firestore role to our UserRole enum
    final userRole =
        role == 'patient' ? UserRole.patient : UserRole.guardian;

    // 6. Check whether the selected login role matches the real role
    if (userRole != _selectedRole) {
      await FirebaseAuth.instance.signOut();

      _errorMessage =
          'This account is registered as ${userRole.label}. '
          'Please select ${userRole.label} and try again.';

      return false;
    }

    // 7. Login successful
    _selectedRole = userRole;

    return true;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found' ||
        e.code == 'invalid-credential') {
      _errorMessage = 'Invalid email or password';
    } else if (e.code == 'wrong-password') {
      _errorMessage = 'Invalid password';
    } else if (e.code == 'invalid-email') {
      _errorMessage = 'Invalid email address';
    } else if (e.code == 'user-disabled') {
      _errorMessage = 'This account has been disabled';
    } else {
      _errorMessage = e.message ?? 'Login failed';
    }

    return false;
  } on FirebaseException catch (e) {
    _errorMessage =
        'Could not read your user profile. Please try again.';
    debugPrint('Firestore error: ${e.code} ${e.message}');
    return false;
  } catch (e) {
    debugPrint('Login error: $e');
    _errorMessage = 'Something went wrong. Please try again.';
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
    // ===================== CREATE ACCOUNT (Firebase SMS OTP) =====================
  final PhoneOtpService _otpService = FirebasePhoneOtpService();
  String? _pendingPhone;
  bool _registrationNeedsRestart = false;

  /// True when the OTP was used up and the user must go back to the form.
  bool get registrationNeedsRestart => _registrationNeedsRestart;

  /// Step 1: send the SMS. Also used for "Resend OTP".
  Future<bool> sendRegistrationOtp(String phoneE164) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _otpService.sendOtp(phoneE164);
      _pendingPhone = phoneE164;
      return true;
     } on FirebaseAuthException catch (e) {
    debugPrint('===== FIREBASE PHONE AUTH ERROR =====');
    debugPrint('Code: ${e.code}');
    debugPrint('Message: ${e.message}');
    debugPrint('======================================');

    _errorMessage = '${e.code}: ${e.message}';
    return false;
}catch (_) {
      _errorMessage = 'Could not send the OTP. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Step 2: verify OTP -> attach email+password -> create Firestore profile.
  Future<bool> verifyOtpAndCreateAccount({
    required String name,
    required String email,
    required String password,
    required String smsCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _registrationNeedsRestart = false;
    notifyListeners();

    User? phoneUser;
    try {
      final cred = await _otpService.verifyOtp(smsCode);
      phoneUser = cred.user;
      if (phoneUser == null) {
        _errorMessage = 'Verification failed. Please try again.';
        return false;
      }

      // Phone belongs to a complete existing account? Don't log into it.
      final hasPassword =
          phoneUser.providerData.any((p) => p.providerId == 'password');
      if (cred.additionalUserInfo?.isNewUser == false && hasPassword) {
        await FirebaseAuth.instance.signOut();
        _errorMessage =
            'This phone number is already registered. Please log in instead.';
        _registrationNeedsRestart = true;
        return false;
      }

      // Attach email + password (stored by Firebase Auth only).
      await phoneUser.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await phoneUser.updateDisplayName(name);

      // Profile document: users/{uid}
      final profile = UserProfile(
        uid: phoneUser.uid,
        name: name,
        email: email,
        phoneNumber: phoneUser.phoneNumber ?? _pendingPhone ?? '',
        role: _selectedRole.name,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(phoneUser.uid)
          .set(profile.toMap());

      _pendingPhone = null;
      return true; // user stays signed in; Wrapper shows the right dashboard
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyAuthError(e);
      if (phoneUser != null) {
        await _rollback(phoneUser);
        _registrationNeedsRestart = true;
      }
      return false;
    } on FirebaseException catch (e) {
      // Firestore error
      _errorMessage = e.code == 'permission-denied'
          ? 'Could not save your profile (check Firestore rules).'
          : 'Could not save your profile. Please try again.';
      await _rollback(phoneUser);
      _registrationNeedsRestart = true;
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      await _rollback(phoneUser);
      _registrationNeedsRestart = phoneUser != null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Removes the half-created phone-only user so the number can be reused.
  Future<void> _rollback(User? user) async {
    try {
      await user?.delete();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  // ===================== FORGOT PASSWORD =====================
  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyAuthError(e);
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check the code and try again.';
      case 'session-expired':
      case 'code-expired':
        return 'This OTP has expired. Please request a new one.';
      case 'invalid-phone-number':
        return 'Enter a valid phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while and try again.';
      case 'quota-exceeded':
        return 'SMS limit reached. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'This email is already registered. Go back and use another email, or log in.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Use a stronger password.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in the Firebase Console.';
      case 'captcha-check-failed':
      case 'app-not-authorized':
      case 'missing-client-identifier':
      case 'invalid-app-credential':
        return 'Phone verification is not set up for this app (check SHA fingerprints in Firebase).';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
   // Logout
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}

      // TODO: replace this with a real call to your FastAPI backend, e.g.
      // final response = await http.post(
      //   Uri.parse('http://<your-backend-ip>:8000/login'),
      //   body: {
      //     'email': email,
      //     'password': password,
      //     'role': _selectedRole.name,
      //   },
      // );
      // if (response.statusCode != 200) {
      //   _errorMessage = 'Invalid email or password';
      //   return false;
      // }

  