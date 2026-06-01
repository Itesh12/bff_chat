import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:libsignal/libsignal.dart';
import 'package:memovault/core/observability/app_logger.dart';
import 'package:memovault/core/services/secure_storage_service.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';
import 'package:memovault/features/messaging/services/signal_session_manager.dart';

class PrekeyRotationService extends GetxService {
  final SecureStorageService _secureStorage;
  final MessagingIdentityService _identityService;

  static const _keyLastRotation = 'messaging_last_prekey_rotation_timestamp';

  PrekeyRotationService(this._secureStorage, this._identityService);

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

  /// Checks if 7 days have passed since the last rotation, and if so, runs rotation.
  Future<void> checkAndRotatePrekeys() async {
    try {
      final lastRotationStr = await _secureStorage.read(_keyLastRotation);
      if (lastRotationStr != null) {
        final lastRotation = DateTime.fromMillisecondsSinceEpoch(int.parse(lastRotationStr));
        final diff = DateTime.now().difference(lastRotation).inDays;
        if (diff < 7) {
          AppLogger.info('[PrekeyRotationService] Prekeys were rotated $diff days ago. Skipping.');
          return;
        }
      }

      await rotatePrekeys();
    } catch (e) {
      AppLogger.error('[PrekeyRotationService] Error checking/rotating prekeys: $e');
    }
  }

  /// Programmatically rotates Signed and Kyber Prekeys, saves them, and updates Firestore.
  Future<void> rotatePrekeys() async {
    AppLogger.info('[PrekeyRotationService] Rotating Signed and Kyber prekeys...');

    final currentUid = Firebase.apps.isEmpty
        ? 'bob_uid'
        : (FirebaseAuth.instance.currentUser?.uid ?? 'bob_uid');

    // 1. Load long-term Identity Key to sign prekeys
    final privHex = await _identityService.getPrivateKey();
    if (privHex == null) {
      AppLogger.warning('[PrekeyRotationService] Identity keys not configured yet. Skipping rotation.');
      return;
    }
    final privateKey = PrivateKey.deserialize(bytes: _hexToBytes(privHex));

    // 2. Generate a new Signed Prekey
    final existingSignedIds = await _identityService.getSignedPreKeyIds();
    final signedPrekeyId = existingSignedIds.isEmpty
        ? 1
        : (existingSignedIds.reduce((a, b) => a > b ? a : b) + 1);

    final signedPrekeyPair = PrivateKey.generate();
    final signedPrekeyPublic = signedPrekeyPair.getPublicKey();
    final signedPrekeySignature = privateKey.sign(
      message: signedPrekeyPublic.serialize(),
    );

    // Save Signed Prekey to IdentityService (SecureStorage)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _identityService.saveSignedPreKey(
      id: signedPrekeyId,
      privKeyHex: _bytesToHex(signedPrekeyPair.serialize()),
      pubKeyHex: _bytesToHex(signedPrekeyPublic.serialize()),
      signatureHex: _bytesToHex(signedPrekeySignature),
      timestampMs: nowMs,
    );

    // Serialize and save PreKeyRecord for SignalStoreImpl
    final signedPreKeyRecord = SignedPreKeyRecord(
      id: signedPrekeyId,
      timestamp: BigInt.from(nowMs),
      publicKey: signedPrekeyPublic,
      privateKey: signedPrekeyPair,
      signature: signedPrekeySignature,
    );
    await _secureStorage.write(
      'signed_prekey_record_$signedPrekeyId',
      _bytesToHex(signedPreKeyRecord.serialize()),
    );

    // 3. Generate a new Kyber Prekey
    final existingKyberIds = await _identityService.getKyberPreKeyIds();
    final kyberPrekeyId = existingKyberIds.isEmpty
        ? 1
        : (existingKyberIds.reduce((a, b) => a > b ? a : b) + 1);

    final kyberKeyPair = KyberKeyPair.generate();
    final kyberPrekeySignature = privateKey.sign(
      message: kyberKeyPair.getPublicKey().serialize(),
    );

    // Save Kyber Prekey to IdentityService (SecureStorage)
    await _identityService.saveKyberPreKey(
      id: kyberPrekeyId,
      privKeyHex: _bytesToHex(kyberKeyPair.getSecretKey().serialize()),
      pubKeyHex: _bytesToHex(kyberKeyPair.getPublicKey().serialize()),
      signatureHex: _bytesToHex(kyberPrekeySignature),
      timestampMs: nowMs,
    );

    // Serialize and save KyberPreKeyRecord for SignalStoreImpl
    final kyberPreKeyRecord = KyberPreKeyRecord.create(
      id: kyberPrekeyId,
      timestamp: BigInt.from(nowMs),
      keyPair: kyberKeyPair,
      signature: kyberPrekeySignature,
    );
    await _secureStorage.write(
      'kyber_prekey_record_$kyberPrekeyId',
      _bytesToHex(kyberPreKeyRecord.serialize()),
    );

    // 4. Update the prekey bundle on Firestore
    final Map<String, dynamic> bundleUpdate = {
      'signedPrekeyId': signedPrekeyId,
      'signedPrekeyPublic': _bytesToHex(signedPrekeyPublic.serialize()),
      'signedPrekeySignature': _bytesToHex(signedPrekeySignature),
      'kyberPrekeyId': kyberPrekeyId,
      'kyberPrekeyPublic': _bytesToHex(kyberKeyPair.getPublicKey().serialize()),
      'kyberPrekeySignature': _bytesToHex(kyberPrekeySignature),
    };

    if (Firebase.apps.isEmpty && SignalSessionManager.mockPrekeyBundles != null) {
      final doc = SignalSessionManager.mockPrekeyBundles![currentUid];
      if (doc != null) {
        doc.addAll(bundleUpdate);
        AppLogger.info('[PrekeyRotationService] [Mock] Successfully updated mock prekey bundle.');
      }
    } else if (Firebase.apps.isNotEmpty) {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('prekey_bundles').doc(currentUid).set(
        bundleUpdate,
        SetOptions(merge: true),
      );
      AppLogger.info('[PrekeyRotationService] Successfully uploaded rotated prekey bundle.');
    }

    // 5. Update last rotation timestamp in SecureStorage
    await _secureStorage.write(_keyLastRotation, nowMs.toString());
    AppLogger.info('[PrekeyRotationService] Prekey rotation completed successfully.');
  }
}
