/// App-level API error hierarchy.
///
/// Kept out of [ApiClient] so any layer that only needs to catch or render
/// errors can import this file without dragging in the HTTP client.
sealed class AppApiError implements Exception {
  const AppApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

class NetworkError extends AppApiError {
  const NetworkError(super.message);
}

class ServerError extends AppApiError {
  const ServerError(super.message);
}

class ValidationError extends AppApiError {
  const ValidationError(super.message);
}
