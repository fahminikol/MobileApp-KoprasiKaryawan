import 'dart:convert';
import 'package:http/http.dart' as http;

/// ============================================================================
/// KONFIGURASI & MESIN REAL-TIME SYNC (SUPABASE CLOUD 24 JAM + LOCAL BACKUP)
/// Mendukung Android APK, iPhone (iOS), dan Web Browser secara bersamaan
/// ============================================================================
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://anqvtgusqrrcdnbgnxgf.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_D9RsDp3QLeHXEoJm69eoyg_U03A2NGV',
  );

  // Endpoint Sync Server Lokal (Cadangan otomatis saat di Wi-Fi / USB yang sama)
  static const String localSyncServerUrl = String.fromEnvironment(
    'SYNC_SERVER_URL',
    defaultValue: 'http://192.168.18.121:8082/api/state',
  );

  static const List<String> _localSyncEndpoints = [
    'http://127.0.0.1:8082/api/state',
    localSyncServerUrl,
    'http://192.168.18.119:8082/api/state',
  ];

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_ID') &&
      supabaseAnonKey.isNotEmpty;

  /// Kirim (Upsert) state aplikasi secara paralel ke Supabase Cloud 24 Jam & Local Server
  static Future<bool> pushStateToSupabase(Map<String, dynamic> stateData) async {
    final jsonPayload = jsonEncode(stateData);

    Future<bool> pushCloud() async {
      if (!isConfigured) return false;
      try {
        final uri = Uri.parse(
          '$supabaseUrl/rest/v1/kopkar_cloud_store?on_conflict=store_key',
        );
        final body = jsonEncode({
          'store_key': 'pt_bbm_master_v2',
          'payload': stateData,
          'updated_at': DateTime.now().toIso8601String(),
        });
        final supResp = await http
            .post(
              uri,
              headers: {
                'apikey': supabaseAnonKey,
                'Content-Type': 'application/json',
                'Prefer': 'resolution=merge-duplicates',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 25));
        return supResp.statusCode >= 200 && supResp.statusCode < 300;
      } catch (_) {
        return false;
      }
    }

    Future<bool> pushLocal() async {
      for (final endpoint in _localSyncEndpoints) {
        try {
          final localResp = await http
              .post(
                Uri.parse(endpoint),
                headers: {'Content-Type': 'application/json'},
                body: jsonPayload,
              )
              .timeout(const Duration(milliseconds: 900));
          if (localResp.statusCode >= 200 && localResp.statusCode < 300) {
            return true;
          }
        } catch (_) {}
      }
      return false;
    }

    final results = await Future.wait([pushCloud(), pushLocal()]);
    return results.any((ok) => ok);
  }

  /// Ambil (Pull) state terbaru secara paralel dari Supabase Cloud 24 Jam & Local Server
  static Future<Map<String, dynamic>?> pullStateFromSupabase() async {
    Future<Map<String, dynamic>?> pullCloud() async {
      if (!isConfigured) return null;
      try {
        final uri = Uri.parse(
          '$supabaseUrl/rest/v1/kopkar_cloud_store?store_key=eq.pt_bbm_master_v2&select=payload',
        );
        final resp = await http
            .get(
              uri,
              headers: {
                'apikey': supabaseAnonKey,
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 20));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final list = jsonDecode(resp.body) as List;
          if (list.isNotEmpty) {
            final first = list.first as Map<String, dynamic>;
            return first['payload'] as Map<String, dynamic>?;
          }
        }
      } catch (_) {}
      return null;
    }

    Future<Map<String, dynamic>?> pullLocal() async {
      for (final endpoint in _localSyncEndpoints) {
        try {
          final localResp = await http
              .get(
                Uri.parse(endpoint),
                headers: {'Accept': 'application/json'},
              )
              .timeout(const Duration(milliseconds: 900));
          if (localResp.statusCode >= 200 && localResp.statusCode < 300) {
            final decoded = jsonDecode(localResp.body) as Map<String, dynamic>;
            if (decoded['members'] != null) return decoded;
          }
        } catch (_) {}
      }
      return null;
    }

    final results = await Future.wait([pullCloud(), pullLocal()]);
    Map<String, dynamic>? bestState;
    int bestTimestamp = 0;

    for (final candidate in results) {
      if (candidate != null) {
        final ts = (candidate['updatedAtMs'] as num?)?.toInt() ?? 1;
        if (ts >= bestTimestamp) {
          bestTimestamp = ts;
          bestState = candidate;
        }
      }
    }

    return bestState;
  }
}
