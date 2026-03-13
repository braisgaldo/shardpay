import 'package:flutter/material.dart';

import '../../app/app_text.dart';

Future<void> showUserManualSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                tr(sheetContext, es: 'Manual rápido', en: 'Quick manual', gl: 'Manual rapido', fr: 'Guide rapide', it: 'Manuale rapido', pt: 'Manual rapido'),
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _ManualBlock(
                icon: Icons.group_rounded,
                title: tr(sheetContext, es: '1. Crea o entra en grupos', en: '1. Create or join groups', gl: '1. Crea ou entra en grupos', fr: '1. Creez ou rejoignez des groupes', it: '1. Crea o entra nei gruppi', pt: '1. Cria ou entra em grupos'),
                body: tr(sheetContext, es: 'Puedes crear grupos con personas pendientes, compartir el enlace o entrar por QR. El administrador decide accesos, icono, divisa y si el grupo queda cerrado.', en: 'You can create groups with pending people, share links, or join via QR. The admin controls access, icon, currency, and whether the group is closed.', gl: 'Podes crear grupos con persoas pendentes, compartir a ligazon ou entrar por QR. A administracion decide accesos, icona, divisa e se o grupo queda pechado.', fr: 'Vous pouvez creer des groupes avec des personnes en attente, partager le lien ou entrer par QR. L admin gere les acces, l icone, la devise et la fermeture du groupe.', it: 'Puoi creare gruppi con persone in attesa, condividere il link o entrare via QR. L admin gestisce accessi, icona, valuta e chiusura del gruppo.', pt: 'Podes criar grupos com pessoas pendentes, partilhar o link ou entrar por QR. A administracao gere acessos, icone, moeda e fecho do grupo.'),
              ),
              _ManualBlock(
                icon: Icons.receipt_long_rounded,
                title: tr(sheetContext, es: '2. Añade gastos o reembolsos', en: '2. Add expenses or reimbursements', gl: '2. Engade gastos ou reembolsos', fr: '2. Ajoutez des depenses ou remboursements', it: '2. Aggiungi spese o rimborsi', pt: '2. Adiciona despesas ou reembolsos'),
                body: tr(sheetContext, es: 'Los gastos pueden ser manuales o desde ticket OCR. Los reembolsos sirven para registrar pagos entre personas y ajustar balances sin perder histórico.', en: 'Expenses can be manual or imported from OCR receipts. Reimbursements record payments between people and adjust balances without losing history.', gl: 'Os gastos poden ser manuais ou desde ticket OCR. Os reembolsos rexistran pagos entre persoas e axustan balances sen perder historico.', fr: 'Les depenses peuvent etre manuelles ou provenir d un ticket OCR. Les remboursements enregistrent les paiements entre personnes sans perdre l historique.', it: 'Le spese possono essere manuali o importate da ticket OCR. I rimborsi registrano i pagamenti tra persone senza perdere lo storico.', pt: 'As despesas podem ser manuais ou importadas por OCR. Os reembolsos registam pagamentos entre pessoas sem perder historico.'),
              ),
              _ManualBlock(
                icon: Icons.notifications_active_rounded,
                title: tr(sheetContext, es: '3. Revisa notificaciones y saldos', en: '3. Review notifications and balances', gl: '3. Revisa notificacions e saldos', fr: '3. Consultez notifications et soldes', it: '3. Controlla notifiche e saldi', pt: '3. Revê notificacoes e saldos'),
                body: tr(sheetContext, es: 'Desde Ajustes puedes abrir el centro de notificaciones y decidir qué avisos quieres ver. En Balance global verás a quién debes y quién te debe entre todos los grupos.', en: 'From Settings you can open the notification center and choose which alerts to see. In Global balance you can see who you owe and who owes you across all groups.', gl: 'Desde Axustes podes abrir o centro de notificacion e decidir que avisos queres ver. En Balance global veras a quen debes e quen che debe entre todos os grupos.', fr: 'Depuis les Reglages vous pouvez ouvrir le centre de notifications et choisir les alertes visibles. Dans Solde global vous voyez qui vous devez et qui vous doit de l argent.', it: 'Da Impostazioni puoi aprire il centro notifiche e scegliere quali avvisi vedere. In Bilancio globale vedi chi devi pagare e chi ti deve soldi.', pt: 'A partir dos Ajustes podes abrir o centro de notificacoes e escolher os avisos visiveis. Em Balance global ves a quem deves e quem te deve dinheiro.'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ManualBlock extends StatelessWidget {
  const _ManualBlock({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
