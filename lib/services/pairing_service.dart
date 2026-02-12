import 'package:uuid/uuid.dart';

class PairingService {
  final _uuid = const Uuid();

  String generateRelationCode() {
    return _uuid.v4();
  }
}