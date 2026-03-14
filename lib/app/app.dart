import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'app_text.dart';
import '../models/app_models.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/home/home_shell.dart';
import 'providers.dart';
import 'theme.dart';

class ShardPayApp extends ConsumerStatefulWidget {
  const ShardPayApp({super.key});

  @override
  ConsumerState<ShardPayApp> createState() => _ShardPayAppState();
}

class _ShardPayAppState extends ConsumerState<ShardPayApp> {
  ProviderSubscription<AsyncValue<AppUser?>>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AsyncValue<AppUser?>>(authStateProvider, (previous, next) async {
      final fcmService = ref.read(fcmServiceProvider);
      final user = next.valueOrNull;
      if (fcmService == null) {
        return;
      }
      if (user == null) {
        await fcmService.dispose();
        return;
      }
      try {
        await fcmService.initializeForUser(user);
      } catch (_) {}
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF4EA), Color(0xFFFFD8B0), Color(0xFFFFA65A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pulse = 0.96 + ((0.5 - (_controller.value - 0.5).abs()) * 0.12);
            final drift = (_controller.value - 0.5) * 24;
            return Stack(
              children: [
                Positioned(left: -38 + drift, top: -12, child: const _SplashOrb(size: 220, color: Color(0x66FFA15A))),
                Positioned(right: -22, top: 92 - drift * 0.4, child: const _SplashOrb(size: 180, color: Color(0x55FFD394))),
                Positioned(left: 22, bottom: 84 - drift * 0.5, child: const _SplashOrb(size: 150, color: Color(0x44FFB178))),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: pulse,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 170,
                              height: 170,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x24FF9B52)),
                            ),
                            Transform.rotate(
                              angle: _controller.value * 0.7,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0x33FF8624), width: 1.5),
                                ),
                              ),
                            ),
                            Container(
                              width: 126,
                              height: 126,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(34),
                                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 28, offset: Offset(0, 18))],
                              ),
                              child: const _BrandGlyph(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'ShardPay',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(color: const Color(0xFF7C2D06), fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF9A5A20)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 140,
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: Colors.white.withValues(alpha: 0.6),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7A1A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SplashOrb extends StatelessWidget {
  const _SplashOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

class _BrandGlyph extends StatelessWidget {
  const _BrandGlyph();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.asset(
        'assets/branding/app_icon.png',
        width: 80,
        height: 80,
        fit: BoxFit.cover,
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