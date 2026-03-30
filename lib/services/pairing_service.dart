import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PairingService {
  final String baseUrl = 'https://alto.samyn.ovh';
  final String userPublicKey = 'pk_alice_xyz';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _lastRelationKey = 'last_relation_code';
  static const String _deviceIdKey = 'local_device_id';

  String generateRelationCode() {
    return const Uuid().v4();
  }

  Future<void> initPairing(String relationCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pairing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'relationCode': relationCode,
        'userPublicKey': userPublicKey,
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
    final first = await http.get(
      Uri.parse('$baseUrl/chat/$relationCode/messages'),
    );

    if (first.statusCode == 200) {
      return _parseMessagesPayload(first.body);
    }

    final fallback = await http.get(
      Uri.parse('$baseUrl/messages/$relationCode'),
    );

    if (fallback.statusCode == 200) {
      return _parseMessagesPayload(fallback.body);
    }

    if (first.statusCode == 404 && fallback.statusCode == 404) {
      throw Exception(
        'API discussion indisponible sur le serveur (endpoints chat non trouves).',
      );
    }

    throw Exception(
      'Erreur chargement messages: ${first.statusCode}/${fallback.statusCode}',
    );
  }

  Future<void> sendDiscussionMessage({
    required String relationCode,
    required String senderId,
    required String content,
    required String type,
  }) async {
    final payload = jsonEncode({
      'relationCode': relationCode,
      'senderId': senderId,
      'content': content,
      'type': type,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
    });

    final first = await http.post(
      Uri.parse('$baseUrl/chat/$relationCode/messages'),
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    if (first.statusCode == 200 || first.statusCode == 201) {
      return;
    }

    final fallback = await http.post(
      Uri.parse('$baseUrl/messages/$relationCode'),
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    if (fallback.statusCode != 200 && fallback.statusCode != 201) {
      if (first.statusCode == 404 && fallback.statusCode == 404) {
        throw Exception(
          'API discussion indisponible sur le serveur (endpoints chat non trouves).',
        );
      }

      throw Exception(
        'Erreur envoi message: ${first.statusCode}/${fallback.statusCode}',
      );
    }
  }

  List<Map<String, dynamic>> _parseMessagesPayload(String body) {
    final decoded = jsonDecode(body);
    final List<dynamic> rawList =
        decoded is List ? decoded : (decoded['messages'] as List<dynamic>? ?? []);

    return rawList.whereType<Map<String, dynamic>>().toList();
  }
}
