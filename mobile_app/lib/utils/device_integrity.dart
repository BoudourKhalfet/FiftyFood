import 'dart:io';
import 'package:flutter/foundation.dart';

class DeviceIntegrity {
  /// Returns true if the device appears to be compromised (rooted/jailbroken).
  static bool isCompromised() {
    if (kIsWeb) return false; // Web has no meaningful check
    if (Platform.isAndroid) return _isAndroidCompromised();
    if (Platform.isIOS) return _isIOSCompromised();
    return false;
  }

  /// Returns a map of individual check results for logging.
  static Map<String, bool> check() {
    if (kIsWeb) return {'web': false};
    if (Platform.isAndroid) return _androidChecks();
    if (Platform.isIOS) return _iosChecks();
    return {};
  }

  static bool _isAndroidCompromised() {
    return _androidChecks().values.any((v) => v);
  }

  static Map<String, bool> _androidChecks() {
    final checks = <String, bool>{};

    // Check for su binary in common locations
    final suPaths = [
      '/system/bin/su',
      '/system/xbin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
    ];
    checks['su_binary'] = suPaths.any((path) => File(path).existsSync());

    // Check for Magisk
    final magiskPaths = [
      '/sbin/.magisk',
      '/data/adb/magisk',
      '/data/adb/magisk.img',
    ];
    checks['magisk'] = magiskPaths.any((path) =>
        File(path).existsSync() || Directory(path).existsSync());

    // Check for common root management apps
    final rootApkPaths = [
      '/system/app/Superuser.apk',
      '/system/app/SuperSU.apk',
      '/data/app/eu.chainfire.supersu',
    ];
    checks['root_apps'] = rootApkPaths.any((path) => File(path).existsSync());

    // Check for test-keys build (non-official ROM)
    try {
      final buildPropFile = File('/system/build.prop');
      if (buildPropFile.existsSync()) {
        final content = buildPropFile.readAsStringSync();
        checks['test_keys'] = content.contains('test-keys');
      } else {
        checks['test_keys'] = false;
      }
    } catch (_) {
      checks['test_keys'] = false;
    }

    return checks;
  }

  static bool _isIOSCompromised() {
    return _iosChecks().values.any((v) => v);
  }

  static Map<String, bool> _iosChecks() {
    final checks = <String, bool>{};

    // Check for Cydia and common jailbreak paths
    final jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/usr/bin/ssh',
      '/private/var/stash',
    ];
    checks['jailbreak_paths'] = jailbreakPaths.any((path) =>
        File(path).existsSync() || Directory(path).existsSync());

    // Try writing to a location outside sandbox — jailbroken devices allow this
    try {
      final testFile = File('/private/jailbreak_test_${DateTime.now().millisecondsSinceEpoch}');
      testFile.writeAsStringSync('test');
      testFile.deleteSync();
      checks['sandbox_escape'] = true; // was able to write outside sandbox
    } catch (_) {
      checks['sandbox_escape'] = false; // expected on non-jailbroken device
    }

    return checks;
  }
}
