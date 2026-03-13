import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_text.dart';
import '../../app/providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _register = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    if (!bootstrap.firebaseReady)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tr(context, es: 'Estás en modo demo local porque faltan credenciales Firebase en --dart-define. La app sigue siendo navegable y los flujos quedan listos.', en: 'You are in local demo mode because Firebase credentials are missing in --dart-define. The app remains fully navigable.', gl: 'Estas en modo demo local porque faltan credenciais Firebase en --dart-define. A app segue sendo navegable.', fr: 'Vous etes en mode demo local car les identifiants Firebase manquent dans --dart-define. L application reste navigable.', it: 'Sei in modalita demo locale perche mancano le credenziali Firebase in --dart-define. L app resta navigabile.', pt: 'Estas em modo demo local porque faltam credenciais Firebase em --dart-define. A app continua navegavel.'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF101522), Color(0xFFE4572E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
                                const SizedBox(height: 16),
                                Text(
                                  'ShardPay',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  tr(context, es: 'Comparte gastos con estilo: escanea tickets, reparte cada item con precisión y entra en tus grupos por QR o enlace.', en: 'Share expenses with style: scan receipts, split each item precisely, and join groups by QR or link.', gl: 'Comparte gastos con estilo: escanea tickets, reparte cada item con precision e entra nos teus grupos por QR ou ligazon.', fr: 'Partagez vos depenses avec style : scannez des tickets, repartissez chaque article et rejoignez vos groupes par QR ou lien.', it: 'Condividi le spese con stile: scansiona scontrini, dividi ogni voce con precisione ed entra nei gruppi tramite QR o link.', pt: 'Partilha despesas com estilo: digitaliza faturas, reparte cada item com precisao e entra nos grupos por QR ou link.'),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _FeaturePill(label: tr(context, es: 'Grupos compartidos', en: 'Shared groups', gl: 'Grupos compartidos', fr: 'Groupes partages', it: 'Gruppi condivisi', pt: 'Grupos partilhados')),
                                    _FeaturePill(label: tr(context, es: 'OCR del ticket', en: 'Receipt OCR', gl: 'OCR do ticket', fr: 'OCR du ticket', it: 'OCR scontrino', pt: 'OCR da fatura')),
                                    _FeaturePill(label: tr(context, es: 'Reparto exacto', en: 'Exact split', gl: 'Reparto exacto', fr: 'Repartition exacte', it: 'Ripartizione precisa', pt: 'Divisao exata')),
                                    _FeaturePill(label: tr(context, es: 'Invitaciones por QR', en: 'QR invites', gl: 'Convites por QR', fr: 'Invitations QR', it: 'Inviti QR', pt: 'Convites por QR')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: colorScheme.outlineVariant),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _register
                                      ? tr(context, es: 'Crea tu acceso en medio minuto', en: 'Create your account in under a minute', gl: 'Crea o teu acceso en medio minuto', fr: 'Creez votre acces en moins d une minute', it: 'Crea il tuo accesso in meno di un minuto', pt: 'Cria o teu acesso em meio minuto')
                                      : tr(context, es: 'Vuelve a tus grupos y balances', en: 'Return to your groups and balances', gl: 'Volve aos teus grupos e balances', fr: 'Retrouvez vos groupes et soldes', it: 'Torna ai tuoi gruppi e saldi', pt: 'Volta aos teus grupos e saldos'),
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _register
                                      ? tr(context, es: 'Prepara tu cuenta para compartir gastos, tickets y repartos avanzados con tu grupo desde el primer minuto.', en: 'Prepare your account to share expenses, receipts and advanced splits from day one.', gl: 'Prepara a tua conta para compartir gastos, tickets e repartos avanzados desde o primeiro minuto.', fr: 'Preparez votre compte pour partager depenses, tickets et repartitions avancees des le premier jour.', it: 'Prepara il tuo account per condividere spese, scontrini e ripartizioni avanzate fin dal primo momento.', pt: 'Prepara a tua conta para partilhar despesas, faturas e reparticoes avancadas desde o primeiro minuto.')
                                      : tr(context, es: 'Accede con tu email o con Google para recuperar grupos, invitaciones y movimientos pendientes.', en: 'Use email or Google to recover groups, invites and pending activity.', gl: 'Accede co teu email ou con Google para recuperar grupos, convites e movementos pendentes.', fr: 'Connectez-vous avec votre e-mail ou Google pour retrouver groupes, invitations et activites en attente.', it: 'Accedi con email o Google per recuperare gruppi, inviti e attivita in sospeso.', pt: 'Entra com email ou Google para recuperar grupos, convites e movimentos pendentes.'),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _ModeButton(
                                          label: tr(context, es: 'Ya tengo cuenta', en: 'I already have an account', gl: 'Xa teño conta', fr: 'J ai deja un compte', it: 'Ho gia un account', pt: 'Ja tenho conta'),
                                          selected: !_register,
                                          onTap: _loading ? null : () => setState(() => _register = false),
                                        ),
                                      ),
                                      Expanded(
                                        child: _ModeButton(
                                          label: tr(context, es: 'Soy nuevo', en: 'I am new here', gl: 'Son novo', fr: 'Je suis nouveau', it: 'Sono nuovo', pt: 'Sou novo'),
                                          selected: _register,
                                          onTap: _loading ? null : () => setState(() => _register = true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      if (_register) ...[
                                        TextFormField(
                                          controller: _nameController,
                                          textCapitalization: TextCapitalization.words,
                                          decoration: InputDecoration(
                                            labelText: tr(context, es: 'Cómo te llamamos', en: 'How should we call you', gl: 'Como te chamamos', fr: 'Comment vous appeler', it: 'Come vuoi essere chiamato', pt: 'Como te chamamos'),
                                            hintText: tr(context, es: 'Nombre visible para tu grupo', en: 'Visible name for your group', gl: 'Nome visible para o teu grupo', fr: 'Nom visible pour votre groupe', it: 'Nome visibile per il gruppo', pt: 'Nome visivel para o teu grupo'),
                                          ),
                                          validator: (value) {
                                            if (!_register) {
                                              return null;
                                            }
                                            if (value == null || value.trim().isEmpty) {
                                              return tr(context, es: 'Introduce el nombre que quieres mostrar.', en: 'Enter the name you want to show.', gl: 'Introduce o nome que queres mostrar.', fr: 'Saisissez le nom a afficher.', it: 'Inserisci il nome da mostrare.', pt: 'Introduz o nome que queres mostrar.');
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      TextFormField(
                                        controller: _emailController,
                                        decoration: InputDecoration(
                                          labelText: tr(context, es: 'Tu email', en: 'Your email', gl: 'O teu email', fr: 'Votre e-mail', it: 'La tua email', pt: 'O teu email'),
                                          hintText: 'nombre@correo.com',
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                                        validator: (value) {
                                          final email = value?.trim() ?? '';
                                          if (email.isEmpty) {
                                            return tr(context, es: 'Introduce tu email.', en: 'Enter your email.', gl: 'Introduce o teu email.', fr: 'Saisissez votre e-mail.', it: 'Inserisci la tua email.', pt: 'Introduz o teu email.');
                                          }
                                          if (!email.contains('@') || !email.contains('.')) {
                                            return tr(context, es: 'Revisa el formato del email.', en: 'Check the email format.', gl: 'Revisa o formato do email.', fr: 'Verifiez le format de l e-mail.', it: 'Controlla il formato della email.', pt: 'Revê o formato do email.');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _passwordController,
                                        decoration: InputDecoration(
                                          labelText: _register ? tr(context, es: 'Crea una contraseña', en: 'Create a password', gl: 'Crea un contrasinal', fr: 'Creez un mot de passe', it: 'Crea una password', pt: 'Cria uma palavra-passe') : tr(context, es: 'Tu contraseña', en: 'Your password', gl: 'O teu contrasinal', fr: 'Votre mot de passe', it: 'La tua password', pt: 'A tua palavra-passe'),
                                          hintText: _register ? tr(context, es: 'Mínimo 6 caracteres', en: 'At least 6 characters', gl: 'Minimo 6 caracteres', fr: 'Minimum 6 caracteres', it: 'Almeno 6 caratteri', pt: 'Minimo 6 caracteres') : tr(context, es: 'Escribe tu contraseña', en: 'Type your password', gl: 'Escribe o teu contrasinal', fr: 'Saisissez votre mot de passe', it: 'Digita la tua password', pt: 'Escreve a tua palavra-passe'),
                                        ),
                                        obscureText: true,
                                        autofillHints: const [AutofillHints.password],
                                        validator: (value) {
                                          final password = value?.trim() ?? '';
                                          if (password.isEmpty) {
                                            return tr(context, es: 'Introduce tu contraseña.', en: 'Enter your password.', gl: 'Introduce o teu contrasinal.', fr: 'Saisissez votre mot de passe.', it: 'Inserisci la tua password.', pt: 'Introduz a tua palavra-passe.');
                                          }
                                          if (_register && password.length < 6) {
                                            return tr(context, es: 'Usa al menos 6 caracteres.', en: 'Use at least 6 characters.', gl: 'Usa polo menos 6 caracteres.', fr: 'Utilisez au moins 6 caracteres.', it: 'Usa almeno 6 caratteri.', pt: 'Usa pelo menos 6 caracteres.');
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _register
                                      ? tr(context, es: 'Crearás tu acceso por email. Después podrás usar Google en cuanto la infraestructura quede activada.', en: 'You will create your account with email. Google can be used later as soon as infrastructure is active.', gl: 'Crearas o teu acceso por email. Despois poderas usar Google cando a infraestrutura estea activa.', fr: 'Vous allez creer votre acces par e-mail. Google pourra etre utilise une fois l infrastructure active.', it: 'Creerai il tuo accesso via email. Potrai usare Google appena l infrastruttura sara attiva.', pt: 'Vais criar o teu acesso por email. Depois poderas usar Google quando a infraestrutura estiver ativa.')
                                      : tr(context, es: 'Si aún no tienes acceso, cambia a "Soy nuevo" y crea tu cuenta desde aquí.', en: 'If you do not have access yet, switch to the new account mode and create it here.', gl: 'Se ainda non tes acceso, cambia ao modo de conta nova e crea a conta aqui.', fr: 'Si vous n avez pas encore acces, passez en mode nouveau compte et creez-le ici.', it: 'Se non hai ancora accesso, passa alla modalita nuovo account e crealo qui.', pt: 'Se ainda nao tens acesso, muda para o modo nova conta e cria-a aqui.'),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _loading ? null : _submitEmail,
                                    icon: Icon(_register ? Icons.person_add_alt_1_rounded : Icons.login_rounded),
                                    label: Text(_register ? tr(context, es: 'Crear cuenta y entrar', en: 'Create account and enter', gl: 'Crear conta e entrar', fr: 'Creer le compte et entrer', it: 'Crea account ed entra', pt: 'Criar conta e entrar') : tr(context, es: 'Entrar con email', en: 'Continue with email', gl: 'Entrar con email', fr: 'Continuer avec e-mail', it: 'Continua con email', pt: 'Entrar com email')),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _loading ? null : _submitGoogle,
                                    icon: const Icon(Icons.account_circle_rounded),
                                    label: Text(tr(context, es: 'Continuar con Google', en: 'Continue with Google', gl: 'Continuar con Google', fr: 'Continuer avec Google', it: 'Continua con Google', pt: 'Continuar com Google')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitEmail() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      final repository = ref.read(repositoryProvider);
      await repository.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        register: _register,
        displayName: _nameController.text.trim(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showError(_readableError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final repository = ref.read(repositoryProvider);
      await repository.signInWithGoogle();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showError(_readableError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _readableError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Bad state: ')) {
      return raw.replaceFirst('Bad state: ', '');
    }
    if (raw.contains('CONFIGURATION_NOT_FOUND') || raw.contains('BILLING_NOT_ENABLED')) {
      return tr(context, es: 'El acceso todavía no está habilitado en Google Cloud para este proyecto. Falta activar facturación/Auth en la infraestructura.', en: 'Access is not yet enabled in Google Cloud for this project. Billing/Auth still needs activation.', gl: 'O acceso ainda non esta habilitado en Google Cloud para este proxecto. Falta activar facturacion/Auth na infraestrutura.', fr: 'L acces n est pas encore active dans Google Cloud pour ce projet. Il faut encore activer la facturation/Auth.', it: 'L accesso non e ancora abilitato in Google Cloud per questo progetto. Occorre ancora attivare billing/Auth.', pt: 'O acesso ainda nao esta ativado no Google Cloud para este projeto. Ainda falta ativar billing/Auth.');
    }
    if (raw.contains('network-request-failed')) {
      return tr(context, es: 'No se pudo contactar con el servidor. Revisa la conexión y vuelve a intentarlo.', en: 'Could not reach the server. Check your connection and try again.', gl: 'Non se puido contactar co servidor. Revisa a conexion e tenta de novo.', fr: 'Impossible de contacter le serveur. Verifiez votre connexion et reessayez.', it: 'Impossibile contattare il server. Controlla la connessione e riprova.', pt: 'Nao foi possivel contactar o servidor. Verifica a ligacao e tenta novamente.');
    }
    return tr(context, es: 'No se pudo iniciar sesión. $raw', en: 'Sign-in failed. $raw', gl: 'Non se puido iniciar sesion. $raw', fr: 'Connexion impossible. $raw', it: 'Accesso non riuscito. $raw', pt: 'Nao foi possivel iniciar sessao. $raw');
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? colorScheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}