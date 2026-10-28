// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

class PlatformStorageHelper {
  static bool get isFlutterTest => false;
  static const String _storageKey = 'kopkar_pt_bbm_db_v3';

  static Future<void> writeLocalState(String jsonString) async {
    try {
      html.window.localStorage[_storageKey] = jsonString;
    } catch (_) {}
  }

  static String? readLocalStateSync() {
    try {
      return html.window.localStorage[_storageKey];
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readLocalStateAsync() async {
    return readLocalStateSync();
  }

  static Future<bool> postJson({
    required String url,
    required Map<String, String> headers,
    required String body,
  }) async {
    return false;
  }

  static Future<String?> getJson({
    required String url,
    required Map<String, String> headers,
  }) async {
    return null;
  }

  /// Buka pemilih foto asli browser / galeri / kamera HP dan kompres ke Base64 JPEG ringan
  static Future<String?> pickImageAsBase64() async {
    final completer = Completer<String?>();
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final file = files.first;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is! String) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        // Kompresi gambar menggunakan HTML Canvas (maks 600px) agar ringan disinkronkan ke Cloud
        final img = html.ImageElement(src: result);
        img.onLoad.listen((_) {
          try {
            final int origW = img.width ?? 600;
            final int origH = img.height ?? 600;
            const int maxDim = 600;
            int targetW = origW;
            int targetH = origH;
            if (origW > maxDim || origH > maxDim) {
              if (origW >= origH) {
                targetW = maxDim;
                targetH = ((origH * maxDim) / origW).round();
              } else {
                targetH = maxDim;
                targetW = ((origW * maxDim) / origH).round();
              }
            }
            final canvas = html.CanvasElement(width: targetW, height: targetH);
            final ctx = canvas.context2D;
            ctx.drawImageScaled(img, 0, 0, targetW, targetH);
            final compressedDataUrl = canvas.toDataUrl('image/jpeg', 0.72);
            final commaIdx = compressedDataUrl.indexOf(',');
            final rawBase64 = commaIdx != -1
                ? compressedDataUrl.substring(commaIdx + 1)
                : compressedDataUrl;
            if (!completer.isCompleted) completer.complete(rawBase64);
          } catch (_) {
            final commaIdx = result.indexOf(',');
            final rawBase64 =
                commaIdx != -1 ? result.substring(commaIdx + 1) : result;
            if (!completer.isCompleted) completer.complete(rawBase64);
          }
        });
        img.onError.listen((_) {
          final commaIdx = result.indexOf(',');
          final rawBase64 =
              commaIdx != -1 ? result.substring(commaIdx + 1) : result;
          if (!completer.isCompleted) completer.complete(rawBase64);
        });
      });
      reader.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
    });

    return completer.future;
  }

  static Future<String> getDeviceMacAddress() async {
    try {
      const key = 'kopkar_device_mac_fp';
      final existing = html.window.localStorage[key];
      if (existing != null && existing.isNotEmpty) return existing;

      final nav = html.window.navigator;
      final seed = '${nav.userAgent}_${nav.hardwareConcurrency}_${html.window.screen?.width}x${html.window.screen?.height}';
      int hash = 0;
      for (int i = 0; i < seed.length; i++) {
        hash = (hash * 31 + seed.codeUnitAt(i)) & 0xFFFFFFFF;
      }
      final b1 = ((hash >> 24) & 0xFE) | 0x02;
      final b2 = (hash >> 16) & 0xFF;
      final b3 = (hash >> 8) & 0xFF;
      final b4 = hash & 0xFF;
      final b5 = (hash ^ 0xAA) & 0xFF;
      final b6 = (hash ^ 0x55) & 0xFF;
      final mac = [b1, b2, b3, b4, b5, b6]
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(':');
      html.window.localStorage[key] = mac;
      return mac;
    } catch (_) {
      return 'FC:DE:48:9A:BC:D1';
    }
  }

  static Future<bool> setFlagSecure(bool enable) async {
    try {
      if (enable) {
        html.document.body?.style.userSelect = 'none';
      } else {
        html.document.body?.style.userSelect = 'auto';
      }
    } catch (_) {}
    return true;
  }

  static Future<bool> isFlagSecureActive() async {
    return true;
  }

  static Future<String?> savePdfToDownloads({
    required String fileName,
    required List<int> pdfBytes,
  }) async {
    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return 'Download/$fileName';
    } catch (_) {
      return null;
    }
  }
}
