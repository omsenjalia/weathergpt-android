/// App-level API error hierarchy — port of `lib/core/errors/app_errors.dart`.
/// Kept out of the HTTP client so any layer that only needs to catch or render
/// errors can import this file without dragging in the network stack.

export type AppApiError = NetworkError | ServerError | ValidationError;

export class NetworkError extends Error {
  readonly kind = "network" as const;
  constructor(message: string) {
    super(message);
    this.name = "NetworkError";
  }
}

export class ServerError extends Error {
  readonly kind = "server" as const;
  constructor(message: string) {
    super(message);
    this.name = "ServerError";
  }
}

export class ValidationError extends Error {
  readonly kind = "validation" as const;
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

export function isAppApiError(error: unknown): error is AppApiError {
  return error instanceof NetworkError || error instanceof ServerError || error instanceof ValidationError;
}

export function apiErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
