import 'package:flutter/material.dart';

/// Sección plegable de Ajustes.
///
/// Antes cada sección se dibujaba entera y siempre: las trece paletas y los
/// catorce idiomas ocupaban dos pantallas de recorrido antes de llegar a
/// «Tus datos». Ahora cada sección se resume en una línea con su valor actual y
/// solo se despliega la que interesa.
///
/// El resumen del encabezado no es decorativo: enseña **el valor activo** —la
/// paleta elegida, el idioma, cuántos avisos hay encendidos— para que en muchos
/// casos ni haga falta abrirla.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;

  /// Valor activo, en una línea.
  final String summary;

  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // `ExpansionTile` pinta una línea divisoria propia que rompe la tarjeta.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsetsDirectional.only(start: 18, end: 12),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 21, color: theme.colorScheme.primary),
          ),
          title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          subtitle: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          children: children,
        ),
      ),
    );
  }
}

/// Fila de una sección: etiqueta a un lado y control al otro.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.label, required this.child, this.help});

  final String label;
  final String? help;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (help != null) ...[
            const SizedBox(height: 2),
            Text(help!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
