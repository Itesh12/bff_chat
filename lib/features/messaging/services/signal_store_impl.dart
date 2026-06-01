import 'dart:typed_data';
import 'package:libsignal/libsignal.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/domain/messaging/messaging_repository.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';

class SignalStoreImpl implements SessionStore, IdentityKeyStore, PreKeyStore, SignedPreKeyStore, KyberPreKeyStore {
  final SecureStorageService _secureStorage;
  final MessagingIdentityService _identityService;
  final MessagingRepository _messagingRepository;
  final bool isHidden;

  SignalStoreImpl(
    this._secureStorage,
    this._identityService,
    this._messagingRepository, {
    this.isHidden = true,
  });

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
    final bytes = await _messagingRepository.loadSession(address.name(), address.deviceId(), isHidden);
    if (bytes == null) return null;
    return SessionRecord.deserialize(bytes: bytes);
  }

  @override
  Future<void> storeSession(ProtocolAddress address, SessionRecord record) async {
    await _messagingRepository.storeSession(
      address.name(),
      address.deviceId(),
      Uint8List.fromList(record.serialize()),
      isHidden,
    );
  }

  @override
  Future<bool> containsSession(ProtocolAddress address) async {
    return await _messagingRepository.containsSession(address.name(), address.deviceId(), isHidden);
  }

  @override
  Future<void> deleteSession(ProtocolAddress address) async {
    await _messagingRepository.deleteSession(address.name(), address.deviceId(), isHidden);
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    await _messagingRepository.deleteAllSessions(name, isHidden);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    return await _messagingRepository.getSubDeviceSessions(name, isHidden);
  }

  // ─── PreKeyStore ──────────────────────────────────────────────────────────

  @override
  Future<PreKeyRecord?> loadPreKey(int preKeyId) async {
    final bytes = await _messagingRepository.loadPreKey(preKeyId, isHidden);
    if (bytes == null) return null;
    return PreKeyRecord.deserialize(bytes: bytes);
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    await _messagingRepository.storePreKey(preKeyId, Uint8List.fromList(record.serialize()), isHidden);
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    return await _messagingRepository.containsPreKey(preKeyId, isHidden);
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    await _messagingRepository.removePreKey(preKeyId, isHidden);
  }

  @override
  Future<List<int>> getAllPreKeyIds() async {
    return await _messagingRepository.getAllPreKeyIds(isHidden);
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
