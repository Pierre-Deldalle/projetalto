import 'dart:math';

class PairingService {
  static final PairingService _instance = PairingService._internal();

  factory PairingService() {
    return _instance;
  }

  PairingService._internal();

  String? _currentRelationCode;

  String generateRelationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();

    final code = String.fromCharCodes(
      Iterable.generate(
        8,
            (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );

    _currentRelationCode = code;
    return code;
  }

  String? get currentRelationCode => _currentRelationCode;

  bool validateRelationCode(String scannedCode) {
    return scannedCode == _currentRelationCode;
  }

  void clearRelation() {
    _currentRelationCode = null;
  }
}