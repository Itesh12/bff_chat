import 'dart:convert';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';

abstract class MessagingIdentityService {
  Future<MessagingSetupState> getSetupState();
  Future<void> setSetupState(MessagingSetupState state);
  Future<String?> getUsername();
  Future<void> saveUsername(String username);
  Future<String?> getDisplayName();
  Future<void> saveDisplayName(String displayName);
  Future<String?> getPublicKey();
  Future<String?> getPrivateKey();
  Future<void> saveIdentityKeys(
      {required String pubKey, required String privKey});
  Future<void> resetIdentity();

  // Local Prekey persistence
  Future<void> saveSignedPreKey({
    required int id,
    required String privKeyHex,
    required String pubKeyHex,
    required String signatureHex,
    required int timestampMs,
  });
  Future<Map<String, dynamic>?> loadSignedPreKey(int id);
  Future<List<int>> getSignedPreKeyIds();

  Future<void> saveKyberPreKey({
    required int id,
    required String privKeyHex,
    required String pubKeyHex,
    required String signatureHex,
    required int timestampMs,
  });
  Future<Map<String, dynamic>?> loadKyberPreKey(int id);
  Future<List<int>> getKyberPreKeyIds();

  Future<void> saveOneTimePreKey({
    required int id,
    required String privKeyHex,
    required String pubKeyHex,
  });
  Future<Map<String, dynamic>?> loadOneTimePreKey(int id);
  Future<bool> containsOneTimePreKey(int id);
  Future<void> removeOneTimePreKey(int id);
  Future<List<int>> getOneTimePreKeyIds();
}

class MessagingIdentityServiceImpl implements MessagingIdentityService {
  final SecureStorageService _secureStorage;

  static const _keySetupState = 'messaging_setup_state';
  static const _keyUsername = 'messaging_my_username';
  static const _keyDisplayName = 'messaging_my_display_name';
  static const _keyPub = 'messaging_identity_key_pub';
  static const _keyPriv = 'messaging_identity_key_priv';

  static const _keySignedPreKeyIds = 'messaging_signed_prekey_ids';
  static const _keyKyberPreKeyIds = 'messaging_kyber_prekey_ids';
  static const _keyOneTimePreKeyIds = 'messaging_ot_prekey_ids';

  MessagingIdentityServiceImpl(this._secureStorage);

  @override
  Future<MessagingSetupState> getSetupState() async {
    final val = await _secureStorage.read(_keySetupState);
    if (val == null) return MessagingSetupState.unconfigured;

    // Support state rename (registered -> identityPublished)
    if (val == 'registered') {
      return MessagingSetupState.identityPublished;
    }

    return MessagingSetupState.values.firstWhere(
      (e) => e.name == val,
      orElse: () => MessagingSetupState.unconfigured,
    );
  }

  @override
  Future<void> setSetupState(MessagingSetupState state) async {
    await _secureStorage.write(_keySetupState, state.name);
  }

  @override
  Future<String?> getUsername() async {
    return await _secureStorage.read(_keyUsername);
  }

  @override
  Future<void> saveUsername(String username) async {
    await _secureStorage.write(_keyUsername, username);
  }

  @override
  Future<String?> getDisplayName() async {
    return await _secureStorage.read(_keyDisplayName);
  }

  @override
  Future<void> saveDisplayName(String displayName) async {
    await _secureStorage.write(_keyDisplayName, displayName);
  }

  @override
  Future<String?> getPublicKey() async {
    return await _secureStorage.read(_keyPub);
  }

  @override
  Future<String?> getPrivateKey() async {
    return await _secureStorage.read(_keyPriv);
  }

  @override
  Future<void> saveIdentityKeys(
      {required String pubKey, required String privKey}) async {
    await _secureStorage.write(_keyPub, pubKey);
    await _secureStorage.write(_keyPriv, privKey);
  }

  @override
  Future<void> resetIdentity() async {
    await _secureStorage.delete(_keySetupState);
    await _secureStorage.delete(_keyUsername);
    await _secureStorage.delete(_keyDisplayName);
    await _secureStorage.delete(_keyPub);
    await _secureStorage.delete(_keyPriv);
    await _secureStorage.delete('messaging_registration_id');
    await _secureStorage.delete('messaging_last_prekey_rotation_timestamp');

    // Delete prekeys list and records
    final spIds = await getSignedPreKeyIds();
    for (final id in spIds) {
      await _secureStorage.delete('messaging_signed_prekey_$id');
      await _secureStorage.delete('signed_prekey_record_$id');
    }
    await _secureStorage.delete(_keySignedPreKeyIds);

    final kpIds = await getKyberPreKeyIds();
    for (final id in kpIds) {
      await _secureStorage.delete('messaging_kyber_prekey_$id');
      await _secureStorage.delete('kyber_prekey_record_$id');
    }
    await _secureStorage.delete(_keyKyberPreKeyIds);

    final otIds = await getOneTimePreKeyIds();
    for (final id in otIds) {
      await _secureStorage.delete('messaging_ot_prekey_$id');
    }
    await _secureStorage.delete(_keyOneTimePreKeyIds);
  }

