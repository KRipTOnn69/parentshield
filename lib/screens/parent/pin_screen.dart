import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/auth_provider.dart';

class PINScreen extends StatefulWidget {
  final bool isSetup;

  const PINScreen({
    Key? key,
    this.isSetup = false,
  }) : super(key: key);

  @override
  State<PINScreen> createState() => _PINScreenState();
}

class _PINScreenState extends State<PINScreen> {
  late List<TextEditingController> _pinControllers;
  late List<FocusNode> _focusNodes;
  String _enteredPin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _pinControllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _updatePin() {
    _enteredPin = _pinControllers.map((c) => c.text).join();
  }

  void _onPinBoxChanged(String value, int index) {
    if (value.length == 1) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _updatePin();
        _handlePinEntry();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handlePinEntry() async {
    _updatePin();

    if (_enteredPin.length != 4) return;

    if (widget.isSetup) {
      if (!_isConfirming) {
        // Save the first PIN and ask for confirmation
        _firstPin = _enteredPin;
        setState(() {
          _isConfirming = true;
          _enteredPin = '';
        });
        _clearPinBoxes();
        _focusNodes[0].requestFocus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Confirm your PIN'),
              backgroundColor: AppColors.teal,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Compare confirmation PIN with the first PIN
        if (_enteredPin != _firstPin) {
          _clearPinBoxes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PINs do not match. Try again.'),
                backgroundColor: AppColors.orange,
              ),
            );
          }
          setState(() {
            _isConfirming = false;
            _enteredPin = '';
            _firstPin = '';
          });
          _focusNodes[0].requestFocus();
          return;
        }

        final authProvider = context.read<AuthProvider>();
        final success = await authProvider.setPIN(_enteredPin);

        if (!mounted) return;

        if (success) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/dashboard',
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Failed to set PIN'),
              backgroundColor: AppColors.orange,
            ),
          );
        }
      }
    } else {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.verifyPIN(_enteredPin);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false,
        );
      } else {
        _clearPinBoxes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN'),
            backgroundColor: AppColors.orange,
          ),
        );
      }
    }
  }

  void _clearPinBoxes() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isSetup
          ? null
          : AppBar(
              backgroundColor: AppColors.navy,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.white,
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Verify PIN',
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: Container(
        color: AppColors.offWhite,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock,
                    size: 64,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  widget.isSetup
                      ? 'Create Your PIN'
                      : _isConfirming
                          ? 'Confirm Your PIN'
                          : 'Enter Your PIN',
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  widget.isSetup
                      ? 'Choose a 4-digit PIN for your account'
                      : 'Enter your 4-digit PIN to unlock',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.midGray,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // PIN Input Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    4,
                    (index) => SizedBox(
                      width: 60,
                      child: TextFormField(
                        controller: _pinControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        obscureText: _obscurePin,
                        maxLength: 1,
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.teal.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.teal.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.teal,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: AppTextStyles.headingLarge.copyWith(
                          color: AppColors.darkText,
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (value) =>
                            _onPinBoxChanged(value, index),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Show/Hide PIN Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.midGray,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _obscurePin = !_obscurePin),
                      child: Text(
                        _obscurePin ? 'Show PIN' : 'Hide PIN',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                // Biometric Option
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.teal.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fingerprint,
                        color: AppColors.teal,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Biometric',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.darkText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Unlock with fingerprint or face',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.midGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.teal,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Info Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.offWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.midGray.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Your PIN is your primary security method. Keep it safe and never share it with anyone.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.midGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
