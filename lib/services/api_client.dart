import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'connectivity_service.dart';

/// Thrown when there is no internet or a request times out.
class NoNetworkException implements Exception {
  final String message;
  NoNetworkException([this.message = 'No internet connection']);
  @override
  String toString() => message;
}

/// Wraps http with connectivity checks + timeouts.
/// Add more verbs (post/put/delete) as needed.
class ApiClient {
  final http.Client _client = http.Client();
  final Duration timeout;

  ApiClient({this.timeout = const Duration(seconds: 20)});

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    await _ensureOnline();
    try {
      return await _client.get(url, headers: headers).timeout(timeout);
    } on SocketException {
      throw NoNetworkException();
    } on TimeoutException {
      throw NoNetworkException('Request timed out');
    }
  }

  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    await _ensureOnline();
    try {
      return await _client
          .post(url, headers: headers, body: body, encoding: encoding)
          .timeout(timeout);
    } on SocketException {
      throw NoNetworkException();
    } on TimeoutException {
      throw NoNetworkException('Request timed out');
    }
  }

  Future<void> _ensureOnline() async {
    final ok = await ConnectivityService.I.isOnline;
    if (!ok) throw NoNetworkException();
  }

  void close() => _client.close();
}
