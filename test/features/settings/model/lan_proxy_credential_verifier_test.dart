import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/settings/model/lan_proxy_credential_verifier.dart';

void main() {
  group('LanProxyCredentialVerifier', () {
    test('matches the cross-platform PBKDF2 encoding', () async {
      final verifier = await LanProxyCredentialVerifier.create(
        username: 'alice',
        password: 'correct horse battery staple',
        iterations: 100000,
        salt: List<int>.generate(16, (index) => index),
      );

      expect(
        verifier,
        r'$hiddify-pbkdf2-sha256$100000$AAECAwQFBgcICQoLDA0ODw$Z88nxzJPgIWUeaXuZ--Hvm7oJltx0z9QUHrieYhh1qM',
      );
      expect(LanProxyCredentialVerifier.isValid(verifier), isTrue);
    });

    test('rejects plaintext and malformed verifiers', () {
      expect(LanProxyCredentialVerifier.isValid('password'), isFalse);
      expect(LanProxyCredentialVerifier.isValid(r'$hiddify-pbkdf2-sha256$1$AA$AA'), isFalse);
    });

    test('builds an escaped SOCKS URI', () {
      expect(
        LanProxyCredentialVerifier.buildProxyUri(
          username: 'alice@example',
          password: 'a pass:word',
          host: '2001:db8::1',
          port: 12334,
        ),
        'socks://alice%40example:a%20pass:word@[2001:db8::1]:12334',
      );
    });
  });
}
