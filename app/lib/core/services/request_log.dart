import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One backend round-trip as seen by the app: enough to debug "why does the
/// home screen show —" without reading device logs.
class RequestLogEntry {
  RequestLogEntry({
    required this.startedAt,
    required this.method,
    required this.path,
    required this.query,
    this.statusCode,
    this.durationMs,
    this.error,
    this.summary,
    this.bytes,
  });

  final DateTime startedAt;
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final int? statusCode;
  final int? durationMs;
  final String? error;

  /// Free-form one-liner: selected source, run, counts.
  final String? summary;
  final int? bytes;

  bool get ok => error == null && (statusCode ?? 0) < 400;

  String get queryString => query.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent('${e.value}')}')
      .join('&');
}

/// Ring buffer of the most recent backend requests.
class RequestLog extends StateNotifier<UnmodifiableListView<RequestLogEntry>> {
  RequestLog() : super(UnmodifiableListView(const []));

  static const _max = 60;
  final _entries = <RequestLogEntry>[];

  /// Global hook so the network layer (no Riverpod access) can record.
  static RequestLog? _active;
  static RequestLog? get active => _active;

  static bool enabled = true;

  void attach() => _active = this;

  void add(RequestLogEntry e) {
    if (!enabled) return;
    _entries.insert(0, e);
    if (_entries.length > _max) _entries.removeRange(_max, _entries.length);
    state = UnmodifiableListView(List.of(_entries));
  }

  void clear() {
    _entries.clear();
    state = UnmodifiableListView(const []);
  }

  static void record(RequestLogEntry e) => _active?.add(e);
}

final requestLogProvider =
    StateNotifierProvider<RequestLog, UnmodifiableListView<RequestLogEntry>>(
  (ref) {
    final log = RequestLog();
    log.attach();
    return log;
  },
);
