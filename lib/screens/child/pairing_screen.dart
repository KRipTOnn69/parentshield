import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/providers/child_provider.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({Key? key}) : super(key: key);

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late List<TextEditingController> _codeControllers;
  late List<FocusNode> _focusNodes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _codeControllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getEnteredCode() {
    return _codeControllers.map((c) => c.text).join();
  }

  void _onCodeBoxChanged(String value, int index) {
    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _handleVerifyCode();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerifyCode() async {
    final code = _getEnteredCode();
    debugPrint('[ParentShield] Pairing code entered: "$code" (length: ${code.length})');
    if (code.length != 6) return;

    setState(() => _isLoading = true);

    final childProvider = context.read<ChildProvider>();
    final success = await childProvider.verifyPairingCode(code);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/child/status',
        (route) => false,
      );
    } else {
      _clearCodeBoxes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(childProvider.errorMessage ?? 'Invalid pairing code'),
          backgroundColor: AppColors.orange,
        ),
      );
    }
  }

  void _clearCodeBoxes() {
    for (var controller in _codeControllers) {
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Pair Device',
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
                    Icons.devices,
                    size: 64,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  'Enter Pairing Code',
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  'Ask your parent for a 6-character pairing code to connect your device to ParentShield',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.midGray,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Code Input Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 50,
                      child: TextFormField(
                        controller: _codeControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.text,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        enabled: !_isLoading,
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
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.midGray.withOpacity(0.2),
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: AppTextStyles.headingMedium.copyWith(
                          color: AppColors.darkText,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                        onChanged: (value) =>
                            _onCodeBoxChanged(value, index),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Loading Indicator
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_isLoading) const SizedBox(height: 16),
                const SizedBox(height: 16),
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.teal.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'How to Pair',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. Ask your parent to open ParentShield on their device\n'
                        '2. Go to Child Management → Add Child\n'
                        '3. Share the 6-character pairing code with you\n'
                        '4. Enter the code above to complete pairing',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.darkText,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
