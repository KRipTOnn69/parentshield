import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:parentshield/config/constants.dart';

/// Shows a PIN verification dialog that checks against the parent's hashed PIN.
/// Returns true if PIN was verified successfully, false otherwise.
Future<bool> showPinVerificationDialog(BuildContext context, String parentId) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PinVerificationDialog(parentId: parentId),
  );
  return result ?? false;
}

class _PinVerificationDialog extends StatefulWidget {
  final String parentId;

  const _PinVerificationDialog({required this.parentId});

  @override
  State<_PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<_PinVerificationDialog> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String? _error;
  int _attempts = 0;
  bool _isLocked = false;
  bool _isVerifying = false;
  String? _parentHashedPin;

  @override
  void initState() {
    super.initState();
    _loadParentPin();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _loadParentPin() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.parentId)
          .get();

      if (doc.exists && doc.data() != null) {
        _parentHashedPin = doc.data()!['hashedPin'] as String?;
      }
    } catch (e) {
      debugPrint('[ParentShield] Failed to load parent PIN: $e');
    }
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  String _getEnteredPin() {
    return _controllers.map((c) => c.text).join();
  }

  void _onDigitChanged(String value, int index) {
    if (value.length == 1) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyPin();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyPin() async {
    final pin = _getEnteredPin();
    if (pin.length != 4) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    // If we haven't loaded the parent PIN yet, try again
    if (_parentHashedPin == null) {
      await _loadParentPin();
    }

    if (_parentHashedPin == null || _parentHashedPin!.isEmpty) {
      // No PIN set — allow exit (shouldn't happen normally)
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final inputHash = _hashPin(pin);
    final isCorrect = inputHash == _parentHashedPin;

    if (isCorrect) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _attempts++;
      if (_attempts >= 3) {
        setState(() {
          _isLocked = true;
          _isVerifying = false;
          _error = 'Too many attempts. Locked for 60 seconds.';
        });
        _clearPinBoxes();
        await Future.delayed(const Duration(seconds: 60));
        if (mounted) {
          setState(() {
            _isLocked = false;
            _attempts = 0;
            _error = null;
          });
        }
      } else {
        setState(() {
          _isVerifying = false;
          _error = 'Wrong PIN. ${3 - _attempts} attempts remaining.';
        });
        _clearPinBoxes();
      }
    }
  }

  void _clearPinBoxes() {
    for (var c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.lock, color: AppColors.teal, size: 24),
          const SizedBox(width: 8),
          Text(
            'Parent PIN Required',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.darkText,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter your parent\'s 4-digit PIN to exit child mode.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.midGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) => SizedBox(
              width: 50,
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                obscureText: true,
                enabled: !_isLocked && !_isVerifying,
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.teal.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.teal.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (value) => _onDigitChanged(value, index),
              ),
            )),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
          if (_isVerifying) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLocked ? null : () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyle(color: AppColors.midGray)),
        ),
      ],
    );
  }
}
