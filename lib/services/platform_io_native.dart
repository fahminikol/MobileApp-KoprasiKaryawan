import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class PlatformStorageHelper {
  static const MethodChannel _nativeChannel = MethodChannel('kopkar.bbm/native');

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static File _getDbFile() {
    final homeDir = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final iosDocsDir = Directory('$homeDir/Documents');
    if (Platform.isIOS && iosDocsDir.existsSync()) {
      return File('${iosDocsDir.path}/kopkar_pt_bbm_db_v2.json');
    }
    return File('$homeDir/.kopkar_pt_bbm_db_v2.json');
  }

  static Future<void> writeLocalState(String jsonString) async {
    // 1. Simpan ke Android EncryptedSharedPreferences (Hardware-backed AES-256 GCM)
    try {
      if (Platform.isAndroid) {
        final ok = await _nativeChannel.invokeMethod<bool>(
          'writeEncryptedPref',
          {'key': 'kopkar_master_state', 'value': jsonString},
        );
        if (ok == true) return;
      }
    } catch (_) {}

    // 2. Fallback untuk Desktop / Unit Test / iOS
    try {
      final file = _getDbFile();
      await file.writeAsString(jsonString, flush: false);
    } catch (_) {}
  }

  static String? readLocalStateSync() {
    try {
      final file = _getDbFile();
      if (!file.existsSync()) return null;
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readLocalStateAsync() async {
    try {
      if (Platform.isAndroid) {
        final res = await _nativeChannel.invokeMethod<String>(
          'readEncryptedPref',
          {'key': 'kopkar_master_state'},
        );
        if (res != null && res.isNotEmpty) return res;
      }
    } catch (_) {}
    return readLocalStateSync();
  }

  static Future<bool> postJson({
    required String url,
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.postUrl(Uri.parse(url));
      headers.forEach((k, v) => req.headers.set(k, v));
      req.add(utf8.encode(body));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  static Future<String?> getJson({
    required String url,
    required Map<String, String> headers,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.getUrl(Uri.parse(url));
      headers.forEach((k, v) => req.headers.set(k, v));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return await resp.transform(utf8.decoder).join();
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<String?> pickImageAsBase64() async {
    try {
      final res = await _nativeChannel.invokeMethod<String>('pickImageAsBase64');
      if (res != null && res.isNotEmpty) {
        return res;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _cachedMacAddress = '36:D5:18:A7:81:7F';

  static Future<String> getDeviceMacAddress() async {
    try {
      if (Platform.isAndroid) {
        final res = await _nativeChannel.invokeMethod<String>('getDeviceMacAddress');
        if (res != null && res.isNotEmpty) {
          _cachedMacAddress = res;
          return res;
        }
      }
    } catch (_) {}

    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run('ifconfig', ['en0']);
        if (result.exitCode == 0) {
          final match = RegExp(r'ether\s+([0-9a-fA-F:]{17})').firstMatch(result.stdout.toString());
          if (match != null) {
            final mac = match.group(1)!.toUpperCase();
            _cachedMacAddress = mac;
            return mac;
          }
        }
      }
    } catch (_) {}

    return _cachedMacAddress;
  }

  static Future<bool> setFlagSecure(bool enable) async {
    try {
      if (Platform.isAndroid) {
        final res = await _nativeChannel.invokeMethod<bool>(
          'setFlagSecure',
          {'enable': enable},
        );
        return res == true;
      }
    } catch (_) {}
    return true;
  }

  static Future<bool> isFlagSecureActive() async {
    try {
      if (Platform.isAndroid) {
        final res = await _nativeChannel.invokeMethod<bool>('isFlagSecureActive');
        return res ?? true;
      }
    } catch (_) {}
    return true;
  }
}
