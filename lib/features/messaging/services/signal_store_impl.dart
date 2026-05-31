import 'dart:typed_data';
import 'package:libsignal/libsignal.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';

class SignalStoreImpl implements SessionStore, IdentityKeyStore, PreKeyStore, SignedPreKeyStore, KyberPreKeyStore {
  final SecureStorageService _secureStorage;
  final MessagingIdentityService _identityService;
  final MessagingRepository _messagingRepository;

  SignalStoreImpl(this._secureStorage, this._identityService, this._messagingRepository);

  static Uint8List _hexToBytes(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ─── IdentityKeyStore ─────────────────────────────────────────────────────

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    final privHex = await _identityService.getPrivateKey();
    final pubHex = await _identityService.getPublicKey();
    if (privHex == null || pubHex == null) {
      throw StateError('Identity keys not generated yet.');
    }
    return IdentityKeyPair.fromKeys(
      privateKey: PrivateKey.deserialize(bytes: _hexToBytes(privHex)),
      publicKey: PublicKey.deserialize(bytes: _hexToBytes(pubHex)),
    );
  }

  @override
  Future<int> getLocalRegistrationId() async {
    final stored = await _secureStorage.read('messaging_registration_id');
    if (stored != null) {
      return int.parse(stored);
    }
    final randomId = 10000 + DateTime.now().millisecond;
    await _secureStorage.write('messaging_registration_id', randomId.toString());
    return randomId;
  }

  @override
  Future<bool> saveIdentity(ProtocolAddress address, PublicKey identityKey) async {
    final pubKeyHex = _bytesToHex(identityKey.serialize());
    final existing = await _messagingRepository.getParticipantById(address.name());
    if (existing == null) {
      await _messagingRepository.createOrUpdateParticipant(
        id: address.name(),
        username: address.name(),
        identityKeyPub: pubKeyHex,
        trustState: 'accepted',
      );
      return true;
    } else {
      if (existing.identityKeyPub != pubKeyHex) {
        // Safety Warning Action under ADR-022: key changed!
        await _messagingRepository.createOrUpdateParticipant(
          id: address.name(),
          username: existing.username,
          identityKeyPub: existing.identityKeyPub, // Keep original key for comparison checks
          trustState: 'revoked', // Mark warning state
        );
        return true;
      }
      return false;
    }
  }

  @override
  Future<PublicKey?> getIdentity(ProtocolAddress address) async {
    final participant = await _messagingRepository.getParticipantById(address.name());
    if (participant == null) return null;
    return PublicKey.deserialize(bytes: _hexToBytes(participant.identityKeyPub));
  }

  @override
  Future<bool> isTrustedIdentity(
    ProtocolAddress address,
    PublicKey identityKey,
    Direction direction,
  ) async {
    final pubKeyHex = _bytesToHex(identityKey.serialize());
    final participant = await _messagingRepository.getParticipantById(address.name());
    if (participant == null) {
      return true; // TOFU
    }
    if (participant.identityKeyPub != pubKeyHex) {
      return false; // key mismatch
    }
    return participant.trustState == 'accepted';
  }

  // ─── SessionStore ─────────────────────────────────────────────────────────

  @override
  Future<SessionRecord?> loadSession(ProtocolAddress address) async {
    final key = 'session_rec_${address.name()}:${address.deviceId()}';
    final hex = await _secureStorage.read(key);
    if (hex == null) return null;
    return SessionRecord.deserialize(bytes: _hexToBytes(hex));
  }

  @override
  Future<void> storeSession(ProtocolAddress address, SessionRecord record) async {
    final key = 'session_rec_${address.name()}:${address.deviceId()}';
    await _secureStorage.write(key, _bytesToHex(record.serialize()));
  }

  @override
  Future<bool> containsSession(ProtocolAddress address) async {
    final key = 'session_rec_${address.name()}:${address.deviceId()}';
    final val = await _secureStorage.read(key);
    return val != null;
  }

  @override
  Future<void> deleteSession(ProtocolAddress address) async {
    final key = 'session_rec_${address.name()}:${address.deviceId()}';
    await _secureStorage.delete(key);
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    final key = 'session_rec_$name:1';
    await _secureStorage.delete(key);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final hasSession = await containsSession(ProtocolAddress(name: name, deviceId: 1));
    return hasSession ? [1] : [];
  }

  // ─── PreKeyStore ──────────────────────────────────────────────────────────

  @override
  Future<PreKeyRecord?> loadPreKey(int preKeyId) async {
    final hex = await _secureStorage.read('ot_prekey_record_$preKeyId');
    if (hex == null) return null;
    return PreKeyRecord.deserialize(bytes: _hexToBytes(hex));
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    await _secureStorage.write('ot_prekey_record_$preKeyId', _bytesToHex(record.serialize()));
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    final val = await _secureStorage.read('ot_prekey_record_$preKeyId');
    return val != null;
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    await _secureStorage.delete('ot_prekey_record_$preKeyId');
  }

  @override
  Future<List<int>> getAllPreKeyIds() async {
    return await _identityService.getOneTimePreKeyIds();
  }

  // ─── SignedPreKeyStore ────────────────────────────────────────────────────

  @override
  Future<SignedPreKeyRecord?> loadSignedPreKey(int signedPreKeyId) async {
    final hex = await _secureStorage.read('signed_prekey_record_$signedPreKeyId');
    if (hex == null) return null;
    return SignedPreKeyRecord.deserialize(bytes: _hexToBytes(hex));
  }

  @override
  Future<void> storeSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) async {
    await _secureStorage.write('signed_prekey_record_$signedPreKeyId', _bytesToHex(record.serialize()));
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    final val = await _secureStorage.read('signed_prekey_record_$signedPreKeyId');
    return val != null;
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    await _secureStorage.delete('signed_prekey_record_$signedPreKeyId');
  }

  @override
  Future<List<int>> getAllSignedPreKeyIds() async {
    return [1];
  }

  // ─── KyberPreKeyStore ─────────────────────────────────────────────────────

  @override
  Future<KyberPreKeyRecord?> loadKyberPreKey(int kyberPreKeyId) async {
    final hex = await _secureStorage.read('kyber_prekey_record_$kyberPreKeyId');
    if (hex == null) return null;
    return KyberPreKeyRecord.deserialize(bytes: _hexToBytes(hex));
  }

  @override
  Future<void> storeKyberPreKey(int kyberPreKeyId, KyberPreKeyRecord record) async {
    await _secureStorage.write('kyber_prekey_record_$kyberPreKeyId', _bytesToHex(record.serialize()));
  }

  @override
  Future<bool> containsKyberPreKey(int kyberPreKeyId) async {
    final val = await _secureStorage.read('kyber_prekey_record_$kyberPreKeyId');
    return val != null;
  }

  @override
  Future<void> markKyberPreKeyUsed(int kyberPreKeyId) async {
    // No-op
  }

  @override
  Future<void> removeKyberPreKey(int kyberPreKeyId) async {
    await _secureStorage.delete('kyber_prekey_record_$kyberPreKeyId');
  }

  @override
  Future<List<int>> getAllKyberPreKeyIds() async {
    return [1];
  }
}
