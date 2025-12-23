import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';
import 'package:flutter/services.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _statusMessage = 'Checking device capabilities...';

  @override
  void initState() {
    super.initState();
    _checkBiometricsAndAuthenticate();
  }

  // Check if device supports biometric authentication
  Future<void> _checkBiometricsAndAuthenticate() async {
    try {
      // Check if device supports biometric authentication
      final bool canAuthenticate = await _localAuth.canCheckBiometrics || 
          await _localAuth.isDeviceSupported();
      
      if (!canAuthenticate) {
        _showError('Biometric authentication not available on this device');
        return;
      }

      // Get available biometric types
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      debugPrint('Available biometrics: $availableBiometrics');
      
      if (availableBiometrics.isEmpty) {
        _showError('No biometric authentication methods enabled. Please set up biometric authentication in device settings.');
        return;
      }

      setState(() {
        _isAuthenticating = true;
      });

      // Check for face authentication first
      if (availableBiometrics.contains(BiometricType.face)) {
        await _authenticateWithBiometric('face');
      } 
      // If face auth not available, try fingerprint
      else if (availableBiometrics.any((type) => type == BiometricType.fingerprint || type == BiometricType.strong || type == BiometricType.weak)) {
        await _authenticateWithBiometric('fingerprint');
      } 
      // No supported biometrics available
      else {
        _showError('No supported biometric authentication methods found');
      }
    } on PlatformException catch (e) {
      _showError('Authentication error: ${e.message}');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  // Helper method to handle biometric authentication
  Future<void> _authenticateWithBiometric(String type) async {
    try {
      setState(() {
        _statusMessage = type == 'face' ? 'Looking for face...' : 'Scan your fingerprint...';
      });

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate with ${type == 'face' ? 'Face ID' : 'Fingerprint'} to continue',
        authMessages: [
          AndroidAuthMessages(
            signInTitle: '${type == 'face' ? 'Face' : 'Fingerprint'} Authentication',
            cancelButton: 'Cancel',
            biometricHint: 'Verify your identity',
            biometricNotRecognized: type == 'face' ? 'Face not recognized. Try again.' : 'Fingerprint not recognized. Try again.',
            biometricRequiredTitle: 'Biometric required',
            biometricSuccess: 'Authentication successful!',
            goToSettingsButton: 'Settings',
            goToSettingsDescription: 'Please set up ${type == 'face' ? 'face' : 'fingerprint'} authentication',
          ),
          const IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Settings',
            goToSettingsDescription: 'Please enable biometric authentication',
            lockOut: 'Biometric is locked. Please try again later.',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (didAuthenticate && mounted) {
        setState(() {
          _statusMessage = 'Authenticated';
        });
        Navigator.of(context).pushReplacementNamed('/login');
      } else if (!didAuthenticate && mounted) {
        _showError('${type == 'face' ? 'Face' : 'Fingerprint'} authentication failed');
      }
    } on PlatformException catch (e) {
      _showError('Authentication error: ${e.message}');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    setState(() {
      _statusMessage = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon
            const Icon(
              Icons.fingerprint,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            // Authentication status message
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Loading indicator when authenticating
            if (_isAuthenticating)
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            // Retry button in case of failure
            if (!_isAuthenticating && _statusMessage != 'Authenticating...')
              ElevatedButton.icon(
                onPressed: _checkBiometricsAndAuthenticate,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
          ],
        ),
      ),
    );
  }
}