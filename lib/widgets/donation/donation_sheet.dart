import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_text.dart';
import '../../app/providers.dart';
import '../../core/donation_config.dart';
import 'coffee_cup_illustration.dart';

/// Panel de «invítame a un café».
///
/// Es un bottom sheet modal y no un diálogo del sistema ni una pantalla
/// completa: tiene que poder ignorarse de un gesto. El texto es corto, en
/// primera persona y sin culpabilizar; no hay cuenta atrás, ni insistencia, ni
/// nada que se desbloquee al pagar.
///
/// Ojo con el vocabulario: aquí no aparecen las palabras *comprar*, *pagar*,
/// *desbloquear*, *pro*, *premium*, *suscripción* ni *precio*. No es un capricho
/// de estilo, es lo que sostiene que esto no sea una compra integrada.
Future<void> showDonationSheet(BuildContext context, WidgetRef ref, {bool fromSettings = false}) async {
  if (!DonationConfig.isEnabled) {
    return;
  }

  if (!fromSettings) {
    // Si el panel sale solo, cuenta como una de las dos apariciones que tiene
    // permitidas en toda la vida de la instalación.
    ref.read(appPreferencesProvider.notifier).markDonationPromptShown();
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (sheetContext) => _DonationSheet(fromSettings: fromSettings),
  );
}

class _DonationSheet extends ConsumerStatefulWidget {
  const _DonationSheet({required this.fromSettings});

  final bool fromSettings;

  @override
  ConsumerState<_DonationSheet> createState() => _DonationSheetState();
}

class _DonationSheetState extends ConsumerState<_DonationSheet> {
  bool _showQr = false;
  bool _visited = false;

