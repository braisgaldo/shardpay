import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_text.dart';
import '../../core/receipts/receipt_parser.dart';

/// Resumen honesto de lo que el OCR ha entendido del ticket.
///
/// La versión anterior mostraba siempre el mismo texto («Añadido con OCR»), sin
/// distinguir una lectura perfecta de una a medias. Aquí se dice si la suma
/// cuadra con el total impreso, qué avisos hay y con cuánta confianza se ha
/// leído, para que el usuario sepa si revisar por encima o línea a línea.
class ReceiptScanSummary extends StatelessWidget {
  const ReceiptScanSummary({super.key, required this.scan, required this.currency});

  final ReceiptScan scan;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quality = _quality(scan);
    final accent = _accentColor(scheme, quality);

    final money = NumberFormat.simpleCurrency(locale: localeTag(context), name: currency);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(quality), size: 20, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_headline(context, quality), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (scan.total != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: tr(
                      context,
                      es: 'Total del ticket',
                      en: 'Receipt total',
                      gl: 'Total do ticket',
                      fr: 'Total du ticket',
                      it: 'Totale scontrino',
                      pt: 'Total da fatura',
                    ),
                    value: money.format(scan.total),
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: tr(
                      context,
                      es: 'Suma de líneas',
                      en: 'Sum of lines',
                      gl: 'Suma de liñas',
                      fr: 'Somme des lignes',
                      it: 'Somma delle voci',
                      pt: 'Soma das linhas',
                    ),
                    value: money.format(scan.itemsTotal),
                  ),
                ),
              ],
            ),
          ],
          for (final warning in scan.warnings) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(Icons.info_outline_rounded, size: 15, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(describeReceiptWarning(context, warning), style: theme.textTheme.bodySmall)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  _ScanQuality _quality(ReceiptScan scan) {
    if (scan.reconciled && scan.confidence >= 0.7) {
      return _ScanQuality.good;
    }
    if (scan.items.isEmpty || scan.confidence < 0.35) {
      return _ScanQuality.poor;
    }
    return _ScanQuality.partial;
  }

  Color _accentColor(ColorScheme scheme, _ScanQuality quality) {
    switch (quality) {
      case _ScanQuality.good:
        return scheme.primary;
      case _ScanQuality.partial:
        return scheme.tertiary;
      case _ScanQuality.poor:
        return scheme.error;
    }
  }

  IconData _icon(_ScanQuality quality) {
    switch (quality) {
      case _ScanQuality.good:
        return Icons.check_circle_outline_rounded;
      case _ScanQuality.partial:
        return Icons.rule_rounded;
      case _ScanQuality.poor:
        return Icons.error_outline_rounded;
    }
  }

  String _headline(BuildContext context, _ScanQuality quality) {
    switch (quality) {
      case _ScanQuality.good:
        return tr(
          context,
          es: 'Ticket leído y cuadrado con su total',
          en: 'Receipt read and matched against its total',
          gl: 'Ticket lido e cadrado co seu total',
          fr: 'Ticket lu et rapproché de son total',
          it: 'Scontrino letto e quadrato con il totale',
          pt: 'Fatura lida e conferida com o total',
        );
      case _ScanQuality.partial:
        return tr(
          context,
          es: 'Ticket leído en parte: revisa los importes',
          en: 'Receipt partly read: check the amounts',
          gl: 'Ticket lido en parte: revisa os importes',
          fr: 'Ticket partiellement lu : vérifiez les montants',
          it: 'Scontrino letto in parte: controlla gli importi',
          pt: 'Fatura lida em parte: revê os valores',
        );
      case _ScanQuality.poor:
        return tr(
          context,
          es: 'Casi no se ha podido leer: prueba con más luz',
          en: 'Almost nothing could be read: try with more light',
          gl: 'Case non se puido ler: proba con máis luz',
          fr: 'Presque rien n a pu être lu : essayez avec plus de lumière',
          it: 'Quasi nulla è leggibile: prova con più luce',
          pt: 'Quase nada foi legível: tenta com mais luz',
        );
    }
  }
}

