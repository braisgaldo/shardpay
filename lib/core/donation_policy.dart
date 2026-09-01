/// Cuándo se puede enseñar el aviso de «invítame a un café», y cuándo no.
///
/// Dart puro y con pruebas porque esto es exactamente el tipo de regla que se
/// escribe una vez, no se vuelve a mirar y acaba molestando a la gente en cada
/// arranque. Aquí queda fijada y comprobada.
///
/// Las reglas, tal cual:
///
/// * Nunca en el arranque en frío ni encima de una tarea a medias: solo al
///   cerrar una sesión en la que el usuario haya hecho algo real.
/// * La primera vez, una sola vez.
/// * Si dice «Ahora no», puede volver a aparecer **una única vez más**, y solo
///   cuando hayan pasado 30 días **y** haya usado la app 10 veces más.
/// * Después, silencio permanente.
/// * «No volver a mostrar» es definitivo e inmediato.
///
/// En ShardPay, «uso real» es crear un gasto, importar un ticket o registrar un
/// reembolso. Abrir la app y mirar los saldos no cuenta.
library;

/// Estado persistente del aviso de donación.
///
/// Viaja en la exportación de datos a propósito: reinstalar la app no debe
/// hacer que alguien que ya dijo que no vuelva a ver el aviso.
class DonationState {
  const DonationState({
    this.dismissedForever = false,
    this.promptCount = 0,
    this.lastPromptAt,
    this.realUseCount = 0,
    this.realUseCountAtLastPrompt = 0,
  });

  /// El usuario pulsó «No volver a mostrar», o ya visitó el enlace.
  final bool dismissedForever;

  /// Cuántas veces se ha enseñado el aviso.
  final int promptCount;

  final DateTime? lastPromptAt;

  /// Número acumulado de usos reales.
  final int realUseCount;

  /// Usos reales que había cuando se enseñó el aviso por última vez.
  final int realUseCountAtLastPrompt;

  DonationState copyWith({
    bool? dismissedForever,
    int? promptCount,
    DateTime? lastPromptAt,
    int? realUseCount,
    int? realUseCountAtLastPrompt,
  }) {
    return DonationState(
      dismissedForever: dismissedForever ?? this.dismissedForever,
      promptCount: promptCount ?? this.promptCount,
      lastPromptAt: lastPromptAt ?? this.lastPromptAt,
      realUseCount: realUseCount ?? this.realUseCount,
      realUseCountAtLastPrompt: realUseCountAtLastPrompt ?? this.realUseCountAtLastPrompt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'dismissedForever': dismissedForever,
    'promptCount': promptCount,
    'lastPromptAt': lastPromptAt?.toIso8601String(),
    'realUseCount': realUseCount,
    'realUseCountAtLastPrompt': realUseCountAtLastPrompt,
  };

  factory DonationState.fromJson(Map<String, Object?> json) {
    return DonationState(
      dismissedForever: json['dismissedForever'] as bool? ?? false,
      promptCount: (json['promptCount'] as num?)?.toInt() ?? 0,
      lastPromptAt: DateTime.tryParse(json['lastPromptAt'] as String? ?? ''),
      realUseCount: (json['realUseCount'] as num?)?.toInt() ?? 0,
      realUseCountAtLastPrompt: (json['realUseCountAtLastPrompt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Política de aparición del aviso.
class DonationPolicy {
  const DonationPolicy({this.maxPrompts = 2, this.cooldown = const Duration(days: 30), this.usesBetweenPrompts = 10});

  /// Veces que se puede enseñar el aviso en toda la vida de la instalación.
  final int maxPrompts;

  /// Tiempo mínimo entre el primer aviso y el segundo.
  final Duration cooldown;

  /// Usos reales mínimos entre el primer aviso y el segundo.
  final int usesBetweenPrompts;

  /// ¿Toca enseñar el aviso ahora?
  ///
  /// [sessionHadRealUse] tiene que ser cierto: el aviso se enseña al cerrar una
  /// sesión productiva, nunca al abrir la app.
  bool shouldPrompt({required DonationState state, required DateTime now, required bool sessionHadRealUse}) {
    if (state.dismissedForever) {
      return false;
    }
    if (!sessionHadRealUse || state.realUseCount < 1) {
      return false;
    }
    if (state.promptCount >= maxPrompts) {
      return false;
    }
    if (state.promptCount == 0) {
      return true;
    }

    final lastPromptAt = state.lastPromptAt;
    if (lastPromptAt == null) {
      return false;
    }
    if (now.difference(lastPromptAt) < cooldown) {
      return false;
    }
    return state.realUseCount - state.realUseCountAtLastPrompt >= usesBetweenPrompts;
  }

  /// Estado tras enseñar el aviso.
  DonationState afterPrompt(DonationState state, DateTime now) {
    return state.copyWith(promptCount: state.promptCount + 1, lastPromptAt: now, realUseCountAtLastPrompt: state.realUseCount);
  }

  /// Estado tras registrar un uso real.
  DonationState afterRealUse(DonationState state) {
    return state.copyWith(realUseCount: state.realUseCount + 1);
  }

  /// Estado tras «No volver a mostrar» o tras visitar el enlace.
  DonationState afterDismissForever(DonationState state) {
    return state.copyWith(dismissedForever: true);
  }
}
