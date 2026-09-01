import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_text.dart';
import '../../core/app_info.dart';
import '../../widgets/tour/tour_ledger_example.dart';

/// Ayuda escrita para quien usa la app, no para quien la programa.
///
/// Nada de «repositorio», «Firestore» ni «dart-define»: qué hace, cómo se usa,
/// preguntas frecuentes y qué hacer cuando algo falla.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, es: 'Ayuda', en: 'Help', gl: 'Axuda', fr: 'Aide', it: 'Aiuto', pt: 'Ajuda')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            tr(
              context,
              es: 'Qué hace ShardPay',
              en: 'What ShardPay does',
              gl: 'Que fai ShardPay',
              fr: 'Ce que fait ShardPay',
              it: 'Cosa fa ShardPay',
              pt: 'O que faz o ShardPay',
            ),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              es: 'Lleva la cuenta de lo que paga cada persona en un grupo y calcula quién le debe qué a quién. Puedes apuntar los gastos a mano o hacerle una foto al ticket para que la app lea las líneas sola.',
              en: 'It keeps track of what everyone pays in a group and works out who owes what to whom. You can enter expenses by hand or photograph the receipt and let the app read the lines itself.',
              gl: 'Leva a conta do que paga cada persoa nun grupo e calcula quen lle debe que a quen. Podes apuntar os gastos a man ou facerlle unha foto ao ticket para que a app lea as liñas soa.',
              fr: 'Elle suit ce que chacun paie dans un groupe et calcule qui doit quoi à qui. Vous pouvez saisir les dépenses à la main ou photographier le ticket pour que l application lise les lignes.',
              it: 'Tiene il conto di quanto paga ciascuno in un gruppo e calcola chi deve cosa a chi. Puoi inserire le spese a mano o fotografare lo scontrino e lasciare che l app legga le voci.',
              pt: 'Regista o que cada pessoa paga num grupo e calcula quem deve o quê a quem. Podes lançar as despesas à mão ou fotografar a fatura para a app ler as linhas sozinha.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _Section(
            title: tr(
              context,
              es: 'Cómo se usa',
              en: 'How to use it',
              gl: 'Como se usa',
              fr: 'Comment l utiliser',
              it: 'Come si usa',
              pt: 'Como se usa',
            ),
            steps: [
              tr(
                context,
                es: 'Crea un grupo o entra en uno con el enlace o el código QR que te pasen.',
                en: 'Create a group, or join one with the link or QR code someone sends you.',
                gl: 'Crea un grupo ou entra nun co enlace ou o código QR que che pasen.',
                fr: 'Créez un groupe, ou rejoignez-en un avec le lien ou le code QR qu on vous envoie.',
                it: 'Crea un gruppo, o entra in uno con il link o il codice QR che ti mandano.',
                pt: 'Cria um grupo ou entra num com a ligação ou o código QR que te enviarem.',
              ),
              tr(
                context,
                es: 'Añade gastos. Puedes escribirlos o pulsar «Ticket con cámara» y fotografiar el recibo.',
                en: 'Add expenses. You can type them in or tap "Receipt with camera" and photograph the bill.',
                gl: 'Engade gastos. Podes escribilos ou premer «Ticket con cámara» e fotografar o recibo.',
                fr: 'Ajoutez des dépenses. Vous pouvez les saisir ou toucher « Ticket avec appareil photo » et photographier le reçu.',
                it: 'Aggiungi spese. Puoi scriverle o toccare «Scontrino con fotocamera» e fotografare la ricevuta.',
                pt: 'Adiciona despesas. Podes escrevê-las ou tocar em «Fatura com câmara» e fotografar o recibo.',
              ),
              tr(
                context,
                es: 'Elige quién participa en cada línea. Por defecto se reparte a partes iguales.',
                en: 'Choose who takes part in each line. By default it is split equally.',
                gl: 'Escolle quen participa en cada liña. Por defecto repártese a partes iguais.',
                fr: 'Choisissez qui participe à chaque ligne. Par défaut, le partage est égal.',
                it: 'Scegli chi partecipa a ogni voce. Per impostazione predefinita si divide in parti uguali.',
                pt: 'Escolhe quem participa em cada linha. Por omissão divide-se em partes iguais.',
              ),
              tr(
                context,
                es: 'Mira el saldo cuando queráis cerrar cuentas: la app propone el mínimo de pagos posible.',
                en: 'Check the balance when you want to settle up: the app suggests the smallest possible number of payments.',
                gl: 'Mira o saldo cando queirades pechar contas: a app propón o mínimo de pagos posible.',
                fr: 'Regardez le solde quand vous voulez régler : l application propose le minimum de paiements possible.',
                it: 'Guarda il saldo quando volete chiudere i conti: l app propone il minor numero di pagamenti possibile.',
                pt: 'Vê o saldo quando quiserem acertar contas: a app propõe o mínimo de pagamentos possível.',
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _EjemploCompleto(),
          const SizedBox(height: 24),
          _Section(
            title: tr(
              context,
              es: 'Sacar el máximo partido al lector de tickets',
              en: 'Getting the most out of the receipt reader',
              gl: 'Sacarlle o máximo partido ao lector de tickets',
              fr: 'Tirer le meilleur du lecteur de tickets',
              it: 'Sfruttare al meglio il lettore di scontrini',
              pt: 'Tirar o máximo partido do leitor de faturas',
            ),
            steps: [
              tr(
                context,
                es: 'Estira el ticket sobre una superficie lisa. Un ticket arrugado se lee mucho peor.',
                en: 'Flatten the receipt on a smooth surface. A crumpled receipt reads much worse.',
                gl: 'Estira o ticket sobre unha superficie lisa. Un ticket engurrado lese moito peor.',
                fr: 'Aplatissez le ticket sur une surface lisse. Un ticket froissé se lit bien moins bien.',
                it: 'Distendi lo scontrino su una superficie liscia. Uno scontrino stropicciato si legge molto peggio.',
                pt: 'Estica a fatura sobre uma superfície lisa. Uma fatura amarrotada lê-se muito pior.',
              ),
              tr(
                context,
                es: 'Evita las sombras y los reflejos. Si hay poca luz, enciende la linterna desde la propia pantalla de captura.',
                en: 'Avoid shadows and glare. If the light is poor, switch on the torch from the capture screen itself.',
                gl: 'Evita as sombras e os reflexos. Se hai pouca luz, acende a lanterna desde a propia pantalla de captura.',
                fr: 'Évitez les ombres et les reflets. Si la lumière est faible, allumez la lampe depuis l écran de capture.',
                it: 'Evita ombre e riflessi. Con poca luce, accendi la torcia dalla schermata di scatto.',
                pt: 'Evita sombras e reflexos. Se houver pouca luz, liga a lanterna a partir do ecrã de captura.',
              ),
              tr(
                context,
                es: 'Encaja el ticket entero dentro del marco, incluida la línea del total: la app la usa para comprobar que la suma cuadra.',
                en: 'Fit the whole receipt inside the frame, including the total line: the app uses it to check that the sum adds up.',
                gl: 'Encaixa o ticket enteiro dentro do marco, incluída a liña do total: a app úsaa para comprobar que a suma cadra.',
                fr: 'Placez le ticket entier dans le cadre, ligne du total comprise : l application s en sert pour vérifier la somme.',
                it: 'Inquadra tutto lo scontrino, riga del totale compresa: l app la usa per verificare che la somma torni.',
                pt: 'Encaixa a fatura inteira na moldura, incluindo a linha do total: a app usa-a para confirmar que a soma bate certo.',
              ),
              tr(
                context,
                es: 'Revisa siempre lo leído antes de guardar. La app te dice si la suma cuadra con el total impreso.',
                en: 'Always review what was read before saving. The app tells you whether the sum matches the printed total.',
                gl: 'Revisa sempre o lido antes de gardar. A app dicheche se a suma cadra co total impreso.',
                fr: 'Vérifiez toujours la lecture avant d enregistrer. L application vous dit si la somme correspond au total imprimé.',
                it: 'Controlla sempre la lettura prima di salvare. L app ti dice se la somma coincide con il totale stampato.',
                pt: 'Revê sempre o que foi lido antes de guardar. A app diz-te se a soma bate certo com o total impresso.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Faq(
            entries: [
              _FaqEntry(
                question: tr(
                  context,
                  es: '¿Puedo usar la app sin conexión?',
                  en: 'Can I use the app offline?',
                  gl: 'Podo usar a app sen conexión?',
                  fr: 'Puis-je utiliser l application hors ligne ?',
                  it: 'Posso usare l app senza connessione?',
                  pt: 'Posso usar a app sem ligação?',
                ),
                answer: tr(
                  context,
                  es: 'Puedes consultar tus grupos y leer tickets sin conexión: la lectura del ticket ocurre entera en tu móvil. Los cambios se sincronizan con el resto del grupo cuando vuelve la red.',
                  en: 'You can browse your groups and read receipts offline: receipt reading happens entirely on your phone. Changes sync with the rest of the group when the network comes back.',
                  gl: 'Podes consultar os teus grupos e ler tickets sen conexión: a lectura do ticket ocorre enteira no teu móbil. Os cambios sincronízanse co resto do grupo cando volve a rede.',
                  fr: 'Vous pouvez consulter vos groupes et lire des tickets hors ligne : la lecture se fait entièrement sur votre téléphone. Les changements se synchronisent au retour du réseau.',
                  it: 'Puoi consultare i tuoi gruppi e leggere scontrini offline: la lettura avviene interamente sul telefono. Le modifiche si sincronizzano quando torna la rete.',
                  pt: 'Podes consultar os teus grupos e ler faturas sem ligação: a leitura acontece toda no teu telemóvel. As alterações sincronizam quando a rede voltar.',
                ),
              ),
              _FaqEntry(
                question: tr(
                  context,
                  es: '¿Se envían mis tickets a algún servidor?',
                  en: 'Are my receipts sent to any server?',
                  gl: 'Envíanse os meus tickets a algún servidor?',
                  fr: 'Mes tickets sont-ils envoyés à un serveur ?',
                  it: 'I miei scontrini vengono inviati a qualche server?',
                  pt: 'As minhas faturas são enviadas para algum servidor?',
                ),
                answer: tr(
                  context,
                  es: 'No. El texto del ticket se reconoce en el propio dispositivo. Solo se comparten con tu grupo los datos del gasto que decidas guardar.',
                  en: 'No. The receipt text is recognised on the device itself. Only the expense data you choose to save is shared with your group.',
                  gl: 'Non. O texto do ticket recoñécese no propio dispositivo. Só se comparten co teu grupo os datos do gasto que decidas gardar.',
                  fr: 'Non. Le texte du ticket est reconnu sur l appareil lui-même. Seules les données de dépense que vous enregistrez sont partagées avec votre groupe.',
                  it: 'No. Il testo dello scontrino viene riconosciuto sul dispositivo. Solo i dati della spesa che decidi di salvare vengono condivisi con il gruppo.',
                  pt: 'Não. O texto da fatura é reconhecido no próprio dispositivo. Só os dados da despesa que decidires guardar são partilhados com o teu grupo.',
                ),
              ),
              _FaqEntry(
                question: tr(
                  context,
                  es: '¿Qué pasa si cambio de móvil?',
                  en: 'What happens if I change phone?',
                  gl: 'Que pasa se cambio de móbil?',
                  fr: 'Que se passe-t-il si je change de téléphone ?',
                  it: 'Cosa succede se cambio telefono?',
                  pt: 'O que acontece se mudar de telemóvel?',
                ),
                answer: tr(
                  context,
                  es: 'Entra con la misma cuenta y tus grupos vuelven solos. Además puedes exportar una copia desde Ajustes y guardarla donde quieras.',
                  en: 'Sign in with the same account and your groups come back on their own. You can also export a backup from Settings and keep it wherever you like.',
                  gl: 'Entra coa mesma conta e os teus grupos volven sós. Ademais podes exportar unha copia desde Axustes e gardala onde queiras.',
                  fr: 'Connectez-vous avec le même compte et vos groupes reviennent d eux-mêmes. Vous pouvez aussi exporter une sauvegarde depuis les réglages.',
                  it: 'Accedi con lo stesso account e i tuoi gruppi tornano da soli. Puoi anche esportare una copia dalle impostazioni.',
                  pt: 'Entra com a mesma conta e os teus grupos voltam sozinhos. Também podes exportar uma cópia a partir das definições.',
                ),
              ),
              _FaqEntry(
                question: tr(
                  context,
                  es: '¿Cuesta dinero?',
                  en: 'Does it cost money?',
                  gl: 'Custa diñeiro?',
                  fr: 'Est-ce que ça coûte de l argent ?',
                  it: 'Costa qualcosa?',
                  pt: 'Custa dinheiro?',
                ),
                answer: tr(
                  context,
                  es: 'No. La app es gratuita y completa, sin anuncios y sin funciones reservadas. Hay una opción para invitar a un café al desarrollador, y no desbloquea absolutamente nada.',
                  en: 'No. The app is free and complete, with no ads and no reserved features. There is an option to buy the developer a coffee, and it unlocks absolutely nothing.',
                  gl: 'Non. A app é gratuíta e completa, sen anuncios e sen funcións reservadas. Hai unha opción para convidar a un café ao desenvolvedor, e non desbloquea absolutamente nada.',
                  fr: 'Non. L application est gratuite et complète, sans publicité ni fonctions réservées. Il y a une option pour offrir un café au développeur, et elle ne débloque strictement rien.',
                  it: 'No. L app è gratuita e completa, senza pubblicità né funzioni riservate. C è un opzione per offrire un caffè allo sviluppatore, e non sblocca assolutamente nulla.',
                  pt: 'Não. A app é gratuita e completa, sem anúncios e sem funcionalidades reservadas. Há uma opção para oferecer um café ao programador, e não desbloqueia absolutamente nada.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            tr(
              context,
              es: 'Si algo falla',
              en: 'If something goes wrong',
              gl: 'Se algo falla',
              fr: 'Si quelque chose ne va pas',
              it: 'Se qualcosa non va',
              pt: 'Se algo correr mal',
            ),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              es: 'Primero cierra la app y vuelve a abrirla. Si el problema sigue, exporta una copia de tus datos desde Ajustes antes de nada y cuéntanoslo: es la forma más rápida de que se arregle.',
              en: 'First close the app and open it again. If the problem persists, export a backup of your data from Settings before anything else, and tell us: it is the fastest way to get it fixed.',
              gl: 'Primeiro pecha a app e volve abrila. Se o problema segue, exporta unha copia dos teus datos desde Axustes antes de nada e cóntanolo: é a forma máis rápida de que se arranxe.',
              fr: 'Fermez d abord l application et rouvrez-la. Si le problème persiste, exportez une sauvegarde depuis les réglages, puis signalez-le : c est le plus rapide pour le corriger.',
              it: 'Prima chiudi l app e riaprila. Se il problema resta, esporta una copia dei dati dalle impostazioni e segnalacelo: è il modo più rapido per risolverlo.',
              pt: 'Primeiro fecha a app e volta a abri-la. Se o problema continuar, exporta uma cópia dos teus dados nas definições e avisa-nos: é a forma mais rápida de o resolver.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(AppInfo.issuesUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.bug_report_outlined),
            label: Text(
              tr(
                context,
                es: 'Contar un problema',
                en: 'Report a problem',
                gl: 'Contar un problema',
                fr: 'Signaler un problème',
                it: 'Segnalare un problema',
                pt: 'Relatar um problema',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (var index = 0; index < steps.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Text('${index + 1}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[index], style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class _FaqEntry {
  const _FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _Faq extends StatelessWidget {
  const _Faq({required this.entries});

  final List<_FaqEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(
            context,
            es: 'Preguntas frecuentes',
            en: 'Frequently asked questions',
            gl: 'Preguntas frecuentes',
            fr: 'Questions fréquentes',
            it: 'Domande frequenti',
            pt: 'Perguntas frequentes',
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        for (final entry in entries)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(entry.question, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(entry.answer, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
      ],
    );
  }
}

/// Ejemplo trabajado de principio a fin.
///
/// Las cifras salen de `lib/core/sample_ledger.dart` y una prueba comprueba que
/// coinciden con lo que calcula el motor de la app. Es la forma de que la ayuda
/// no se desincronice del comportamiento real.
class _EjemploCompleto extends StatelessWidget {
  const _EjemploCompleto();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(
            context,
            es: 'Un ejemplo de principio a fin',
            en: 'A worked example, end to end',
            gl: 'Un exemplo de principio a fin',
            ca: 'Un exemple de principi a fi',
            eu: 'Adibide oso bat, hasieratik bukaeraraino',
            fr: 'Un exemple complet, de bout en bout',
            it: 'Un esempio completo, dall inizio alla fine',
            pt: 'Um exemplo de ponta a ponta',
            de: 'Ein durchgerechnetes Beispiel',
            el: 'Ένα παράδειγμα από την αρχή ως το τέλος',
            ru: 'Разобранный пример от начала до конца',
            ar: 'مثال كامل من البداية إلى النهاية',
            zh: '一个完整的例子',
            ja: '最初から最後までの実例',
          ),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            es: 'Cuatro amigos se van de viaje: Brais, Noa, Leo y Marta. Cada uno paga lo que le toca pagar sobre la marcha, y ninguno lleva la cuenta.',
            en: 'Four friends go on a trip: Brais, Noa, Leo and Marta. Each pays for whatever comes up, and nobody keeps score.',
            gl: 'Catro amigos van de viaxe: Brais, Noa, Leo e Marta. Cada un paga o que lle toca sobre a marcha, e ninguén leva a conta.',
            ca: 'Quatre amics fan un viatge: en Brais, la Noa, en Leo i la Marta. Cadascú paga el que toca i ningú porta el compte.',
            eu: 'Lau lagun bidaian doaz: Brais, Noa, Leo eta Marta. Bakoitzak dagokiona ordaintzen du, eta inork ez du kontua eramaten.',
            fr: 'Quatre amis partent en voyage : Brais, Noa, Leo et Marta. Chacun paie ce qui se présente, personne ne tient les comptes.',
            it: 'Quattro amici partono per un viaggio: Brais, Noa, Leo e Marta. Ognuno paga quello che capita e nessuno tiene i conti.',
            pt: 'Quatro amigos vão de viagem: Brais, Noa, Leo e Marta. Cada um paga o que aparece e ninguém faz contas.',
            de: 'Vier Freunde machen eine Reise: Brais, Noa, Leo und Marta. Jeder zahlt, was gerade anfällt, niemand rechnet mit.',
            el: 'Τέσσερις φίλοι πάνε ταξίδι: Brais, Noa, Leo και Marta. Ο καθένας πληρώνει ό,τι προκύψει και κανείς δεν κρατάει λογαριασμό.',
            ru: 'Четверо друзей едут в поездку: Брайс, Ноа, Лео и Марта. Каждый платит за то, что подвернётся, и никто не ведёт счёт.',
            ar: 'أربعة أصدقاء في رحلة: Brais وNoa وLeo وMarta. كل واحد يدفع ما يصادفه، ولا أحد يمسك الحساب.',
            zh: '四个朋友一起旅行：Brais、Noa、Leo 和 Marta。谁碰上谁付，没人记账。',
            ja: '4 人で旅行に行きます。Brais・Noa・Leo・Marta。そのつど誰かが払い、誰も記録はつけません。',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        const TourExpensesExample(),
        const SizedBox(height: 14),
        Text(
          tr(
            context,
            es: 'Las entradas al museo solo las querían Noa y Marta, así que esa línea se reparte entre dos: 12 € cada una. Brais y Leo no pagan nada de ella. El resto va a partes iguales entre los cuatro.',
            en: 'Only Noa and Marta wanted the museum tickets, so that line splits between two: 12 € each. Brais and Leo pay nothing towards it. Everything else is split four ways.',
            gl: 'As entradas ao museo só as querían Noa e Marta, así que esa liña repártese entre dúas: 12 € cada unha. O resto vai a partes iguais entre os catro.',
            ca: 'Les entrades al museu només les volien la Noa i la Marta: aquella línia es reparteix entre dues, 12 € cadascuna. La resta va a parts iguals.',
            eu: 'Museoko sarrerak Noak eta Martak nahi zituzten: lerro hori biren artean, 12 € bakoitzak. Gainerakoa lauren artean berdin.',
            fr: 'Seules Noa et Marta voulaient le musée : cette ligne se partage à deux, 12 € chacune. Le reste se divise à quatre.',
            it: 'Il museo lo volevano solo Noa e Marta: quella voce si divide fra due, 12 € a testa. Il resto si divide in quattro.',
            pt: 'O museu só a Noa e a Marta queriam: essa linha divide-se por duas, 12 € cada. O resto divide-se pelos quatro.',
            de: 'Ins Museum wollten nur Noa und Marta: diese Position teilen sich zwei, je 12 €. Der Rest wird durch vier geteilt.',
            el: 'Το μουσείο το ήθελαν μόνο η Noa και η Marta: η γραμμή μοιράζεται στα δύο, 12 € η καθεμία. Τα υπόλοιπα στα τέσσερα.',
            ru: 'В музей хотели только Ноа и Марта: эта строка делится на двоих, по 12 €. Остальное — на четверых поровну.',
            ar: 'المتحف أرادته Noa وMarta فقط: تلك السطر يقسم على اثنتين، 12 يورو لكل منهما. والباقي بالتساوي على الأربعة.',
            zh: '博物馆只有 Noa 和 Marta 想去，这一项两人平分，各 12 €。其余四人均摊。',
            ja: '美術館は Noa と Marta だけ。この行は 2 人で各 12 €。ほかは 4 人で均等に分けます。',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        const TourBalancesExample(),
        const SizedBox(height: 14),
        Text(
          tr(
            context,
            es: 'Brais adelantó la cena y le deben 36 €. Leo puso la gasolina y le deben 12 €. Noa y Marta consumieron más de lo que pagaron, así que deben. Los cuatro saldos suman cero: eso es lo que hay que comprobar siempre.',
            en: 'Brais fronted the dinner and is owed 36 €. Leo covered the fuel and is owed 12 €. Noa and Marta consumed more than they paid, so they owe. The four balances add up to zero: that is the check that always has to hold.',
            gl: 'Brais adiantou a cea e débenlle 36 €. Leo puxo a gasolina e débenlle 12 €. Noa e Marta consumiron máis do que pagaron. Os catro saldos suman cero.',
            ca: 'En Brais va avançar el sopar i li deuen 36 €. En Leo la benzina, 12 €. Els quatre saldos sumen zero.',
            eu: 'Braisek afaria aurreratu zuen: 36 € zor diote. Leok gasolina: 12 €. Lau saldoek zero ematen dute.',
            fr: 'Brais a avancé le dîner : 36 € pour lui. Leo l essence : 12 €. Les quatre soldes font zéro.',
            it: 'Brais ha anticipato la cena: gli devono 36 €. Leo la benzina: 12 €. I quattro saldi fanno zero.',
            pt: 'O Brais adiantou o jantar: devem-lhe 36 €. O Leo a gasolina: 12 €. Os quatro saldos somam zero.',
            de: 'Brais hat das Essen ausgelegt: 36 € für ihn. Leo den Sprit: 12 €. Die vier Salden ergeben null.',
            el: 'Ο Brais πλήρωσε το δείπνο: του χρωστούν 36 €. Ο Leo τη βενζίνη: 12 €. Τα τέσσερα υπόλοιπα κάνουν μηδέν.',
            ru: 'Брайс оплатил ужин — ему 36 €. Лео бензин — 12 €. Четыре баланса в сумме дают ноль.',
            ar: 'دفع Brais العشاء: له 36 يورو. وLeo البنزين: 12 يورو. مجموع الأرصدة الأربعة صفر.',
            zh: 'Brais 垫了晚饭，应收 36 €。Leo 加油，应收 12 €。四个余额相加为零。',
            ja: 'Brais は夕食で 36 € の受取。Leo は給油で 12 €。4 人の残高の合計はゼロになります。',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        const TourDirectDebtsExample(),
        const SizedBox(height: 14),
        Text(
          tr(
            context,
            es: 'Si tocas a una persona en «Balance», ShardPay abre sus deudas directas, gasto a gasto. Aquí salen cinco por 54 €. Noa y Marta no aparecen juntas: Marta le debe 12 € a Noa por el museo y Noa le debe otros 12 € a Marta por el súper, así que quedan a cero entre ellas.',
            en: 'Tap a person in "Balance" and ShardPay opens their direct debts, expense by expense. Here there are five, adding up to 54 €. Noa and Marta never share a row: Marta owes Noa 12 € for the museum and Noa owes Marta 12 € for the groceries, so they cancel out.',
            gl: 'Se tocas unha persoa en «Balance», ShardPay abre as súas débedas directas, gasto a gasto. Aquí saen cinco por 54 €. Noa e Marta non aparecen xuntas: crúzanse 12 € e quedan a cero.',
            ca: 'Si toques una persona a «Balanç», ShardPay obre els seus deutes directes, despesa a despesa. Aquí en surten cinc per 54 €. La Noa i la Marta es creuen 12 € i queden a zero.',
            eu: '«Balantzea» atalean pertsona bat ukituz gero, bere zuzeneko zorrak irekitzen dira, gastuz gastu. Hemen bost dira, 54 €. Noa eta Marta 12 € gurutzatzen dituzte eta zeroan gelditzen dira.',
            fr: 'Touchez une personne dans « Solde » et ShardPay ouvre ses dettes directes, dépense par dépense. Il y en a cinq, pour 54 €. Noa et Marta s annulent 12 € et restent à zéro.',
            it: 'Tocca una persona in «Saldo» e ShardPay apre i suoi debiti diretti, spesa per spesa. Qui sono cinque, per 54 €. Noa e Marta si annullano 12 € e restano a zero.',
            pt: 'Toca numa pessoa em «Saldo» e o ShardPay abre as suas dívidas directas, despesa a despesa. Aqui são cinco, 54 €. A Noa e a Marta anulam 12 € e ficam a zero.',
            de: 'Tippe in „Saldo" auf eine Person, und ShardPay öffnet ihre direkten Schulden, Ausgabe für Ausgabe. Hier sind es fünf über 54 €. Noa und Marta heben 12 € gegenseitig auf.',
            el: 'Άγγιξε ένα άτομο στο «Υπόλοιπο» και το ShardPay ανοίγει τα άμεσα χρέη του, έξοδο προς έξοδο. Εδώ είναι πέντε, 54 €. Η Noa και η Marta αλληλοαναιρούν 12 €.',
            ru: 'Коснитесь человека в «Балансе», и ShardPay откроет его прямые долги, расход за расходом. Здесь их пять на 54 €. Ноа и Марта гасят по 12 € и выходят в ноль.',
            ar: 'المس شخصا في «الرصيد» ليفتح ShardPay ديونه المباشرة، مصروفا بمصروف. هنا خمسة بقيمة 54 يورو. وتتقاص Noa وMarta 12 يورو فتبقيان على الصفر.',
            zh: '在「余额」里点某个人，ShardPay 会逐笔列出他的直接欠款。这里共五笔、54 €。Noa 与 Marta 双向 12 € 相抵，彼此归零。',
            ja: '「残高」で人をタップすると、支出ごとの直接の債務が開きます。ここでは 5 件・54 €。Noa と Marta は 12 € ずつが相殺されてゼロになります。',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        const TourSettlementExample(),
        const SizedBox(height: 14),
        Text(
          tr(
            context,
            es: 'Esas cinco deudas se quedan en dos pagos, y el dinero que se mueve baja de 54 € a 48 €. Nadie gana ni pierde un céntimo: Brais recupera sus 36 €, Leo sus 12 €, y Noa y Marta pagan lo que debían. Solo cambia a quién se lo transfieren. Cuando alguien pague, pulsa «Reembolsar»: el plan se recalcula con lo que quede pendiente.',
            en: 'Those five debts come down to two payments, and the money moved drops from 54 € to 48 €. Nobody gains or loses a cent: Brais gets his 36 € back, Leo his 12 €, and Noa and Marta pay exactly what they owed. Only the recipient changes. When someone pays, tap "Reimburse": the plan recalculates with whatever is left.',
            gl: 'Esas cinco débedas quedan en dous pagos, e o diñeiro que se move baixa de 54 € a 48 €. Ninguén gaña nin perde un céntimo. Cando alguén pague, preme «Reembolsar».',
            ca: 'Aquells cinc deutes queden en dos pagaments, i els diners que es mouen baixen de 54 € a 48 €. Ningú hi guanya ni hi perd res.',
            eu: 'Bost zor horiek bi ordainketatan gelditzen dira, eta mugitzen den dirua 54 €-tik 48 €-ra jaisten da. Inork ez du zentimorik irabazi ez galtzen.',
            fr: 'Ces cinq dettes se réduisent à deux paiements, et l argent déplacé passe de 54 € à 48 €. Personne ne gagne ni ne perd un centime.',
            it: 'Quei cinque debiti si riducono a due pagamenti e il denaro spostato scende da 54 € a 48 €. Nessuno guadagna o perde un centesimo.',
            pt: 'Essas cinco dívidas ficam em dois pagamentos e o dinheiro movido desce de 54 € para 48 €. Ninguém ganha nem perde um cêntimo.',
            de: 'Aus diesen fünf Schulden werden zwei Zahlungen, und der bewegte Betrag sinkt von 54 € auf 48 €. Niemand gewinnt oder verliert einen Cent.',
            el: 'Αυτά τα πέντε χρέη γίνονται δύο πληρωμές και τα χρήματα που κινούνται πέφτουν από 54 € σε 48 €. Κανείς δεν κερδίζει ούτε χάνει σεντ.',
            ru: 'Эти пять долгов сводятся к двум переводам, а сумма в движении падает с 54 € до 48 €. Никто ничего не выигрывает и не теряет.',
            ar: 'تتحول تلك الديون الخمسة إلى دفعتين، وينخفض المال المتحرك من 54 إلى 48 يورو. لا أحد يربح أو يخسر سنتا.',
            zh: '这五笔欠款变成两笔转账，实际流动的钱从 54 € 降到 48 €。谁都不多不少。',
            ja: 'この 5 件の債務が 2 回の支払いになり、動くお金は 54 € から 48 € に減ります。誰も損も得もしません。',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Text(
          tr(
            context,
            es: 'En Estadísticas verás en qué se fue: 84 € en comida, 60 € en transporte, 48 € en súper y 24 € en ocio, de 216 € en total. Y quién adelantó más dinero a lo largo del viaje.',
            en: 'Stats show where it went: 84 € on food, 60 € on transport, 48 € on groceries and 24 € on leisure, out of 216 € total. And who fronted the most money along the way.',
            gl: 'En Estatísticas verás en que se foi: 84 € en comida, 60 € en transporte, 48 € no súper e 24 € en ocio, de 216 € en total.',
            ca: 'A Estadístiques veuràs on ha anat: 84 € en menjar, 60 € en transport, 48 € al súper i 24 € en oci, de 216 € en total.',
            eu: 'Estatistiketan ikusiko duzu zertan joan den: 84 € janaria, 60 € garraioa, 48 € supermerkatua eta 24 € aisia, 216 €-tik.',
            fr: 'Les statistiques montrent la répartition : 84 € de repas, 60 € de transport, 48 € de courses, 24 € de loisirs, sur 216 € au total.',
            it: 'Le statistiche mostrano dove è finito: 84 € di cibo, 60 € di trasporto, 48 € di spesa e 24 € di svago, su 216 € totali.',
            pt: 'Nas estatísticas vês para onde foi: 84 € em comida, 60 € em transporte, 48 € no supermercado e 24 € em lazer, de 216 € no total.',
            de: 'Die Statistiken zeigen die Verteilung: 84 € Essen, 60 € Transport, 48 € Einkauf, 24 € Freizeit von insgesamt 216 €.',
            el: 'Τα στατιστικά δείχνουν πού πήγαν: 84 € φαγητό, 60 € μεταφορικά, 48 € σούπερ μάρκετ, 24 € διασκέδαση, από 216 € συνολικά.',
            ru: 'Статистика показывает, куда ушло: 84 € еда, 60 € транспорт, 48 € продукты, 24 € досуг — из 216 € всего.',
            ar: 'تُظهر الإحصاءات أين ذهب المال: 84 للطعام و60 للتنقل و48 للتسوق و24 للترفيه، من أصل 216 يورو.',
            zh: '统计页显示去向：餐饮 84 €、交通 60 €、超市 48 €、娱乐 24 €，合计 216 €。',
            ja: '統計では内訳がわかります。食事 84 €、交通 60 €、買い物 48 €、娯楽 24 €、合計 216 € です。',
          ),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
