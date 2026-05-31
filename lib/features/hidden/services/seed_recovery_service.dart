import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

abstract class SeedRecoveryService {
  List<String> generateMnemonic();
  bool validateMnemonic(String mnemonic);
  String derivePublicKey(String mnemonic);
  String derivePrivateKey(String mnemonic);
}

class SeedRecoveryServiceImpl implements SeedRecoveryService {
  final _random = Random.secure();

  // Premium, standard 128-word vocabulary subset of standard BIP-39 words
  static const List<String> _words = [
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract',
    'act', 'action', 'actor', 'actress', 'actual', 'adapt', 'add', 'addict',
    'address', 'adjust', 'admit', 'adult', 'advance', 'advice', 'advisor', 'affect',
    'afford', 'afraid', 'again', 'age', 'agent', 'agree', 'ahead', 'aim',
    'alarm', 'album', 'alcohol', 'alert', 'alien', 'all', 'alley', 'allow',
    'almost', 'alone', 'alpha', 'already', 'also', 'alter', 'always', 'amateur',
    'amazing', 'among', 'amount', 'amused', 'analyst', 'anchor', 'ancient', 'anger',
    'angle', 'angry', 'animal', 'ankle', 'announce', 'annual', 'another', 'answer',
    'antenna', 'antique', 'anxiety', 'any', 'apart', 'apology', 'appear', 'apple',
    'approve', 'april', 'arch', 'arctic', 'area', 'arena', 'argue', 'arm',
    'armed', 'armor', 'army', 'around', 'arrange', 'arrest', 'arrive', 'arrow',
    'art', 'artefact', 'artist', 'artwork', 'ask', 'aspect', 'assault', 'asset',
    'assist', 'assume', 'asthma', 'athlete', 'atom', 'attack', 'attend', 'attitude',
    'attract', 'auction', 'audit', 'august', 'aunt', 'author', 'auto', 'autumn',
    'average', 'avocado', 'avoid', 'awake', 'aware', 'away', 'awesome', 'awful',
    'awkward', 'axis', 'baby', 'bachelor', 'bacon', 'badge', 'bag', 'balance',
  ];

  @override
  List<String> generateMnemonic() {
    final List<String> result = [];
    for (int i = 0; i < 12; i++) {
      final index = _random.nextInt(_words.length);
      result.add(_words[index]);
    }
    return result;
  }

  @override
  bool validateMnemonic(String mnemonic) {
    final clean = mnemonic.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final wordsList = clean.split(RegExp(r'\s+'));
    if (wordsList.length != 12) return false;

    // Verify all words belong to our premium vocab
    for (final word in wordsList) {
      if (!_words.contains(word)) {
        return false;
      }
    }
    return true;
  }

  @override
  String derivePrivateKey(String mnemonic) {
    final cleanMnemonic = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final bytes = utf8.encode(cleanMnemonic);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  String derivePublicKey(String privateKey) {
    final bytes = utf8.encode(privateKey);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