  Future<void> _openDonationLink() async {
    await HapticFeedback.lightImpact();

    final uri = Uri.parse(DonationConfig.effectiveUrl);
    var opened = false;
    try {
      // `inAppBrowserView` son las Custom Tabs en Android y el
      // SFSafariViewController en iOS: el navegador del sistema, con su barra
      // de direcciones a la vista. Nunca un WebView incrustado, porque eso sí
      // parecería una pasarela dentro de la app.
      opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }

    if (!mounted) {
      return;
    }

    if (!opened) {
      _showSnack(
        tr(
          context,
          es: 'No se pudo abrir el navegador. Puedes copiar el enlace.',
          en: 'The browser could not be opened. You can copy the link instead.',
          gl: 'Non se puido abrir o navegador. Podes copiar a ligazón.',
          fr: 'Impossible d ouvrir le navigateur. Vous pouvez copier le lien.',
          it: 'Non è stato possibile aprire il browser. Puoi copiare il link.',
          pt: 'Não foi possível abrir o navegador. Podes copiar a ligação.',
        ),
      );
      return;
    }

    // No se afirma en ningún momento que el pago se haya hecho: no hay forma
    // de comprobarlo desde aquí y decirlo sería mentir.
    ref.read(appPreferencesProvider.notifier).dismissDonationForever();
    setState(() => _visited = true);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(const ClipboardData(text: DonationConfig.url));
    if (!mounted) {
      return;
    }
    _showSnack(
      tr(
        context,
        es: 'Enlace copiado.',
        en: 'Link copied.',
        gl: 'Ligazón copiada.',
        fr: 'Lien copié.',
        it: 'Link copiato.',
        pt: 'Ligação copiada.',
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _dismissForever() {
    ref.read(appPreferencesProvider.notifier).dismissDonationForever();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final amount = NumberFormat.simpleCurrency(
      locale: localeTag(context),
      name: DonationConfig.currencyCode,
      decimalDigits: 0,
    ).format(DonationConfig.suggestedAmount);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Entrada escalonada: la ilustración, el título, el texto y los
          // botones aparecen con 40 ms de desfase entre ellos.
          _Staggered(
            index: 0,
            reduceMotion: reduceMotion,
            child: CoffeeCupIllustration(
              size: 128,
              semanticsLabel: tr(
                context,
                es: 'Ilustración de una taza de café con vapor',
                en: 'Illustration of a coffee cup with steam',
                gl: 'Ilustración dunha cunca de café con vapor',
                fr: 'Illustration d une tasse de café fumante',
                it: 'Illustrazione di una tazza di caffè con vapore',
                pt: 'Ilustração de uma chávena de café com vapor',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Staggered(
            index: 1,
            reduceMotion: reduceMotion,
            child: Text(
              _visited
                  ? tr(
                      context,
                      es: 'Gracias por pasarte por ahí',
                      en: 'Thanks for stopping by',
                      gl: 'Grazas por pasar por alí',
                      fr: 'Merci d y être passé',
                      it: 'Grazie per essere passato di lì',
                      pt: 'Obrigado por lá passares',
                    )
                  : tr(
                      context,
                      es: '¿Te invito yo o me invitas tú?',
                      en: 'Fancy buying me a coffee?',
                      gl: 'Convídasme a un café?',
                      fr: 'Vous m offrez un café ?',
                      it: 'Mi offri un caffè?',
                      pt: 'Ofereces-me um café?',
                    ),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          _Staggered(
            index: 2,
            reduceMotion: reduceMotion,
            child: Text(
              _visited
                  ? tr(
                      context,
                      es: 'No sé si has llegado a hacerlo, y da igual: la app sigue siendo la misma para todo el mundo.',
                      en: 'I have no way of knowing whether you went through with it, and it does not matter: the app stays the same for everyone.',
                      gl: 'Non sei se chegaches a facelo, e dá igual: a app segue sendo a mesma para todo o mundo.',
                      fr: 'Je ne sais pas si vous êtes allé au bout, et peu importe : l application reste la même pour tout le monde.',
                      it: 'Non so se lo hai fatto davvero, e non importa: l app resta la stessa per tutti.',
                      pt: 'Não sei se chegaste a fazê-lo, e não importa: a app continua igual para toda a gente.',
                    )
                  : tr(
                      context,
                      es: 'Esta app es gratuita, sin anuncios y no recoge tus datos. Si te resulta útil, puedes invitarme a un café.',
                      en: 'This app is free, has no ads and does not collect your data. If you find it useful, you can buy me a coffee.',
                      gl: 'Esta app é gratuíta, sen anuncios e non recolle os teus datos. Se che resulta útil, podes convidarme a un café.',
                      fr: 'Cette application est gratuite, sans publicité et ne collecte pas vos données. Si elle vous sert, vous pouvez m offrir un café.',
                      it: 'Questa app è gratuita, senza pubblicità e non raccoglie i tuoi dati. Se ti è utile, puoi offrirmi un caffè.',
                      pt: 'Esta app é gratuita, sem anúncios e não recolhe os teus dados. Se te for útil, podes oferecer-me um café.',
                    ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 22),
          if (!_visited)
            _Staggered(
              index: 3,
              reduceMotion: reduceMotion,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openDonationLink,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  icon: const Icon(Icons.local_cafe_rounded),
                  label: Text(
                    tr(
                      context,
                      es: 'Invítame a un café · $amount',
                      en: 'Buy me a coffee · $amount',
                      gl: 'Convídame a un café · $amount',
                      fr: 'Offrez-moi un café · $amount',
                      it: 'Offrimi un caffè · $amount',
                      pt: 'Oferece-me um café · $amount',
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          _Staggered(
            index: 4,
            reduceMotion: reduceMotion,
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showQr = !_showQr),
                  icon: Icon(_showQr ? Icons.expand_less_rounded : Icons.qr_code_2_rounded, size: 20),
                  label: Text(
                    tr(
                      context,
                      es: 'Desde otro dispositivo',
                      en: 'From another device',
                      gl: 'Desde outro dispositivo',
                      fr: 'Depuis un autre appareil',
                      it: 'Da un altro dispositivo',
                      pt: 'A partir de outro dispositivo',
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 220),
                  curve: Curves.easeOut,
                  child: _showQr ? _QrPanel(onCopy: _copyLink) : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _Staggered(
            index: 5,
            reduceMotion: reduceMotion,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    _visited
                        ? tr(context, es: 'Cerrar', en: 'Close', gl: 'Pechar', fr: 'Fermer', it: 'Chiudi', pt: 'Fechar')
                        : tr(context, es: 'Ahora no', en: 'Not now', gl: 'Agora non', fr: 'Pas maintenant', it: 'Non ora', pt: 'Agora não'),
                  ),
                ),
                if (!_visited && !widget.fromSettings) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _dismissForever,
                    child: Text(
                      tr(
                        context,
                        es: 'No volver a mostrar',
                        en: 'Do not show again',
                        gl: 'Non amosar máis',
                        fr: 'Ne plus afficher',
                        it: 'Non mostrare più',
                        pt: 'Não mostrar mais',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Código QR del enlace, generado en local y sin red.
class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // El QR se pinta con los colores del tema, pero manteniendo el contraste
    // que necesita para poder escanearse: módulos oscuros sobre fondo claro,
    // nunca al revés y nunca con dos tonos parecidos.
    final isDarkSurface = ThemeData.estimateBrightnessForColor(scheme.surface) == Brightness.dark;
    final background = isDarkSurface ? Colors.white : scheme.surface;
    final foreground = isDarkSurface ? scheme.surface : scheme.onSurface;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
          child: Semantics(
            image: true,
            label: tr(
              context,
              es: 'Código QR con el enlace para invitar a un café',
              en: 'QR code with the link to buy a coffee',
              gl: 'Código QR coa ligazón para convidar a un café',
              fr: 'Code QR avec le lien pour offrir un café',
              it: 'Codice QR con il link per offrire un caffè',
              pt: 'Código QR com a ligação para oferecer um café',
            ),
            child: QrImageView(
              data: DonationConfig.url,
              version: QrVersions.auto,
              size: 168,
              backgroundColor: background,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: foreground),
              dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: foreground),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: Text(
            tr(
              context,
              es: 'Copiar enlace',
              en: 'Copy link',
              gl: 'Copiar ligazón',
              fr: 'Copier le lien',
              it: 'Copia il link',
              pt: 'Copiar ligação',
            ),
          ),
        ),
      ],
    );
  }
}

/// Aparición escalonada de un elemento del panel.
class _Staggered extends StatelessWidget {
  const _Staggered({required this.index, required this.child, required this.reduceMotion});

  final int index;
  final Widget child;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - value) * 16), child: child),
        );
      },
      child: child,
    );
  }
}
