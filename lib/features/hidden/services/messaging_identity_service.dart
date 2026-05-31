import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/features/hidden/domain/entities/messaging_setup_state.dart';

abstract class MessagingIdentityService {
  Future<MessagingSetupState> getSetupState();
  Future<void> setSetupState(MessagingSetupState state);
  Future<String?> getUsername();
  Future<void> saveUsername(String username);
  Future<String?> getPublicKey();
  Future<String?> getPrivateKey();
  Future<void> saveIdentityKeys(
      {required String pubKey, required String privKey});
  Future<void> resetIdentity();
}

class MessagingIdentityServiceImpl implements MessagingIdentityService {
  final SecureStorageService _secureStorage;

  static const _keySetupState = 'messaging_setup_state';
  static const _keyUsername = 'messaging_my_username';
  static const _keyPub = 'messaging_identity_key_pub';
  static const _keyPriv = 'messaging_identity_key_priv';

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
    await _secureStorage.delete(_keyPub);
    await _secureStorage.delete(_keyPriv);
  }
}
