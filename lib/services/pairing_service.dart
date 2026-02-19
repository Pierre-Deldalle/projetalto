import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PairingService {
  final String baseUrl = 'https://alto.samyn.ovh';
  final String userPublicKey = 'pk_alice_xyz';

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
}
