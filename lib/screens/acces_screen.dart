import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'medicamente_screen.dart';

/// Tine aplicatia in spatele contului: arata ecranul de autentificare sau de
/// blocare pana cand utilizatorul este recunoscut, apoi continutul.
class PoartaAcces extends StatefulWidget {
  final Widget child;
  const PoartaAcces({super.key, required this.child});

  @override
  State<PoartaAcces> createState() => _PoartaAccesState();
}

class _PoartaAccesState extends State<PoartaAcces> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = context.read<AuthProvider>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      auth.laPlecare();
    } else if (state == AppLifecycleState.resumed) {
      auth.laRevenire();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stare = context.watch<AuthProvider>().stare;
    // continutul ramane construit sub ecranul de blocare, ca la deblocare
    // utilizatorul sa revina exact unde era
    return Stack(
      children: [
        if (stare == StareAcces.deblocat || stare == StareAcces.blocat)
          ExcludeSemantics(
            excluding: stare != StareAcces.deblocat,
            child: widget.child,
          ),
        // fiecare stare are propriul ecran (cheie distincta): stratul lui se
        // construieste o singura data, deci nu poate fi refolosit intre stari
        if (stare == StareAcces.seIncarca)
          const _Fundal(key: ValueKey('incarcare'), child: SizedBox()),
        if (stare == StareAcces.neautentificat)
          const _Fundal(
            key: ValueKey('autentificare'),
            child: _Formular(blocat: false),
          ),
        if (stare == StareAcces.blocat)
          const _Fundal(
            key: ValueKey('blocare'),
            child: _Formular(blocat: true),
          ),
      ],
    );
  }
}

class _Fundal extends StatelessWidget {
  final Widget child;
  const _Fundal({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // ecranul sta peste navigatorul aplicatiei, deci isi aduce propriul strat
    // pentru cursor, selectie si etichetele butoanelor
    return Overlay(
      initialEntries: [OverlayEntry(builder: (context) => _continut())],
    );
  }

  Widget _continut() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Autentificarea cu e-mail si parola. Cand aplicatia e doar blocata, ofera
/// intai deblocarea biometrica si pastreaza e-mailul contului.
class _Formular extends StatefulWidget {
  final bool blocat;
  const _Formular({required this.blocat});

  @override
  State<_Formular> createState() => _FormularState();
}

class _FormularState extends State<_Formular> {
  late final _email = TextEditingController(
    text: context.read<AuthProvider>().email,
  );
  final _parola = TextEditingController();
  bool _ascunsa = true;
  bool _cuParola = false;
  String? _mesaj;
  bool _eroare = false;

  @override
  void initState() {
    super.initState();
    if (widget.blocat) {
      // fara nicio metoda de blocare pe telefon, butonul nu ar avea ce cere
      context.read<AuthProvider>().poateDebloca().then((poate) {
        if (!poate && mounted) setState(() => _cuParola = true);
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _parola.dispose();
    super.dispose();
  }

  Future<void> _intra() async {
    FocusScope.of(context).unfocus();
    final eroare = await context.read<AuthProvider>().autentifica(
      _email.text,
      _parola.text,
    );
    if (!mounted || eroare == null) return;
    setState(() {
      _mesaj = eroare;
      _eroare = true;
    });
  }

  Future<void> _reseteaza() async {
    final mesaj = await context.read<AuthProvider>().reseteazaParola(
      _email.text,
    );
    if (!mounted) return;
    setState(() {
      _mesaj = mesaj;
      _eroare = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cuFormular = !widget.blocat || _cuParola;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const EmblemaCapsula(dimensiune: 76),
        const SizedBox(height: 16),
        const Text(
          'MedRO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.blocat ? auth.email : 'Autentifică-te pentru a continua',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 28),
        if (!cuFormular) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: auth.deblocheaza,
              icon: const Icon(Icons.fingerprint, size: 26),
              label: const Text('Deblochează', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _cuParola = true),
            child: const Text(
              'Folosește parola',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _email,
                    enabled: !widget.blocat && !auth.lucreaza,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _parola,
                    enabled: !auth.lucreaza,
                    obscureText: _ascunsa,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _intra(),
                    decoration: InputDecoration(
                      labelText: 'Parolă',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _ascunsa ? 'Arată parola' : 'Ascunde parola',
                        icon: Icon(
                          _ascunsa
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _ascunsa = !_ascunsa),
                      ),
                    ),
                  ),
                  if (_mesaj != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _mesaj!,
                      style: TextStyle(
                        color: _eroare ? AppColors.red : AppColors.ink,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: auth.lucreaza ? null : _intra,
                    child: auth.lucreaza
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Intră în cont',
                            style: TextStyle(fontSize: 14.5),
                          ),
                  ),
                  TextButton(
                    onPressed: auth.lucreaza ? null : _reseteaza,
                    child: const Text('Am uitat parola'),
                  ),
                ],
              ),
            ),
          ),
        if (widget.blocat) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: auth.iesi,
            child: Text(
              'Ieși din cont',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          widget.blocat
              ? 'Aplicația se blochează la fiecare deschidere.'
              : 'Conturile sunt create de administratorul aplicației.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
