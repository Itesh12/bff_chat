import 'dart:convert';

class HiddenVaultConfig {
  final String realPinHash;
  final String? panicPinHash;
  final bool biometricEnabled;
  final String pinSalt;

  const HiddenVaultConfig({
    required this.realPinHash,
    this.panicPinHash,
    this.biometricEnabled = false,
    required this.pinSalt,
  });

  Map<String, dynamic> toJson() {
    return {
      'real_pin_hash': realPinHash,
      'panic_pin_hash': panicPinHash,
      'biometric_enabled': biometricEnabled,
      'pin_salt': pinSalt,
    };
  }

  factory HiddenVaultConfig.fromJson(Map<String, dynamic> json) {
    return HiddenVaultConfig(
      realPinHash: json['real_pin_hash'] as String,
      panicPinHash: json['panic_pin_hash'] as String?,
      biometricEnabled: json['biometric_enabled'] as bool? ?? false,
      pinSalt: json['pin_salt'] as String,
    );
  }

  String serialize() => json.encode(toJson());

  factory HiddenVaultConfig.deserialize(String data) =>
      HiddenVaultConfig.fromJson(json.decode(data) as Map<String, dynamic>);
}
