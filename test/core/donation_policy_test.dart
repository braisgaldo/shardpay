import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/donation_policy.dart';

void main() {
  const policy = DonationPolicy();
  final now = DateTime(2026, 8, 31, 22);

  group('DonationPolicy', () {
    test('no aparece al abrir la app, solo al cerrar una sesion productiva', () {
      const state = DonationState(realUseCount: 3);

      expect(policy.shouldPrompt(state: state, now: now, sessionHadRealUse: false), isFalse);
      expect(policy.shouldPrompt(state: state, now: now, sessionHadRealUse: true), isTrue);
    });

    test('no aparece si el usuario no ha hecho nada real todavia', () {
      const state = DonationState();
      expect(policy.shouldPrompt(state: state, now: now, sessionHadRealUse: true), isFalse);
    });

    test('«No volver a mostrar» es definitivo', () {
      final state = policy.afterDismissForever(const DonationState(realUseCount: 40, promptCount: 1));
      expect(policy.shouldPrompt(state: state, now: now.add(const Duration(days: 900)), sessionHadRealUse: true), isFalse);
    });

    test('tras un «Ahora no» hacen falta 30 dias y 10 usos mas', () {
      final first = policy.afterPrompt(const DonationState(realUseCount: 1), now);

      // Justo despues: no.
      expect(policy.shouldPrompt(state: first, now: now, sessionHadRealUse: true), isFalse);

      // Pasan 30 dias pero solo hay 5 usos mas: no.
      final pocosUsos = first.copyWith(realUseCount: 6);
      expect(policy.shouldPrompt(state: pocosUsos, now: now.add(const Duration(days: 31)), sessionHadRealUse: true), isFalse);

      // Hay 10 usos mas pero solo han pasado 10 dias: no.
      final pocoTiempo = first.copyWith(realUseCount: 11);
      expect(policy.shouldPrompt(state: pocoTiempo, now: now.add(const Duration(days: 10)), sessionHadRealUse: true), isFalse);

      // Las dos condiciones: si.
      expect(policy.shouldPrompt(state: pocoTiempo, now: now.add(const Duration(days: 31)), sessionHadRealUse: true), isTrue);
    });

    test('nunca aparece una tercera vez', () {
      var state = policy.afterPrompt(const DonationState(realUseCount: 1), now);
      state = state.copyWith(realUseCount: 40);
      state = policy.afterPrompt(state, now.add(const Duration(days: 31)));
      state = state.copyWith(realUseCount: 400);

      expect(policy.shouldPrompt(state: state, now: now.add(const Duration(days: 4000)), sessionHadRealUse: true), isFalse);
    });

    test('el estado sobrevive a la ida y vuelta por JSON', () {
      final state = DonationState(
        dismissedForever: true,
        promptCount: 2,
        lastPromptAt: DateTime.utc(2026, 1, 2, 3, 4),
        realUseCount: 17,
        realUseCountAtLastPrompt: 7,
      );

      final restored = DonationState.fromJson(state.toJson());

      expect(restored.dismissedForever, isTrue);
      expect(restored.promptCount, 2);
      expect(restored.lastPromptAt, DateTime.utc(2026, 1, 2, 3, 4));
      expect(restored.realUseCount, 17);
      expect(restored.realUseCountAtLastPrompt, 7);
    });

    test('un estado recien estrenado se lee sin datos', () {
      final restored = DonationState.fromJson(const <String, Object?>{});
      expect(restored.dismissedForever, isFalse);
      expect(restored.promptCount, 0);
      expect(restored.lastPromptAt, isNull);
      expect(restored.realUseCount, 0);
    });
  });
}
