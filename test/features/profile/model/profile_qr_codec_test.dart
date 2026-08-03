import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/model/profile_qr_codec.dart';

void main() {
  group('ProfileQrCodec', () {
    test('keeps small profiles interoperable as plain JSON', () {
      const source = '{\n  "outbounds": [{"type": "direct"}]\n}';
      final encoded = ProfileQrCodec.encode(source);

      expect(encoded, '{"outbounds":[{"type":"direct"}]}');
      expect(ProfileQrCodec.decode(encoded!), isNull);
    });

    test('compresses and restores large profiles', () {
      final source = jsonEncode({
        'outbounds': List.generate(300, (index) => {'type': 'vless', 'tag': 'node-$index', 'server': 'example.com'}),
      });
      final encoded = ProfileQrCodec.encode(source);

      expect(encoded, startsWith(ProfileQrCodec.compressedPrefix));
      expect(jsonDecode(ProfileQrCodec.decode(encoded!)!), jsonDecode(source));
    });

    test('rejects malformed compressed payloads', () {
      expect(() => ProfileQrCodec.decode('${ProfileQrCodec.compressedPrefix}not-base64'), throwsFormatException);
    });

    test('rejects a compressed payload that expands beyond the limit', () {
      final compressed = gzip.encode(utf8.encode('{"value":"${'a' * ProfileQrCodec.maxDecodedBytes}"}'));
      final payload = '${ProfileQrCodec.compressedPrefix}${base64UrlEncode(compressed).replaceAll('=', '')}';

      expect(payload.length, lessThan(ProfileQrCodec.maxQrPayloadBytes));
      expect(() => ProfileQrCodec.decode(payload), throwsFormatException);
    });
  });
}
