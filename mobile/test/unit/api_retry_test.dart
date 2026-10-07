import 'dart:convert';
import 'dart:typed_data';

import 'package:campusflow/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Koneksi putus sesaat diulang sekali diem-diem (termasuk upload multipart),
/// dan upload yang kena token expired tetap bisa diulang setelah refresh.
void main() {
  late ProviderContainer container;
  late Dio dio;
  late _ScriptedAdapter adapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'flutter.cf_access_token': 'old-access',
      'flutter.cf_refresh_token': 'refresh',
      'flutter.cf_server_url': 'http://test',
    });
    retryDelay = Duration.zero;
    container = ProviderContainer();
    dio = container.read(apiClientProvider);
    adapter = _ScriptedAdapter();
    dio.httpClientAdapter = adapter;
  });
  tearDown(() => container.dispose());

  test('koneksi putus sekali -> diulang otomatis, user dapat hasilnya', () async {
    adapter.script = [_drop, _ok];
    final resp = await dio.get('/tasks');
    expect(resp.data, {'ok': true});
    expect(adapter.calls, 2);
  });

  test('upload multipart juga bisa diulang (body di-clone)', () async {
    adapter.script = [_drop, _ok];
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(Uint8List.fromList([1, 2, 3]), filename: 'snap.jpg'),
    });
    final resp = await dio.post('/ai/snap/extract', data: form);
    expect(resp.data, {'ok': true});
    expect(adapter.calls, 2);
    expect(adapter.bodies.every((b) => b.contains('snap.jpg')), isTrue);
  });

  test('putus terus -> cuma diulang sekali, error diterusin', () async {
    adapter.script = [_drop, _drop, _ok];
    await expectLater(dio.get('/tasks'), throwsA(isA<DioException>()));
    expect(adapter.calls, 2);
  });

  test('upload kena token expired -> refresh lalu diulang dengan body utuh', () async {
    adapter.script = [_unauthorized, _ok];
    adapter.refreshResponse = {'access_token': 'new-access', 'refresh_token': 'refresh'};
    final form = FormData.fromMap({
      'audio': MultipartFile.fromBytes(Uint8List.fromList([4, 5]), filename: 'voice.m4a'),
    });
    final resp = await dio.post('/ai/snap/voice', data: form);
    expect(resp.data, {'ok': true});
    expect(adapter.lastAuth, 'Bearer new-access');
    expect(adapter.bodies.last, contains('voice.m4a'));
  });
}

// langkah skenario adapter
const _drop = 'drop';
const _ok = 'ok';
const _unauthorized = '401';

class _ScriptedAdapter implements HttpClientAdapter {
  List<String> script = [];
  int calls = 0;
  final bodies = <String>[];
  String? lastAuth;
  Map<String, dynamic>? refreshResponse;

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Dio refresh pake adapter yg sama, jawab langsung tanpa ngitung panggilan
    if (options.path == '/auth/refresh') return _json(refreshResponse!, 200);
    calls++;
    // baca body sampe abis, kayak adapter beneran (ini yg bikin FormData "final")
    final chunks = <int>[];
    if (requestStream != null) {
      await for (final c in requestStream) {
        chunks.addAll(c);
      }
    }
    bodies.add(utf8.decode(chunks, allowMalformed: true));
    lastAuth = options.headers['Authorization'] as String?;
    final step = script.removeAt(0);
    switch (step) {
      case _drop:
        throw DioException.connectionError(requestOptions: options, reason: 'reset by peer');
      case _unauthorized:
        return _json({'detail': 'expired'}, 401);
      default:
        return _json({'ok': true}, 200);
    }
  }

  @override
  void close({bool force = false}) {}
}
