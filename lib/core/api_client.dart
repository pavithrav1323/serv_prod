import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_messenger.dart';

class ApiClient {
  ApiClient(this.baseUrl);
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    try {
      return await http.get(_u(path), headers: headers).timeout(_timeout);
    } on SocketException {
      AppMessenger.show('No internet connection. Please check your network.');
      rethrow;
    } on TimeoutException {
      AppMessenger.show('Network is slow. Please try again in a moment.');
      rethrow;
    } catch (_) {
      AppMessenger.show('Can’t reach the server right now. Try again shortly.');
      rethrow;
    }
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http
          .post(_u(path), headers: headers, body: body)
          .timeout(_timeout);
    } on SocketException {
      AppMessenger.show('No internet connection. Please check your network.');
      rethrow;
    } on TimeoutException {
      AppMessenger.show('Network is slow. Please try again in a moment.');
      rethrow;
    } catch (_) {
      AppMessenger.show('Can’t reach the server right now. Try again shortly.');
      rethrow;
    }
  }

  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http
          .put(_u(path), headers: headers, body: body)
          .timeout(_timeout);
    } on SocketException {
      AppMessenger.show('No internet connection. Please check your network.');
      rethrow;
    } on TimeoutException {
      AppMessenger.show('Network is slow. Please try again in a moment.');
      rethrow;
    } catch (_) {
      AppMessenger.show('Can’t reach the server right now. Try again shortly.');
      rethrow;
    }
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http
          .delete(_u(path), headers: headers, body: body)
          .timeout(_timeout);
    } on SocketException {
      AppMessenger.show('No internet connection. Please check your network.');
      rethrow;
    } on TimeoutException {
      AppMessenger.show('Network is slow. Please try again in a moment.');
      rethrow;
    } catch (_) {
      AppMessenger.show('Can’t reach the server right now. Try again shortly.');
      rethrow;
    }
  }
}
