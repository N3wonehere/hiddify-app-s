import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

abstract final class LanProxyCredentialVerifier {
  static const prefix = r'$hiddify-pbkdf2-sha256$';
  static const defaultIterations = 210000;
  static const minIterations = 100000;
  static const maxIterations = 1000000;
  static const saltLength = 16;
  static const digestLength = 32;
  static const maxCredentialBytes = 255;

  static Future<String> create({
    required String username,
    required String password,
    int iterations = defaultIterations,
    List<int>? salt,
  }) async {
    if (iterations < minIterations || iterations > maxIterations) {
      throw ArgumentError.value(iterations, 'iterations');
    }

    final usernameBytes = utf8.encode(username);
    final passwordBytes = utf8.encode(password);
    if (usernameBytes.isEmpty || usernameBytes.length > maxCredentialBytes) {
      throw ArgumentError.value(username, 'username');
    }
    if (passwordBytes.isEmpty || passwordBytes.length > maxCredentialBytes) {
      throw ArgumentError.value(password, 'password');
    }

    final secureRandom = Random.secure();
    final verifierSalt = salt == null
        ? List<int>.generate(saltLength, (_) => secureRandom.nextInt(256), growable: false)
        : List<int>.unmodifiable(salt);
    if (verifierSalt.length != saltLength) {
      throw ArgumentError.value(verifierSalt.length, 'salt length');
    }

    return Isolate.run(
      () => _deriveVerifier(
        usernameBytes: usernameBytes,
        passwordBytes: passwordBytes,
        salt: verifierSalt,
        iterations: iterations,
      ),
    );
  }

  static bool isValid(String value) {
    if (!value.startsWith(prefix)) return false;
    final parts = value.substring(prefix.length).split(r'$');
    if (parts.length != 3) return false;

    final iterations = int.tryParse(parts[0]);
    if (iterations == null || iterations < minIterations || iterations > maxIterations) return false;

    try {
      final salt = _decodeBase64Url(parts[1]);
      final digest = _decodeBase64Url(parts[2]);
      return salt.length == saltLength &&
          digest.length == digestLength &&
          _encodeBase64Url(salt) == parts[1] &&
          _encodeBase64Url(digest) == parts[2];
    } on FormatException {
      return false;
    }
  }

  static String buildProxyUri({
    required String username,
    required String password,
    required String host,
    required int port,
  }) {
    return Uri(scheme: 'socks', userInfo: '$username:$password', host: host, port: port).toString();
  }
}

String _deriveVerifier({
  required List<int> usernameBytes,
  required List<int> passwordBytes,
  required List<int> salt,
  required int iterations,
}) {
  final credential = Uint8List(4 + usernameBytes.length + passwordBytes.length);
  ByteData.sublistView(credential).setUint32(0, usernameBytes.length, Endian.big);
  credential.setRange(4, 4 + usernameBytes.length, usernameBytes);
  credential.setRange(4 + usernameBytes.length, credential.length, passwordBytes);

  final digest = _pbkdf2HmacSha256(
    secret: credential,
    salt: salt,
    iterations: iterations,
    outputLength: LanProxyCredentialVerifier.digestLength,
  );
  return '${LanProxyCredentialVerifier.prefix}$iterations'
      r'$'
      '${_encodeBase64Url(salt)}'
      r'$'
      '${_encodeBase64Url(digest)}';
}

Uint8List _pbkdf2HmacSha256({
  required List<int> secret,
  required List<int> salt,
  required int iterations,
  required int outputLength,
}) {
  final hmac = Hmac(sha256, secret);
  final output = Uint8List(outputLength);
  var outputOffset = 0;
  var blockIndex = 1;

  while (outputOffset < outputLength) {
    final initialInput = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
    ByteData.sublistView(initialInput).setUint32(salt.length, blockIndex, Endian.big);

    var u = Uint8List.fromList(hmac.convert(initialInput).bytes);
    final block = Uint8List.fromList(u);
    for (var iteration = 1; iteration < iterations; iteration++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var index = 0; index < block.length; index++) {
        block[index] ^= u[index];
      }
    }

    final remaining = outputLength - outputOffset;
    final count = min(block.length, remaining);
    output.setRange(outputOffset, outputOffset + count, block);
    outputOffset += count;
    blockIndex++;
  }
  return output;
}

String _encodeBase64Url(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');

Uint8List _decodeBase64Url(String value) {
  final padding = (4 - value.length % 4) % 4;
  return base64Url.decode('$value${'=' * padding}');
}
