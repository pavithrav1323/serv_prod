import 'dart:async';
import 'dart:io';

class AppNetworkException implements Exception {
  final String userMessage;
  AppNetworkException(this.userMessage);
}

Never rethrowFriendly(Object error) {
  if (error is SocketException) {
    throw AppNetworkException(
      'No internet connection.\nPlease check your network and try again.',
    );
  }
  if (error is TimeoutException) {
    throw AppNetworkException(
      'Network is taking too long.\nPlease try again in a moment.',
    );
  }
  throw AppNetworkException(
    'Can’t reach the server right now.\nPlease try again shortly.',
  );
}
