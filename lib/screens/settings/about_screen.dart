import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_text.dart';
import '../../core/app_info.dart';
import '../../widgets/brand_mark.dart';

/// «Acerca de»: versión, compilación, licencia, privacidad y contacto.
///
/// Sirve para dos cosas concretas: que cualquiera pueda decir exactamente qué
/// versión tiene instalada cuando reporta un fallo, y que las obligaciones
/// legales de la ficha de tienda —licencia, licencias de terceros y política de
/// privacidad— estén accesibles desde dentro de la app.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, es: 'Acerca de', en: 'About', gl: 'Acerca de', fr: 'À propos', it: 'Informazioni', pt: 'Acerca de')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                const ShardPayBrandMark(size: 72),
                const SizedBox(height: 12),
                Text('ShardPay', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  tr(
                    context,
                    es: 'Divide tickets, no amistades.',
                    en: 'Split receipts, not friendships.',
                    gl: 'Divide tickets, non amizades.',
                    fr: 'Partage les tickets, pas les amitiés.',
                    it: 'Dividi gli scontrini, non le amicizie.',
                    pt: 'Divide faturas, não amizades.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                _InfoRow(
                  label: tr(context, es: 'Versión', en: 'Version', gl: 'Versión', fr: 'Version', it: 'Versione', pt: 'Versão'),
                  value: AppInfo.version,
                ),
                _InfoRow(
                  label: tr(context, es: 'Compilación', en: 'Build', gl: 'Compilación', fr: 'Build', it: 'Build', pt: 'Compilação'),
                  value: AppInfo.buildNumber,
                ),
                _InfoRow(
                  label: tr(context, es: 'Commit', en: 'Commit', gl: 'Commit', fr: 'Commit', it: 'Commit', pt: 'Commit'),
                  value: AppInfo.commit,
                  copyable: true,
                ),
                if (AppInfo.buildDate.isNotEmpty)
                  _InfoRow(
                    label: tr(
                      context,
                      es: 'Fecha de compilación',
                      en: 'Build date',
                      gl: 'Data de compilación',
                      fr: 'Date de compilation',
                      it: 'Data di build',
                      pt: 'Data de compilação',
                    ),
                    value: AppInfo.buildDate,
                  ),
                _InfoRow(
                  label: tr(context, es: 'Licencia', en: 'Licence', gl: 'Licenza', fr: 'Licence', it: 'Licenza', pt: 'Licença'),
                  value: AppInfo.license,
                ),
                _InfoRow(
                  label: tr(
                    context,
                    es: 'Identificador',
                    en: 'Application ID',
                    gl: 'Identificador',
                    fr: 'Identifiant',
                    it: 'Identificativo',
                    pt: 'Identificador',
                  ),
                  value: AppInfo.applicationId,
                  copyable: true,
                ),
              ],
            ),
          ),
          if (!AppInfo.isReleaseBuild) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: theme.colorScheme.tertiary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Text(
                tr(
                  context,
                  es: 'Esta es una compilación local, no una versión publicada.',
                  en: 'This is a local build, not a published release.',
                  gl: 'Esta é unha compilación local, non unha versión publicada.',
                  fr: 'Ceci est une compilation locale, pas une version publiée.',
                  it: 'Questa è una build locale, non una versione pubblicata.',
                  pt: 'Esta é uma compilação local, não uma versão publicada.',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _LinkTile(
            icon: Icons.privacy_tip_outlined,
            label: tr(
              context,
              es: 'Política de privacidad',
              en: 'Privacy policy',
              gl: 'Política de privacidade',
              fr: 'Politique de confidentialité',
              it: 'Informativa sulla privacy',
              pt: 'Política de privacidade',
            ),
            url: AppInfo.privacyPolicyUrl,
          ),
          _LinkTile(
            icon: Icons.code_rounded,
            label: tr(
              context,
              es: 'Código fuente',
              en: 'Source code',
              gl: 'Código fonte',
              fr: 'Code source',
              it: 'Codice sorgente',
              pt: 'Código-fonte',
            ),
            url: AppInfo.repositoryUrl,
          ),
          _LinkTile(
            icon: Icons.public_rounded,
            label: tr(
              context,
              es: 'Página del proyecto',
              en: 'Project page',
              gl: 'Páxina do proxecto',
              fr: 'Page du projet',
              it: 'Pagina del progetto',
              pt: 'Página do projeto',
            ),
            url: AppInfo.projectPageUrl,
          ),
          _LinkTile(
            icon: Icons.mail_outline_rounded,
            label: tr(context, es: 'Contacto', en: 'Contact', gl: 'Contacto', fr: 'Contact', it: 'Contatti', pt: 'Contacto'),
            url: 'mailto:${AppInfo.contactEmail}',
            displayValue: AppInfo.contactEmail,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: Text(
              tr(
                context,
                es: 'Licencias de terceros',
                en: 'Third-party licences',
                gl: 'Licenzas de terceiros',
                fr: 'Licences tierces',
                it: 'Licenze di terze parti',
                pt: 'Licenças de terceiros',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'ShardPay',
              applicationVersion: '${AppInfo.version} (${AppInfo.buildNumber})',
              applicationLegalese: '© 2026 Brais Castiñeiras Galdo · ${AppInfo.license}',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.copyable = false});

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (copyable) ...[
            const SizedBox(width: 4),
            IconButton(
              iconSize: 18,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: tr(context, es: 'Copiar', en: 'Copy', gl: 'Copiar', fr: 'Copier', it: 'Copia', pt: 'Copiar'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr(context, es: 'Copiado.', en: 'Copied.', gl: 'Copiado.', fr: 'Copié.', it: 'Copiato.', pt: 'Copiado.')),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.url, this.displayValue});

  final IconData icon;
  final String label;
  final String url;
  final String? displayValue;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: displayValue == null ? null : Text(displayValue!),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
