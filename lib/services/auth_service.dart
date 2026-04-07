import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Secure storage key prefix for PIN hashes
  static const String _pinKeyPrefix = 'user_pin_hash_';

  /// Get current authenticated user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Sign up with email and password
  Future<User?> signUp(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password cannot be empty');
      }

      if (!_isValidEmail(email)) {
        throw Exception('Invalid email format');
      }

      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password cannot be empty');
      }

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Hash PIN using SHA-256
  String hashPin(String pin) {
    try {
      if (pin.isEmpty || pin.length < 4) {
        throw Exception('PIN must be 4 digits');
      }

      if (!RegExp(r'^\d+$').hasMatch(pin)) {
        throw Exception('PIN must contain only digits');
      }

      return sha256.convert(utf8.encode(pin)).toString();
    } catch (e) {
      throw Exception('PIN hashing failed: ${e.toString()}');
    }
  }

  /// Set up PIN for user — hashes the PIN and stores it in secure storage
  Future<void> setupPin(String uid, String pin) async {
    try {
      final hashedPin = hashPin(pin);
      await _secureStorage.write(
        key: '$_pinKeyPrefix$uid',
        value: hashedPin,
      );
    } catch (e) {
      throw Exception('PIN setup failed: ${e.toString()}');
    }
  }

  /// Verify PIN for user — retrieves stored hash from secure storage and compares
  Future<bool> verifyPin(String uid, String pin) async {
    try {
      final storedHash = await _secureStorage.read(
        key: '$_pinKeyPrefix$uid',
      );

      if (storedHash == null || storedHash.isEmpty) {
        return false;
      }

      if (pin.isEmpty || !RegExp(r'^\d+$').hasMatch(pin)) {
        return false;
      }

      final inputHash = sha256.convert(utf8.encode(pin)).toString();
      return inputHash == storedHash;
    } catch (e) {
      return false;
    }
  }

  /// Verify PIN against stored hash (synchronous, for direct hash comparison)
  bool verifyPinHash(String inputPin, String storedHash) {
    try {
      if (inputPin.isEmpty || storedHash.isEmpty) {
        return false;
      }

      if (!RegExp(r'^\d+$').hasMatch(inputPin)) {
        return false;
      }

      final inputHash = sha256.convert(utf8.encode(inputPin)).toString();
      return inputHash == storedHash;
    } catch (e) {
      return false;
    }
  }

  /// Authenticate using biometric (fingerprint/face)
  Future<bool> authenticateWithBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        throw Exception('Biometric authentication not available on this device');
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access ParentShield',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return isAuthenticated;
    } on Exception catch (e) {
      throw Exception('Biometric authentication failed: ${e.toString()}');
    } catch (e) {
      throw Exception('Biometric authentication error: ${e.toString()}');
    }
  }

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics ||
          await _localAuth.isDeviceSupported();

      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Handle Firebase Auth exceptions
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return Exception('Password is too weak. Use a stronger password.');
      case 'email-already-in-use':
        return Exception('Email is already registered. Try signing in instead.');
      case 'invalid-email':
        return Exception('Invalid email format.');
      case 'user-disabled':
        return Exception('This account has been disabled.');
      case 'user-not-found':
        return Exception('Email not found. Please sign up first.');
      case 'wrong-password':
        return Exception('Incorrect password. Please try again.');
      case 'network-request-failed':
        return Exception('Network error. Check your internet connection.');
      case 'too-many-requests':
        return Exception('Too many login attempts. Please try again later.');
      default:
        return Exception('Authentication error: ${e.message}');
    }
  }
}
