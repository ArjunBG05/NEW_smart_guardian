import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';

/// Anything that can send and check a phone OTP.
/// Today: Firebase SMS. Later you can add a WhatsApp implementation
/// of this same interface (that one will need a backend).
abstract class PhoneOtpService {
  Future<void> sendOtp(String phoneE164);
  Future<UserCredential> verifyOtp(String code);
}

class FirebasePhoneOtpService implements PhoneOtpService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;
  PhoneAuthCredential? _autoCredential; // set when Android auto-reads the SMS

  @override
 @override
Future<void> sendOtp(String phoneE164) {
  final completer = Completer<void>();
  _autoCredential = null;

  debugPrint('📱 Starting Firebase Phone Auth');
  debugPrint('📱 Phone: $phoneE164');

  _auth.verifyPhoneNumber(
    phoneNumber: phoneE164,
    timeout: const Duration(seconds: 60),

    forceResendingToken: _resendToken,

    verificationCompleted: (credential) {
      debugPrint('✅ Firebase verification completed automatically');

      _autoCredential = credential;

      if (!completer.isCompleted) {
        completer.complete();
      }
    },

    verificationFailed: (e) {
      debugPrint('❌ Firebase Phone Auth failed');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');

      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    },

    codeSent: (id, token) {
      debugPrint('✅ OTP code sent');
      debugPrint('Verification ID received');

      _verificationId = id;
      _resendToken = token;

      if (!completer.isCompleted) {
        completer.complete();
      }
    },

    codeAutoRetrievalTimeout: (id) {
      debugPrint('⏰ OTP auto-retrieval timeout');
      _verificationId = id;
    },
  );

  return completer.future;
}
  @override
  Future<UserCredential> verifyOtp(String code) async {
    final credential = _autoCredential ??
        PhoneAuthProvider.credential(
          verificationId: _verificationId ?? '',
          smsCode: code,
        );
    try {
      return await _auth.signInWithCredential(credential);
    } catch (_) {
      _autoCredential = null; // don't reuse a failed auto credential
      rethrow;
    }
  }
}