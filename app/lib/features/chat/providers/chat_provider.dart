import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/request_context.dart';
import '../../../core/services/api_client.dart';
import '../../farmer/providers/farm_profile_provider.dart';
import '../../home/providers/location_provider.dart';
import '../../settings/providers/settings_provider.dart';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.meta,
    DateTime? at,
  }) : at = at ?? DateTime.now();
  final String role; // user | assistant
  final String content;
  final DateTime at;

  /// Additive response metadata from the backend (`meta` in /chat responses).
  /// Present on the assistant message when the server sent it; used to surface
  /// routing diagnostics such as the System One intent engine.
  final Map<String, dynamic>? meta;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.sending = false,
    this.error,
  });
  final List<ChatMessage> messages;
  final bool sending;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(const ChatState());
  final Ref _ref;

  /// Bumped whenever the conversation is cleared or the identity/mode context
  /// changes, so a late response from a superseded context is discarded rather
  /// than appended to a different conversation.
  int _generation = 0;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    final generation = _generation;
    final next = [...state.messages, ChatMessage(role: 'user', content: trimmed)];
    state = state.copyWith(messages: next, sending: true, clearError: true);
    try {
      final result = await ApiClient.instance
          .post(ApiEndpoints.chat, data: buildPayload(next, trimmed));
      // Context changed while the request was in flight: drop the answer.
      if (generation != _generation) return;
      final reply = '${result['response'] ?? ''}';
      final meta = result['meta'] is Map
          ? (result['meta'] as Map).cast<String, dynamic>()
          : null;
      state = state.copyWith(
        sending: false,
        messages: [
          ...next,
          ChatMessage(role: 'assistant', content: reply, meta: meta),
        ],
      );
    } on AppApiError catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(sending: false, error: e.message);
    } catch (_) {
      if (generation != _generation) return;
      state = state.copyWith(
          sending: false, error: 'Could not reach WeatherGPT. Try again.');
    }
  }

  /// Assembles the /chat request body from the current settings, location and
  /// saved farm profile.
  ///
  /// Farm context is read from [farmProfileProvider] — the same source
  /// `/advisory` uses — instead of assuming a crop. Mode and farm fields are
  /// built by [buildAgentRequestContext] so chat and voice cannot drift.
  @visibleForTesting
  Map<String, dynamic> buildPayload(
      List<ChatMessage> messages, String message) {
    final settings = _ref.read(settingsProvider);
    final location = _ref.read(locationProvider);
    final profile = _ref.read(farmProfileProvider);
    final context = buildAgentRequestContext(
      profilePersona: settings.userPersona,
      farm: FarmContext(
        crop: profile.crop,
        growthStage: profile.growthStage,
        soilType: profile.soilType,
        irrigationType: profile.irrigationType,
      ),
    );
    return {
      'message': message,
      'messages': messages.map((m) => m.toJson()).toList(),
      'location': location.name,
      'lat': location.lat,
      'lon': location.lon,
      'language': settings.language,
      ...context.toPayload(),
    };
  }

  void clear() {
    _generation++;
    state = const ChatState();
  }

  /// Re-sends the last user message after a failure (banner "Retry" action).
  void retryLast() {
    final hasUserTurn = state.messages.any((m) => m.role == 'user');
    if (!hasUserTurn) return;
    final lastUser =
        state.messages.lastWhere((m) => m.role == 'user');
    if (lastUser.content.trim().isEmpty) return;
    send(lastUser.content);
  }
}


final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));
