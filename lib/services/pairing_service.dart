import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PairingService {
  final String baseUrl = 'https://alto.samyn.ovh';
  final String userPublicKey = 'pk_alice_xyz';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _lastRelationKey = 'last_relation_code';

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
}