  // ─── Local Prekey persistence implementations ────────────────────────────

  @override
  Future<void> saveSignedPreKey({
    required int id,
    required String privKeyHex,
    required String pubKeyHex,
    required String signatureHex,
    required int timestampMs,
  }) async {
    final data = {
      'id': id,
      'privKeyHex': privKeyHex,
      'pubKeyHex': pubKeyHex,
      'signatureHex': signatureHex,
      'timestampMs': timestampMs,
    };
    await _secureStorage.write('messaging_signed_prekey_$id', jsonEncode(data));

    // Update list of IDs
    final ids = await getSignedPreKeyIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await _secureStorage.write(_keySignedPreKeyIds, ids.join(','));
    }
  }

  @override
  Future<Map<String, dynamic>?> loadSignedPreKey(int id) async {
    final val = await _secureStorage.read('messaging_signed_prekey_$id');
    if (val == null) return null;
    return jsonDecode(val) as Map<String, dynamic>;
  }

  @override
  Future<List<int>> getSignedPreKeyIds() async {
    final val = await _secureStorage.read(_keySignedPreKeyIds);
    if (val == null || val.isEmpty) return [];
    return val.split(',').map(int.parse).toList();
  }

  @override
  Future<void> saveKyberPreKey({
    required int id,
    required String privKeyHex,
    required String pubKeyHex,
    required String signatureHex,
    required int timestampMs,
  }) async {
    final data = {
      'id': id,
      'privKeyHex': privKeyHex,
      'pubKeyHex': pubKeyHex,
      'signatureHex': signatureHex,
      'timestampMs': timestampMs,
    };
    await _secureStorage.write('messaging_kyber_prekey_$id', jsonEncode(data));

    // Update list of IDs
    final ids = await getKyberPreKeyIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await _secureStorage.write(_keyKyberPreKeyIds, ids.join(','));
    }
  }

  @override
  Future<Map<String, dynamic>?> loadKyberPreKey(int id) async {
    final val = await _secureStorage.read('messaging_kyber_prekey_$id');
    if (val == null) return null;
    return jsonDecode(val) as Map<String, dynamic>;
  }

  @override
  Future<List<int>> getKyberPreKeyIds() async {
    final val = await _secureStorage.read(_keyKyberPreKeyIds);
    if (val == null || val.isEmpty) return [];
    return val.split(',').map(int.parse).toList();
  }

  @override
  Future<void> saveOneTimePreKey({
    required int id,
    required String privKeyHex,
    required String pubKeyHex,
  }) async {
    final data = {
      'id': id,
      'privKeyHex': privKeyHex,
      'pubKeyHex': pubKeyHex,
    };
    await _secureStorage.write('messaging_ot_prekey_$id', jsonEncode(data));

    // Update list of IDs
    final ids = await getOneTimePreKeyIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await _secureStorage.write(_keyOneTimePreKeyIds, ids.join(','));
    }
  }

  @override
  Future<Map<String, dynamic>?> loadOneTimePreKey(int id) async {
    final val = await _secureStorage.read('messaging_ot_prekey_$id');
    if (val == null) return null;
    return jsonDecode(val) as Map<String, dynamic>;
  }

  @override
  Future<bool> containsOneTimePreKey(int id) async {
    final val = await _secureStorage.read('messaging_ot_prekey_$id');
    return val != null;
  }

  @override
  Future<void> removeOneTimePreKey(int id) async {
    await _secureStorage.delete('messaging_ot_prekey_$id');
    final ids = await getOneTimePreKeyIds();
    if (ids.contains(id)) {
      ids.remove(id);
      if (ids.isEmpty) {
        await _secureStorage.delete(_keyOneTimePreKeyIds);
      } else {
        await _secureStorage.write(_keyOneTimePreKeyIds, ids.join(','));
      }
    }
  }

  @override
  Future<List<int>> getOneTimePreKeyIds() async {
    final val = await _secureStorage.read(_keyOneTimePreKeyIds);
    if (val == null || val.isEmpty) return [];
    return val.split(',').map(int.parse).toList();
  }
}
