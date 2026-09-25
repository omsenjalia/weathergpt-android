import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weathergpt_mobile/features/chat/providers/chat_provider.dart';
import 'package:weathergpt_mobile/features/chat/screens/chat_screen.dart';
import 'package:weathergpt_mobile/features/home/providers/atmosphere_provider.dart';
import 'package:weathergpt_mobile/features/home/theme/atmosphere_theme.dart';

/// Regression harness for the "gray box while chatting" bug.
///
/// The typing indicator's AnimationController used `..repeat()` with NO
/// duration. The null-period check inside `AnimationController.repeat` lives
/// inside an `assert`, so debug/test runs threw
/// "AnimationController.repeat() called without an explicit period…" the
/// moment the indicator mounted — the same crash that, in release builds,
/// rendered Flutter's opaque gray 400×400 error slab in place of the chat
/// while the assistant was thinking. This test mounts the chat screen with a
/// pending send and fails on any build exception.
class _SendingNotifier extends ChatNotifier {
  _SendingNotifier(super.ref);

  @override
  ChatState get state => ChatState(
        sending: true,
        messages: [ChatMessage(role: 'user', content: 'Show 7 day forecast')],
      );

  @override
  Future<void> send(String text) async {}
}

void main() {
  testWidgets(
    'chat screen with a pending send renders the typing indicator without '
    'exceptions (regression: durationless repeat() crashed initState in '
    'release → gray error slab)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatProvider.overrideWith(_SendingNotifier.new),
            atmospherePaletteProvider.overrideWithValue(
              paletteFor(SkyPeriod.midday, SkyCondition.clear),
            ),
          ],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      // One frame mounts the typing indicator (sending == true, one user
      // message). Any exception here reproduces the device gray box.
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Let the repeat animation tick past one full period; still no
      // exception, and the user's message is still on screen.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(tester.takeException(), isNull);
      expect(find.text('Show 7 day forecast'), findsOneWidget);
    },
  );
}
