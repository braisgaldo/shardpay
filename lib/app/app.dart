import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'app_text.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/home/home_shell.dart';
import 'providers.dart';
import 'theme.dart';

class ShardPayApp extends ConsumerWidget {
  const ShardPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final activeTheme = buildShardPayTheme(preferences.theme);
    Intl.defaultLocale = preferences.language.locale.toLanguageTag();

    return MaterialApp(
      title: 'ShardPay',
      debugShowCheckedModeBanner: false,
      theme: activeTheme,
      darkTheme: activeTheme,
      themeMode: ThemeMode.light,
      locale: preferences.language.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
        Locale('gl'),
        Locale('fr'),
        Locale('it'),
        Locale('pt'),
        Locale('de'),
        Locale('ru'),
        Locale('zh'),
        Locale('ja'),
      ],
      home: authState.when(
        data: (user) => user == null ? const AuthScreen() : HomeShell(user: user),
        error: (error, _) => _BootstrapErrorView(error: error),
        loading: () => const _SplashView(),
      ),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF101522), Color(0xFF18263B), Color(0xFFE4572E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 20),
              Text(
                'ShardPay',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  es: 'Divide tickets, no amistades.',
                  en: 'Split receipts, not friendships.',
                  gl: 'Divide tickets, non amizades.',
                  fr: 'Partage les tickets, pas les amities.',
                  it: 'Dividi gli scontrini, non le amicizie.',
                  pt: 'Divide faturas, nao amizades.',
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorView extends StatelessWidget {
  const _BootstrapErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                tr(
                  context,
                  es: 'No se pudo arrancar ShardPay',
                  en: 'ShardPay could not start',
                  gl: 'Non se puido iniciar ShardPay',
                  fr: 'Impossible de lancer ShardPay',
                  it: 'Impossibile avviare ShardPay',
                  pt: 'Nao foi possivel iniciar o ShardPay',
                ),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}