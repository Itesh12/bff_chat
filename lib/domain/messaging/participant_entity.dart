import 'dart:convert';
import 'package:crypto/crypto.dart';

class ParticipantEntity {
  final String id;
  final String username;
  final String identityKeyPub;
  final String trustState;

  const ParticipantEntity({
    required this.id,
    required this.username,
    required this.identityKeyPub,
    this.trustState = 'unknown',
  });

  String get identityFingerprint {
    if (identityKeyPub.isEmpty) return '';
    final bytes = utf8.encode(identityKeyPub);
    final digest = sha256.convert(bytes);
    final hex = digest.toString().toUpperCase();
    final chunks = <String>[];
    for (var i = 0; i < hex.length; i += 4) {
      if (i + 4 <= hex.length) {
        chunks.add(hex.substring(i, i + 4));
      }
    }
    return chunks.join('-');
  }

  ParticipantEntity copyWith({
    String? id,
    String? username,
    String? identityKeyPub,
    String? trustState,
  }) {
    return ParticipantEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      identityKeyPub: identityKeyPub ?? this.identityKeyPub,
      trustState: trustState ?? this.trustState,
    );
  }
}
