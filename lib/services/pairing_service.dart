import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Service gérant la logique d'appairage (pairing) entre deux appareils
/// ainsi que le stockage sécurisé des identifiants et de l'historique.
class PairingService {
  // Configuration API
  final String baseUrl = 'https://alto.samyn.ovh';
  
  // Instance de stockage sécurisé
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Clés de stockage (constantes pour éviter les erreurs de frappe)
  static const String _keyLastRelationCode = 'last_relation_code';
  static const String _keyLocalDeviceId = 'local_device_id';
  static const String _keyDiscussionContext = 'last_discussion_context';
  static const String _prefixHistory = 'discussion_history_';

  /// Génère un code de relation unique (UUID v4).
  String generateRelationCode() {
    return const Uuid().v4();
  }

  /// Initialise une session d'appairage sur le serveur.
  /// [relationCode] est le code unique généré pour cette session.
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
      throw Exception('Erreur lors de l\'initialisation de l\'appairage (Code: ${response.statusCode})');
    }
  }

  /// Vérifie l'état actuel d'une session d'appairage via son [code].
  /// Retourne le statut renvoyé par le serveur (ex: 'pending', 'completed').
  Future<String> checkPairingStatus(String code) async {
    final response = await http.get(
      Uri.parse('$baseUrl/pairing/$code/status'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'];
    } else {
      throw Exception('Erreur serveur lors de la vérification du statut: ${response.statusCode}');
    }
  }

  /// Finalise l'appairage en liant deux codes de relation.
  /// [initiatorCode] : le code généré par le premier appareil (celui qui affiche le QR).
  /// [followerCode] : le code généré par l'appareil qui scanne.
  /// [followerPublicKey] : l'identifiant unique de l'appareil qui scanne.
  Future<void> completePairing({
    required String relationCodeA, // Conservé pour compatibilité API, mais documenté
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
      throw Exception('Erreur lors de la finalisation de l\'appairage: ${response.statusCode}');
    }
  }

  /// Sauvegarde le dernier code de relation utilisé avec succès.
  Future<void> saveLastRelationCode(String relationCode) async {
    await _storage.write(key: _keyLastRelationCode, value: relationCode);
  }

  /// Récupère le dernier code de relation sauvegardé.
  Future<String?> getLastRelationCode() async {
    return _storage.read(key: _keyLastRelationCode);
  }

  /// Supprime le dernier code de relation (déconnexion).
  Future<void> clearLastRelationCode() async {
    await _storage.delete(key: _keyLastRelationCode);
  }

  /// Sauvegarde le contexte de la discussion actuelle (codes locaux et distants).
  Future<void> saveDiscussionContext({
    required String localRelationCode,
    String? remoteRelationCode,
  }) async {
    await _storage.write(
      key: _keyDiscussionContext,
      value: jsonEncode({
        'localRelationCode': localRelationCode,
        'remoteRelationCode': remoteRelationCode,
      }),
    );
  }

  /// Récupère le contexte de discussion sauvegardé.
  /// Retourne une Map contenant 'localRelationCode' et 'remoteRelationCode'.
  Future<Map<String, String?>> getDiscussionContext() async {
    final rawData = await _storage.read(key: _keyDiscussionContext);
    
    if (rawData == null || rawData.isEmpty) {
      return {
        'localRelationCode': await getLastRelationCode(),
        'remoteRelationCode': null,
      };
    }

    try {
      final decoded = jsonDecode(rawData) as Map<String, dynamic>;
      return {
        'localRelationCode': decoded['localRelationCode']?.toString(),
        'remoteRelationCode': decoded['remoteRelationCode']?.toString(),
      };
    } catch (_) {
      // En cas d'erreur de parsing, on tente de récupérer au moins le dernier code connu
      return {
        'localRelationCode': await getLastRelationCode(),
        'remoteRelationCode': null,
      };
    }
  }

  /// Sauvegarde l'historique des messages localement pour un code donné.
  Future<void> saveLocalHistory(
    String localRelationCode,
    List<Map<String, dynamic>> messages,
  ) async {
    await _storage.write(
      key: '$_prefixHistory$localRelationCode',
      value: jsonEncode(messages),
    );
  }

  /// Récupère l'historique des messages sauvegardé localement.
  Future<List<Map<String, dynamic>>> getLocalHistory(
    String localRelationCode,
  ) async {
    final rawData = await _storage.read(key: '$_prefixHistory$localRelationCode');
    if (rawData == null || rawData.isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(rawData) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Récupère l'identifiant unique de l'appareil ou en génère un s'il n'existe pas.
  Future<String> getOrCreateDeviceId() async {
    final existingId = await _storage.read(key: _keyLocalDeviceId);
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final newId = const Uuid().v4();
    await _storage.write(key: _keyLocalDeviceId, value: newId);
    return newId;
  }

  /// Récupère les messages d'une discussion depuis le serveur.
  Future<List<Map<String, dynamic>>> fetchDiscussionMessages(
    String relationCode,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/element?relationCode=${Uri.encodeComponent(relationCode)}'),
    );

    if (response.statusCode == 200) {
      return _parseElementsPayload(response.body);
    }

    throw Exception('Erreur lors du chargement des messages: ${response.statusCode}');
  }

  /// Envoie un message ou une donnée de canal sur le serveur.
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

    throw Exception('Erreur lors de l\'envoi du message: ${response.statusCode}');
  }

  /// Parse le JSON reçu du serveur pour extraire la liste des éléments.
  List<Map<String, dynamic>> _parseElementsPayload(String body) {
    final decoded = jsonDecode(body);
    
    // Le serveur peut renvoyer soit un objet contenant une liste 'elements', soit directement une liste
    final List<dynamic> rawList = decoded is Map<String, dynamic>
        ? (decoded['elements'] as List<dynamic>? ?? [])
        : (decoded is List ? decoded : <dynamic>[]);

    return rawList.whereType<Map<String, dynamic>>().toList();
  }
}
