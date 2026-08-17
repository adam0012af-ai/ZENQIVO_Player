import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/zenqivo_config.dart';
import '../models/playlist.dart';
import '../services/device_identity_service.dart';

class ZenqivoApiException implements Exception {
  const ZenqivoApiException(this.code, {this.statusCode});
  final String code;
  final int? statusCode;

  @override
  String toString() => 'ZenqivoApiException($code, $statusCode)';
}

class DeviceStatus {
  const DeviceStatus({required this.active, this.activatedUntil});
  final bool active;
  final DateTime? activatedUntil;
}

class SyncPayload {
  const SyncPayload({required this.playlists, required this.syncedAt});
  final List<ZenqivoPlaylist> playlists;
  final DateTime syncedAt;
}

class ZenqivoApi {
  ZenqivoApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ZenqivoConfig.apiBaseUrl;

  final http.Client _client;
  final String baseUrl;
  static const _timeout = Duration(seconds: 12);

  Future<DeviceStatus> register(DeviceIdentity identity) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/devices/register'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'deviceId': identity.deviceId,
        'deviceKey': identity.deviceKey,
        'platform': 'flutter',
        'appVersion': ZenqivoConfig.version,
      }),
    ).timeout(_timeout);
    return _parseStatus(response);
  }

  Future<DeviceStatus> status(DeviceIdentity identity) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/devices/status'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'deviceId': identity.deviceId, 'deviceKey': identity.deviceKey}),
    ).timeout(_timeout);
    return _parseStatus(response);
  }

  Future<SyncPayload> sync(DeviceIdentity identity) async {
    final uri = Uri.parse('$baseUrl/api/v1/sync').replace(queryParameters: {
      'deviceId': identity.deviceId,
      'deviceKey': identity.deviceKey,
    });
    final response = await _client.get(uri).timeout(_timeout);
    final data = _json(response);
    if (response.statusCode != 200) {
      throw ZenqivoApiException(data['error'] as String? ?? 'sync_failed', statusCode: response.statusCode);
    }
    final lists = (data['playlists'] as List<dynamic>? ?? const [])
        .map((e) => ZenqivoPlaylist.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return SyncPayload(
      playlists: lists,
      syncedAt: DateTime.tryParse(data['syncedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  DeviceStatus _parseStatus(http.Response response) {
    final data = _json(response);
    if (response.statusCode != 200) {
      throw ZenqivoApiException(data['error'] as String? ?? 'device_request_failed', statusCode: response.statusCode);
    }
    return DeviceStatus(
      active: data['active'] == true,
      activatedUntil: DateTime.tryParse(
        (data['device'] as Map<String, dynamic>?)?['activatedUntil'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> _json(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ZenqivoApiException('invalid_server_response');
    }
  }
}
