import 'package:flutter/widgets.dart';

const String kCountryCode = '+91'; // change if you support other countries

class RegisterValidators {
  static String? name(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Please enter your full name';
    if (t.length < 2) return 'Name is too short';
    return null;
  }

  static String? phone(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Please enter your phone number';
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(t)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? otp(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Please enter the OTP';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(t)) return 'OTP must be 6 digits';
    return null;
  }

  static String? Function(String?) confirmPassword(TextEditingController password) =>
      (v) {
        if (v == null || v.isEmpty) return 'Please confirm your password';
        if (v != password.text) return 'Passwords do not match';
        return null;
      };

  static String fullPhone(String digits) => '$kCountryCode${digits.trim()}';
}