class PlatformStorageHelper {
  static bool get isFlutterTest => false;
  static String? _webMemoryStore;

  static Future<void> writeLocalState(String jsonString) async {
    _webMemoryStore = jsonString;
  }

  static String? readLocalStateSync() {
    return _webMemoryStore;
  }

  static Future<String?> readLocalStateAsync() async {
    return _webMemoryStore;
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

  static Future<String?> pickImageAsBase64() async {
    return null;
  }

  static Future<String> getDeviceMacAddress() async {
    return '36:D5:18:A7:81:7F';
  }

  static Future<bool> setFlagSecure(bool enable) async {
    return true;
  }

  static Future<bool> isFlagSecureActive() async {
    return true;
  }

  static Future<String?> savePdfToDownloads({
    required String fileName,
    required List<int> pdfBytes,
  }) async {
    return 'Download/$fileName';
  }
}
