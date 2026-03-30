import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PairingService {
  final String baseUrl = 'https://alto.samyn.ovh';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _lastRelationKey = 'last_relation_code';
  static const String _deviceIdKey = 'local_device_id';
  static const String _discussionContextKey = 'last_discussion_context';
  static const String _historyPrefix = 'discussion_history_';

  String generateRelationCode() {
    return const Uuid().v4();
  }

  Future<void> initPairing(String relationCode) async {
    final deviceId = await getOrCreateDeviceId();

    final response = await http.post(
      Uri.parse('$baseUrl/pairing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'relationCode': relationCode,
        'userPublicKey': deviceId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur init pairing: ${response.statusCode}');
    }
  }

  Future<String> checkPairingStatus(String code) async {
    final response = await http.get(
      Uri.parse('$baseUrl/pairing/$code/status'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'];
    } else {
      throw Exception('Erreur serveur: ${response.statusCode}');
    }
  }

  Future<void> completePairing({
    required String relationCodeA,
    required String relationCodeB,
    required String publicKeyB,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/pairing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'relationCodeA': relationCodeA,
        'relationCodeB': relationCodeB,
        'publicKeyB': publicKeyB,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur complete pairing: ${response.statusCode}');
    }
  }

  Future<void> saveLastRelationCode(String relationCode) async {
    await _storage.write(key: _lastRelationKey, value: relationCode);
  }

  Future<String?> getLastRelationCode() async {
    return _storage.read(key: _lastRelationKey);
  }

  Future<void> clearLastRelationCode() async {
    await _storage.delete(key: _lastRelationKey);
  }

  Future<void> saveDiscussionContext({
    required String localRelationCode,
    String? remoteRelationCode,
  }) async {
    await _storage.write(
      key: _discussionContextKey,
      value: jsonEncode({
        'localRelationCode': localRelationCode,
        'remoteRelationCode': remoteRelationCode,
      }),
    );
  }

  Future<Map<String, String?>> getDiscussionContext() async {
    final raw = await _storage.read(key: _discussionContextKey);
    if (raw == null || raw.isEmpty) {
      return {
        'localRelationCode': await getLastRelationCode(),
        'remoteRelationCode': null,
      };
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'localRelationCode': decoded['localRelationCode']?.toString(),
        'remoteRelationCode': decoded['remoteRelationCode']?.toString(),
      };
    } catch (_) {
      return {
        'localRelationCode': await getLastRelationCode(),
        'remoteRelationCode': null,
      };
    }
  }

  Future<void> saveLocalHistory(
    String localRelationCode,
    List<Map<String, dynamic>> messages,
  ) async {
    await _storage.write(
      key: '$_historyPrefix$localRelationCode',
      value: jsonEncode(messages),
    );
  }

  Future<List<Map<String, dynamic>>> getLocalHistory(
    String localRelationCode,
  ) async {
    final raw = await _storage.read(key: '$_historyPrefix$localRelationCode');
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  Future<List<Map<String, dynamic>>> fetchDiscussionMessages(
    String relationCode,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/element?relationCode=${Uri.encodeComponent(relationCode)}'),
    );

    if (response.statusCode == 200) {
      return _parseElementsPayload(response.body);
    }

    throw Exception('Erreur chargement messages: ${response.statusCode}');
  }

  Future<void> sendDiscussionMessage({
    required String relationCode,
    required String senderId,
    required String content,
    required String type,
  }) async {
    final payload = jsonEncode({
      'relationCode': relationCode,
      'key': type,
      'value': content,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/element'),
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    throw Exception('Erreur envoi message: ${response.statusCode}');
  }

  List<Map<String, dynamic>> _parseElementsPayload(String body) {
    final decoded = jsonDecode(body);
    final List<dynamic> rawList = decoded is Map<String, dynamic>
        ? (decoded['elements'] as List<dynamic>? ?? [])
        : (decoded is List ? decoded : <dynamic>[]);

    return rawList.whereType<Map<String, dynamic>>().toList();
  }
}