enum _ScanQuality { good, partial, poor }

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// Traduce los avisos que devuelve el parser.
String describeReceiptWarning(BuildContext context, ReceiptWarning warning) {
  switch (warning) {
    case ReceiptWarning.noItemsDetected:
      return tr(
        context,
        es: 'No se reconoció ninguna línea de artículo.',
        en: 'No item line was recognised.',
        gl: 'Non se recoñeceu ningunha liña de artigo.',
        fr: 'Aucune ligne d article n a été reconnue.',
        it: 'Non è stata riconosciuta nessuna voce.',
        pt: 'Não foi reconhecida nenhuma linha de artigo.',
      );
    case ReceiptWarning.totalNotFound:
      return tr(
        context,
        es: 'No se encontró el total impreso, así que no se ha podido comprobar la suma.',
        en: 'The printed total was not found, so the sum could not be checked.',
        gl: 'Non se atopou o total impreso, así que non se puido comprobar a suma.',
        fr: 'Le total imprimé n a pas été trouvé, la somme n a pas pu être vérifiée.',
        it: 'Non è stato trovato il totale stampato, quindi la somma non è stata verificata.',
        pt: 'Não foi encontrado o total impresso, por isso a soma não pôde ser verificada.',
      );
    case ReceiptWarning.itemsDoNotMatchTotal:
      return tr(
        context,
        es: 'Las líneas suman más que el total del ticket.',
        en: 'The lines add up to more than the receipt total.',
        gl: 'As liñas suman máis que o total do ticket.',
        fr: 'Les lignes dépassent le total du ticket.',
        it: 'Le voci sommano più del totale dello scontrino.',
        pt: 'As linhas somam mais do que o total da fatura.',
      );
    case ReceiptWarning.adjustmentAdded:
      return tr(
        context,
        es: 'Se añadió una línea de ajuste para llegar al total pagado.',
        en: 'An adjustment line was added to reach the amount actually paid.',
        gl: 'Engadiuse unha liña de axuste para chegar ao total pagado.',
        fr: 'Une ligne d ajustement a été ajoutée pour atteindre le montant payé.',
        it: 'È stata aggiunta una voce di rettifica per arrivare al totale pagato.',
        pt: 'Foi adicionada uma linha de ajuste para chegar ao total pago.',
      );
    case ReceiptWarning.duplicatedTotalDropped:
      return tr(
        context,
        es: 'Se descartó una línea que repetía el total.',
        en: 'A line that repeated the total was dropped.',
        gl: 'Descartouse unha liña que repetía o total.',
        fr: 'Une ligne qui répétait le total a été écartée.',
        it: 'È stata scartata una riga che ripeteva il totale.',
        pt: 'Foi descartada uma linha que repetia o total.',
      );
    case ReceiptWarning.lowTextQuality:
      return tr(
        context,
        es: 'Se leyó poco texto. Prueba con más luz, sin sombras y con el ticket estirado.',
        en: 'Little text was read. Try with more light, no shadows and the receipt flattened.',
        gl: 'Leuse pouco texto. Proba con máis luz, sen sombras e co ticket estirado.',
        fr: 'Peu de texte a été lu. Essayez avec plus de lumière, sans ombre et le ticket bien à plat.',
        it: 'È stato letto poco testo. Prova con più luce, senza ombre e con lo scontrino disteso.',
        pt: 'Foi lido pouco texto. Tenta com mais luz, sem sombras e com a fatura esticada.',
      );
    case ReceiptWarning.totalCorrectedByArithmetic:
      return tr(
        context,
        es: 'El total impreso no cuadraba con el subtotal más los impuestos. Se ha usado la suma del propio ticket; compruébalo.',
        en: 'The printed total did not match the subtotal plus taxes. The receipt\u2019s own arithmetic was used; please check it.',
        gl: 'O total impreso non cadraba co subtotal máis os impostos. Usouse a suma do propio ticket; compróbao.',
        ca: 'El total imprès no quadrava amb el subtotal més els impostos. S\u2019ha fet servir la suma del mateix tiquet; comprova-ho.',
        eu: 'Inprimatutako guztizkoa ez zetorren bat subtotalarekin gehi zergekin. Tiketaren beraren batuketa erabili da; egiaztatu.',
        fr: 'Le total imprimé ne correspondait pas au sous-total plus les taxes. La somme du ticket lui-même a été utilisée ; vérifiez-la.',
        it: 'Il totale stampato non tornava con il subtotale più le imposte. È stata usata la somma dello scontrino stesso; controllala.',
        pt: 'O total impresso não batia certo com o subtotal mais os impostos. Usou-se a soma da própria fatura; confirma.',
        de: 'Die gedruckte Summe passte nicht zu Zwischensumme plus Steuern. Es wurde die Rechnung des Belegs selbst verwendet; bitte prüfen.',
        el: 'Το εκτυπωμένο σύνολο δεν συμφωνούσε με το μερικό σύνολο συν τους φόρους. Χρησιμοποιήθηκε το άθροισμα της ίδιας της απόδειξης· έλεγξέ το.',
        ru: 'Напечатанный итог не сходился с подытогом плюс налоги. Использована арифметика самого чека; проверьте.',
        ar: 'الإجمالي المطبوع لا يتطابق مع المجموع الفرعي زائد الضرائب. استُخدم حساب الإيصال نفسه؛ تحقق منه.',
        zh: '打印的合计与小计加税额对不上。已改用小票自身的算式，请核对。',
        ja: '印字された合計が小計＋税と一致しませんでした。レシート自身の計算を使っています。確認してください。',
      );
  }
}
