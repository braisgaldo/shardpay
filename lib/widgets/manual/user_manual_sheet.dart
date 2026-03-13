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
              _ManualBlock(
                icon: Icons.auto_awesome_rounded,
                title: tr(sheetContext, es: '4. OCR con revisión manual', en: '4. OCR with manual review', gl: '4. OCR con revision manual', fr: '4. OCR avec revision manuelle', it: '4. OCR con revisione manuale', pt: '4. OCR com revisao manual'),
                body: tr(sheetContext, es: 'Cuando importas un ticket, ShardPay detecta líneas e importes, pero siempre puedes revisar el nombre, el importe, la categoría, el reparto y añadir o quitar items antes de guardar.', en: 'When you import a receipt, ShardPay detects lines and amounts, but you can always review the name, amount, category, split, and add or remove items before saving.', gl: 'Ao importar un ticket, ShardPay detecta liñas e importes, pero sempre podes revisar nome, importe, categoria, reparto e engadir ou quitar items antes de gardar.', fr: 'Lorsque vous importez un ticket, ShardPay detecte lignes et montants, mais vous pouvez toujours revoir le nom, le montant, la categorie, la repartition et ajouter ou supprimer des articles avant d enregistrer.', it: 'Quando importi uno scontrino, ShardPay rileva righe e importi, ma puoi sempre rivedere nome, importo, categoria, ripartizione e aggiungere o rimuovere voci prima di salvare.', pt: 'Quando importas uma fatura, o ShardPay deteta linhas e valores, mas podes sempre rever nome, valor, categoria, divisao e adicionar ou remover itens antes de guardar.'),
              ),
              _ManualBlock(
                icon: Icons.account_tree_rounded,
                title: tr(sheetContext, es: '5. Liquidaciones mínimas', en: '5. Minimum settlements', gl: '5. Liquidacions minimas', fr: '5. Reglements minimaux', it: '5. Liquidazioni minime', pt: '5. Liquidacoes minimas'),
                body: tr(sheetContext, es: 'En balances de grupo y balance global se muestra un plan mínimo de transferencias para reducir pagos cruzados. Si registras un pago, el plan se recalcula automáticamente con los importes pendientes restantes.', en: 'Group balances and global balance show a minimum transfer plan to reduce cross-payments. When you record a payment, the plan recalculates automatically with the remaining pending amounts.', gl: 'Nos balances de grupo e no balance global mostraselle un plan minimo de transferencias para reducir pagos cruzados. Se rexistras un pago, o plan recalculase automaticamente co pendente restante.', fr: 'Les soldes du groupe et le solde global affichent un plan minimal de transferts pour reduire les paiements croises. Quand vous enregistrez un paiement, le plan est recalcule automatiquement.', it: 'I saldi del gruppo e il bilancio globale mostrano un piano minimo di trasferimenti per ridurre i pagamenti incrociati. Quando registri un pagamento, il piano si ricalcola automaticamente.', pt: 'Nos balances do grupo e no balance global aparece um plano minimo de transferencias para reduzir pagamentos cruzados. Quando registas um pagamento, o plano recalcula-se automaticamente.'),
              ),
              _ManualBlock(
                icon: Icons.admin_panel_settings_rounded,
                title: tr(sheetContext, es: '6. Roles y cierre del grupo', en: '6. Roles and group closing', gl: '6. Roles e peche do grupo', fr: '6. Roles et fermeture du groupe', it: '6. Ruoli e chiusura del gruppo', pt: '6. Papeis e fecho do grupo'),
                body: tr(sheetContext, es: 'La persona propietaria puede transferir la propiedad y nombrar más administradores. Los administradores pueden cerrar el grupo, reabrirlo y lanzar recordatorios de pago desde el menú de tres puntos.', en: 'The owner can transfer ownership and assign more admins. Admins can close or reopen the group and send payment reminders from the three-dot menu.', gl: 'A persoa propietaria pode transferir a propiedade e nomear mais admins. Os admins poden pechar o grupo, reabrilo e lanzar recordatorios de pago desde o menu de tres puntos.', fr: 'Le proprietaire peut transferer la propriete et nommer davantage d admins. Les admins peuvent fermer ou rouvrir le groupe et envoyer des rappels de paiement depuis le menu a trois points.', it: 'Il proprietario puo trasferire la proprieta e nominare altri admin. Gli admin possono chiudere o riaprire il gruppo e inviare promemoria dal menu a tre punti.', pt: 'A pessoa proprietaria pode transferir a propriedade e nomear mais admins. Os admins podem fechar ou reabrir o grupo e enviar lembretes de pagamento no menu de tres pontos.'),
              ),
              _ManualBlock(
                icon: Icons.filter_alt_rounded,
                title: tr(sheetContext, es: '7. Estadísticas por varios grupos', en: '7. Stats across multiple groups', gl: '7. Estatisticas por varios grupos', fr: '7. Statistiques sur plusieurs groupes', it: '7. Statistiche su piu gruppi', pt: '7. Estatisticas por varios grupos'),
                body: tr(sheetContext, es: 'En Estadísticas puedes abrir el selector de grupos, buscar por nombre y combinar varios grupos a la vez. Esto te permite comparar categorías, evolución mensual y quién adelanta más dinero.', en: 'In Stats you can open the group selector, search by name, and combine several groups at once. This lets you compare categories, monthly trends, and who advances the most money.', gl: 'En Estatisticas podes abrir o selector de grupos, buscar por nome e combinar varios grupos a vez. Isto permite comparar categorias, evolucion mensual e quen adianta mais diñeiro.', fr: 'Dans Statistiques vous pouvez ouvrir le selecteur de groupes, chercher par nom et combiner plusieurs groupes a la fois. Cela permet de comparer categories, evolution mensuelle et personnes qui avancent le plus.', it: 'In Statistiche puoi aprire il selettore gruppi, cercare per nome e combinare piu gruppi insieme. Questo permette di confrontare categorie, andamento mensile e chi anticipa piu soldi.', pt: 'Em Estatisticas podes abrir o seletor de grupos, procurar por nome e combinar varios grupos ao mesmo tempo. Isto permite comparar categorias, evolucao mensal e quem adianta mais dinheiro.'),
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
