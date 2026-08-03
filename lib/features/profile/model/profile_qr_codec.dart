import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

abstract final class ProfileQrCodec {
  static const compressedPrefix = 'hiddify-json://v1/';
  static const maxQrPayloadBytes = 2800;
  static const maxDecodedBytes = 1024 * 1024;

  static String? encode(String json) {
    final normalized = jsonEncode(jsonDecode(json));
    final normalizedLength = _byteLength(normalized);
    if (normalizedLength <= maxQrPayloadBytes) return normalized;
    if (normalizedLength > maxDecodedBytes) return null;

    final compressed = gzip.encode(utf8.encode(normalized));
    final payload = '$compressedPrefix${base64UrlEncode(compressed).replaceAll('=', '')}';
    return _byteLength(payload) <= maxQrPayloadBytes ? payload : null;
  }

  static String? decode(String input) {
    if (!input.startsWith(compressedPrefix)) return null;
    final encoded = input.substring(compressedPrefix.length);
    if (encoded.isEmpty || _byteLength(input) > maxQrPayloadBytes) {
      throw const FormatException('Invalid QR profile payload');
    }

    try {
      final padding = (4 - encoded.length % 4) % 4;
      final compressed = base64Url.decode('$encoded${'=' * padding}');
      final output = _BoundedByteSink(maxDecodedBytes);
      gzip.decoder.startChunkedConversion(output)
        ..add(compressed)
        ..close();

      final json = utf8.decode(output.bytes);
      jsonDecode(json);
      return json;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid QR profile payload');
    }
  }

  static int _byteLength(String value) => utf8.encode(value).length;
}

final class _BoundedByteSink implements Sink<List<int>> {
  _BoundedByteSink(this.maxBytes);

  final int maxBytes;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  var _length = 0;

  Uint8List get bytes => _builder.toBytes();

  @override
  void add(List<int> data) {
    _length += data.length;
    if (_length > maxBytes) {
      throw const FormatException('QR profile payload is too large');
    }
    _builder.add(data);
  }

  @override
  void close() {}
}
