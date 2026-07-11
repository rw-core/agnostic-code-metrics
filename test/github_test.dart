import 'dart:convert';

import 'package:agnostic_code_metrics/src/github.dart';
import 'package:agnostic_code_metrics/src/report.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('creates a new comment when no marker comment exists', () async {
    final calls = <http.Request>[];
    final client = MockClient((req) async {
      calls.add(req);
      if (req.method == 'GET') return http.Response('[]', 200);
      return http.Response('{"id":1}', 201);
    });
    final gh =
        GitHub(token: 't', repository: 'o/r', client: client, apiUrl: 'https://x');

    await gh.upsertStickyComment(7, '$marker body');

    expect(calls.last.method, 'POST');
    expect(calls.last.url.path, '/repos/o/r/issues/7/comments');
  });

  test('edits the existing marker comment in place', () async {
    final calls = <http.Request>[];
    final existing = jsonEncode([
      {'id': 100, 'body': 'unrelated'},
      {'id': 200, 'body': '$marker previous run'},
    ]);
    final client = MockClient((req) async {
      calls.add(req);
      if (req.method == 'GET') return http.Response(existing, 200);
      return http.Response('{"id":200}', 200);
    });
    final gh =
        GitHub(token: 't', repository: 'o/r', client: client, apiUrl: 'https://x');

    await gh.upsertStickyComment(7, '$marker new run');

    final patch = calls.last;
    expect(patch.method, 'PATCH');
    expect(patch.url.path, '/repos/o/r/issues/comments/200');
  });
}
