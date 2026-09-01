import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_text.dart';
import '../../core/sample_ledger.dart';

/// Tabla del grupo de ejemplo: quién pagó qué.
///
/// Las cifras salen de `lib/core/sample_ledger.dart` y están comprobadas contra
/// el motor de cálculo real, así que lo que se enseña aquí es exactamente lo que
/// la app haría con esos gastos.
class TourExpensesExample extends StatelessWidget {
  const TourExpensesExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dinero = NumberFormat.simpleCurrency(locale: localeTag(context), name: 'EUR');

    return _MarcoEjemplo(
      title: 'Roadtrip Costa · ${sampleMemberNames.length} personas',
      child: Column(
        children: [
          for (final fila in sampleExpenseRows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(fila.concept, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      fila.payer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text(dinero.format(fila.amount), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const Divider(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(
                    context,
                    es: 'Total del grupo',
                    en: 'Group total',
                    gl: 'Total do grupo',
                    ca: 'Total del grup',
                    eu: 'Taldearen guztizkoa',
                    fr: 'Total du groupe',
                    it: 'Totale del gruppo',
                    pt: 'Total do grupo',
                    de: 'Gruppensumme',
                    el: 'Σύνολο ομάδας',
                    ru: 'Итого по группе',
                    ar: 'إجمالي المجموعة',
                    zh: '群组合计',
                    ja: 'グループ合計',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                dinero.format(sampleTotalSpend),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Saldos del grupo de ejemplo: a quién le deben y quién debe.
class TourBalancesExample extends StatelessWidget {
  const TourBalancesExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dinero = NumberFormat.simpleCurrency(locale: localeTag(context), name: 'EUR');

    return _MarcoEjemplo(
      title: tr(
        context,
        es: 'Cómo queda el grupo',
        en: 'How the group ends up',
        gl: 'Como queda o grupo',
        ca: 'Com queda el grup',
        eu: 'Nola geratzen den taldea',
        fr: 'Où en est le groupe',
        it: 'Come resta il gruppo',
        pt: 'Como fica o grupo',
        de: 'Wie die Gruppe dasteht',
        el: 'Πώς μένει η ομάδα',
        ru: 'Что получается в группе',
        ar: 'كيف تنتهي المجموعة',
        zh: '群组结果',
        ja: 'グループの結果',
      ),
      child: Column(
        children: [
          for (final entrada in sampleNetBalances.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    entrada.value >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 16,
                    color: entrada.value >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entrada.key, style: theme.textTheme.bodySmall)),
                  Text(
                    entrada.value >= 0
                        ? tr(
                            context,
                            es: 'le deben',
                            en: 'is owed',
                            gl: 'débenlle',
                            ca: 'li deuen',
                            eu: 'zor diote',
                            fr: 'on lui doit',
                            it: 'gli devono',
                            pt: 'devem-lhe',
                            de: 'bekommt',
                            el: 'του χρωστούν',
                            ru: 'ему должны',
                            ar: 'له',
                            zh: '应收',
                            ja: '受取',
                          )
                        : tr(
                            context,
                            es: 'debe',
                            en: 'owes',
                            gl: 'debe',
                            ca: 'deu',
                            eu: 'zor du',
                            fr: 'doit',
                            it: 'deve',
                            pt: 'deve',
                            de: 'schuldet',
                            el: 'χρωστάει',
                            ru: 'должен',
                            ar: 'عليه',
                            zh: '应付',
                            ja: '支払',
                          ),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dinero.format(entrada.value.abs()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: entrada.value >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Las deudas directas del grupo de ejemplo, antes de cruzarlas.
///
/// Es la vista que sale al tocar a una persona en «Balance». Enseñarla junto a
/// [TourSettlementExample] es la forma más rápida de que se entienda qué hace
/// exactamente el botón de liquidar: cinco deudas sueltas se convierten en dos
/// pagos sin que nadie gane ni pierda un céntimo.
class TourDirectDebtsExample extends StatelessWidget {
  const TourDirectDebtsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dinero = NumberFormat.simpleCurrency(locale: localeTag(context), name: 'EUR');

    return _MarcoEjemplo(
      title: tr(
        context,
        es: 'Sin cruzar: cinco deudas sueltas',
        en: 'Un-netted: five separate debts',
        gl: 'Sen cruzar: cinco débedas soltas',
        ca: 'Sense creuar: cinc deutes solts',
        eu: 'Gurutzatu gabe: bost zor solte',
        fr: 'Sans compensation : cinq dettes',
        it: 'Senza compensare: cinque debiti',
        pt: 'Sem cruzar: cinco dívidas soltas',
        de: 'Ohne Verrechnung: fünf Einzelschulden',
        el: 'Χωρίς συμψηφισμό: πέντε χρέη',
        ru: 'Без взаимозачёта: пять долгов',
        ar: 'بدون مقاصة: خمسة ديون',
        zh: '未对冲：五笔零散欠款',
        ja: '相殺前は 5 件の債務',
      ),
      child: Column(
        children: [
          for (final deuda in sampleDirectDebts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(deuda.from, style: theme.textTheme.bodySmall)),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(deuda.to, style: theme.textTheme.bodySmall)),
                  Text(dinero.format(deuda.amount), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Text(
            tr(
              context,
              es: 'Noa y Marta no aparecen: se cruzan 12 € en los dos sentidos.',
              en: 'Noa and Marta are absent: they cancel 12 € both ways.',
              gl: 'Noa e Marta non aparecen: crúzanse 12 € nos dous sentidos.',
              ca: 'La Noa i la Marta no hi surten: es creuen 12 € en tots dos sentits.',
              eu: 'Noa eta Marta ez daude: 12 € gurutzatzen dituzte bi noranzkoetan.',
              fr: 'Noa et Marta n apparaissent pas : 12 € s annulent dans les deux sens.',
              it: 'Noa e Marta non compaiono: 12 € si annullano nei due sensi.',
              pt: 'A Noa e a Marta não aparecem: 12 € anulam-se nos dois sentidos.',
              de: 'Noa und Marta fehlen: 12 € heben sich gegenseitig auf.',
              el: 'Η Noa και η Marta λείπουν: 12 € αλληλοαναιρούνται.',
              ru: 'Ноа и Марты нет: 12 € взаимно гасятся.',
              ar: 'لا تظهر Noa وMarta: يتقاصان 12 يورو في الاتجاهين.',
              zh: 'Noa 与 Marta 未出现：双向 12 € 相互抵消。',
              ja: 'Noa と Marta は双方 12 € で相殺されるため出てきません。',
            ),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Los dos pagos que dejan el grupo de ejemplo a cero.
class TourSettlementExample extends StatelessWidget {
  const TourSettlementExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dinero = NumberFormat.simpleCurrency(locale: localeTag(context), name: 'EUR');

    return _MarcoEjemplo(
      title: tr(
        context,
        es: 'Con dos pagos queda saldado',
        en: 'Two payments settle it',
        gl: 'Con dous pagos queda saldado',
        ca: 'Amb dos pagaments queda saldat',
        eu: 'Bi ordainketarekin kitatuta',
        fr: 'Deux paiements suffisent',
        it: 'Bastano due pagamenti',
        pt: 'Dois pagamentos chegam',
        de: 'Zwei Zahlungen reichen',
        el: 'Δύο πληρωμές το κλείνουν',
        ru: 'Хватает двух переводов',
        ar: 'دفعتان تكفيان',
        zh: '两笔转账即可结清',
        ja: '2 回の支払いで清算',
      ),
      child: Column(
        children: [
          for (final pago in sampleSettlements)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(pago.from, style: theme.textTheme.bodySmall)),
                  Icon(Icons.arrow_forward_rounded, size: 15, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(pago.to, style: theme.textTheme.bodySmall)),
                  Text(dinero.format(pago.amount), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Text(
            tr(
              context,
              es: 'Cinco deudas se quedan en dos pagos. Nadie gana ni pierde un céntimo.',
              en: 'Five debts become two payments. Nobody gains or loses a cent.',
              gl: 'Cinco débedas quedan en dous pagos. Ninguén gaña nin perde un céntimo.',
              ca: 'Cinc deutes queden en dos pagaments. Ningú hi guanya ni hi perd res.',
              eu: 'Bost zor bi ordainketatan. Inork ez du zentimorik irabazi ez galtzen.',
              fr: 'Cinq dettes deviennent deux paiements. Personne ne gagne ni ne perd un centime.',
              it: 'Cinque debiti diventano due pagamenti. Nessuno guadagna o perde un centesimo.',
              pt: 'Cinco dívidas ficam em dois pagamentos. Ninguém ganha nem perde um cêntimo.',
              de: 'Aus fünf Schulden werden zwei Zahlungen. Niemand gewinnt oder verliert einen Cent.',
              el: 'Πέντε χρέη γίνονται δύο πληρωμές. Κανείς δεν κερδίζει ούτε χάνει σεντ.',
              ru: 'Пять долгов превращаются в два перевода. Никто ничего не теряет.',
              ar: 'خمسة ديون تصبح دفعتين. لا أحد يربح أو يخسر سنتا.',
              zh: '五笔欠款变成两笔转账，谁都不多不少。',
              ja: '5 件の債務が 2 回の支払いに。誰も損も得もしません。',
            ),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MarcoEjemplo extends StatelessWidget {
  const _MarcoEjemplo({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
