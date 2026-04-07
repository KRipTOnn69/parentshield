import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:parentshield/models/user_model.dart';
import 'package:parentshield/services/auth_service.dart';
import 'package:parentshield/services/firestore_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  StreamSubscription<User?>? _authSubscription;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _isPinVerified = false;
  bool _hasPinSet = false;

  AuthProvider()
      : _authService = AuthService(),
        _firestoreService = FirestoreService() {
    _safeInitializeAuth();
    _listenToAuthChanges();
  }

  // Getters
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isPinVerified => _isPinVerified;
  bool get hasPinSet => _hasPinSet;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> _safeInitializeAuth() async {
    try {
      await _initializeAuth();
    } catch (e) {
      debugPrint('Auth initialization failed: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _initializeAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        _user = await _firestoreService.getUser(currentUser.uid);
        _hasPinSet = _user?.hasPinSet ?? false;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize authentication';
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.signIn(email, password);
      if (firebaseUser == null) {
        _errorMessage = 'Sign in failed. Please try again.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      _user = await _firestoreService.getUser(firebaseUser.uid);
      _hasPinSet = _user?.hasPinSet ?? false;
      _isPinVerified = false;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during sign in';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.signUp(email, password);
      if (firebaseUser == null) {
        _errorMessage = 'Sign up failed. Please try again.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      final newUser = UserModel(
        uid: firebaseUser.uid,
        name: name,
        email: email,
        createdAt: DateTime.now(),
        hasPinSet: false,
      );

      try {
        await _firestoreService.createUser(newUser);
      } catch (e) {
        debugPrint('Firestore createUser failed (continuing): $e');
        // Continue even if Firestore write fails - user is already created in Firebase Auth
      }

      _user = newUser;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Sign up error: $e');
      _errorMessage = 'Sign up error: ${e.toString()}';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
      _isPinVerified = false;
      _hasPinSet = false;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to sign out';
    }

    notifyListeners();
  }

  Future<bool> setPIN(String pin) async {
    if (_user == null) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return false;
    }

    if (pin.length != 4 || !RegExp(r'^\d+$').hasMatch(pin)) {
      _errorMessage = 'PIN must be 4 digits';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final hashedPin = _authService.hashPin(pin);
      await _firestoreService.updateUser(_user!.uid, {
        'hashedPin': hashedPin,
        'hasPinSet': true,
      });
      _hasPinSet = true;
      _isPinVerified = true;
      _user = _user!.copyWith(hashedPin: hashedPin, hasPinSet: true);
      _errorMessage = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to set up PIN. Please try again.';
      _status = AuthStatus.authenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPIN(String pin) async {
    if (_user == null) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Refresh user to get latest hashedPin
      final freshUser = await _firestoreService.getUser(_user!.uid);
      final storedHash = freshUser?.hashedPin ?? _user!.hashedPin ?? '';

      final isValid = _authService.verifyPinHash(pin, storedHash);
      if (isValid) {
        _isPinVerified = true;
        _errorMessage = null;
      } else {
        _errorMessage = 'Incorrect PIN. Please try again.';
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return isValid;
    } catch (e) {
      _errorMessage = 'Failed to verify PIN. Please try again.';
      _status = AuthStatus.authenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    if (_user == null) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.authenticateWithBiometric();
      if (success) {
        _isPinVerified = true;
        _errorMessage = null;
      } else {
        _errorMessage = 'Biometric authentication failed';
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Biometric authentication not available';
      _status = AuthStatus.authenticated;
      notifyListeners();
      return false;
    }
  }

  void _listenToAuthChanges() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        if (_status != AuthStatus.loading) {
          _user = null;
          _isPinVerified = false;
          _hasPinSet = false;
          _status = AuthStatus.unauthenticated;
          notifyListeners();
        }
      } else if (_user == null && _status != AuthStatus.loading) {
        // User signed in externally or session restored
        try {
          _user = await _firestoreService.getUser(firebaseUser.uid);
          _hasPinSet = _user?.hasPinSet ?? false;
          _status = AuthStatus.authenticated;
          notifyListeners();
        } catch (e) {
          debugPrint('Auth state change - failed to load user: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({required this.code, required this.message});

  @override
  String toString() => message;
}
