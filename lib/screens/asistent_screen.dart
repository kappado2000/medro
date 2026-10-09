import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicament.dart';
import '../providers/asistent_provider.dart';
import '../providers/interactiuni_provider.dart';
import '../providers/medicamente_provider.dart';
import '../services/claude_client.dart';
import '../theme/app_theme.dart';

class AsistentScreen extends StatefulWidget {
  const AsistentScreen({super.key});

  @override
  State<AsistentScreen> createState() => _AsistentScreenState();
}

class _AsistentScreenState extends State<AsistentScreen> {
  final _intrebare = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _intrebare.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _trimite() async {
    final text = _intrebare.text;
    if (text.trim().isEmpty) return;
    _intrebare.clear();
    final asistent = context.read<AsistentProvider>();
    final viitor = asistent.trimite(
      text,
      context.read<MedicamenteProvider>(),
      context.read<InteractiuniProvider>(),
    );
    _laSfarsit();
    await viitor;
    _laSfarsit();
  }

  void _laSfarsit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _alegeMedicament() async {
    final ales = await showModalBottomSheet<Medicament>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (_) => const _AlegeMedicament(),
    );
    if (ales != null && mounted) {
      context.read<AsistentProvider>().ataseaza(ales);
    }
  }

  Future<void> _setari(AsistentProvider asistent) async {
    final control = TextEditingController(text: asistent.cheie);
    final rezultat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cheie API proprie (opțional)'),
        content: TextField(
          controller: control,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'sk-ant-…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Șterge', style: TextStyle(color: AppColors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, control.text),
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
    if (rezultat != null) await asistent.seteazaCheie(rezultat);
  }

  @override
  Widget build(BuildContext context) {
    final asistent = context.watch<AsistentProvider>();
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asistent',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Întrebări pe baza RCP-ului și a datelor din aplicație',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (asistent.disponibil) ...[
                    IconButton(
                      tooltip: 'Conversație nouă',
                      icon: const Icon(
                        Icons.add_comment_outlined,
                        color: Colors.white,
                      ),
                      onPressed: asistent.asteapta
                          ? null
                          : asistent.conversatieNoua,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Model',
                      icon: const Icon(Icons.tune, color: Colors.white),
                      enabled: !asistent.asteapta,
                      onSelected: asistent.seteazaModel,
                      itemBuilder: (context) => [
                        for (final e in ClaudeClient.modele.entries)
                          CheckedPopupMenuItem(
                            value: e.key,
                            checked: e.key == asistent.model,
                            child: Text(e.value),
                          ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Cheie API',
                      icon: const Icon(Icons.key_outlined, color: Colors.white),
                      onPressed: () => _setari(asistent),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: !asistent.incarcat
              ? const Center(child: CircularProgressIndicator())
              : asistent.disponibil
              ? _conversatie(asistent)
              : _FaraCheie(onSalveaza: asistent.seteazaCheie),
        ),
      ],
    );
  }

  Widget _conversatie(AsistentProvider asistent) {
    return Column(
      children: [
        _Atasate(asistent: asistent, onAdauga: _alegeMedicament),
        Expanded(
          child: asistent.mesaje.isEmpty
              ? const _Sugestii()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount:
                      asistent.mesaje.length + (asistent.asteapta ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == asistent.mesaje.length) return const _SeGandeste();
                    return _Balon(asistent.mesaje[i]);
                  },
                ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _intrebare,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _trimite(),
                    decoration: InputDecoration(
                      hintText: 'Scrie o întrebare',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: 'Trimite',
                  onPressed: asistent.asteapta ? null : _trimite,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FaraCheie extends StatefulWidget {
  final Future<void> Function(String) onSalveaza;
  const _FaraCheie({required this.onSalveaza});

  @override
  State<_FaraCheie> createState() => _FaraCheieState();
}

class _FaraCheieState extends State<_FaraCheie> {
  final _control = TextEditingController();

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.auto_awesome, size: 52, color: AppColors.blue),
        const SizedBox(height: 14),
        const Text(
          'Conectează asistentul',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Asistentul folosește modelul Claude prin contul tău Anthropic. Creează o '
          'cheie API în console.anthropic.com și lipește-o mai jos. Cheia rămâne '
          'salvată doar pe acest dispozitiv, iar fiecare întrebare se taxează pe '
          'contul tău.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _control,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'sk-ant-…',
            prefixIcon: const Icon(Icons.key_outlined, color: AppColors.blue),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => widget.onSalveaza(_control.text),
          child: const Text('Salvează cheia'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Nu introduce date care pot identifica un pacient: întrebările și '
          'documentele atașate sunt trimise către serviciul Anthropic.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.red, fontSize: 12.5, height: 1.45),
        ),
      ],
    );
  }
}

class _Atasate extends StatelessWidget {
  final AsistentProvider asistent;
  final VoidCallback onAdauga;
  const _Atasate({required this.asistent, required this.onAdauga});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final m in asistent.atasate)
                InputChip(
                  label: Text(m.denumire),
                  avatar: const Icon(
                    Icons.medication_outlined,
                    size: 18,
                    color: AppColors.blue,
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.blue),
                  labelStyle: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  deleteIconColor: AppColors.blue,
                  onDeleted: asistent.asteapta
                      ? null
                      : () => asistent.detaseaza(m),
                ),
              ActionChip(
                label: const Text('Atașează medicament'),
                avatar: const Icon(Icons.add, size: 18, color: AppColors.blue),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.line),
                onPressed: asistent.asteapta ? null : onAdauga,
              ),
            ],
          ),
          if (asistent.includeRcp && asistent.atasate.any((m) => m.centralizat))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'RCP-ul de la EMA este un document lung (toate concentrațiile și '
                'prospectul): prima întrebare costă de câteva ori mai mult.',
                style: TextStyle(color: AppColors.red, fontSize: 12.5),
              ),
            ),
          if (asistent.atasate.isNotEmpty)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Trimite și RCP-ul (răspuns cu trimiteri la pagină, cost mai mare)',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ),
                Switch(
                  value: asistent.includeRcp,
                  onChanged: asistent.asteapta
                      ? null
                      : asistent.seteazaIncludeRcp,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Sugestii extends StatelessWidget {
  const _Sugestii();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 8),
        Text(
          'Atașează unul sau mai multe medicamente și întreabă, de exemplu:',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        _Exemplu('Cum se ajustează doza în insuficiența renală?'),
        _Exemplu(
          'Care este mecanismul interacțiunii dintre cele două și ce conduită se recomandă?',
        ),
        _Exemplu('Ce monitorizare cere RCP-ul la inițierea tratamentului?'),
        _Exemplu('Rezumă contraindicațiile și atenționările speciale.'),
        SizedBox(height: 16),
        Text(
          'Răspunsurile sunt generate de un model AI și pot conține erori. Verifică '
          'pasajele citate din RCP. Nu introduce date care pot identifica un pacient.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _Exemplu extends StatelessWidget {
  final String text;
  const _Exemplu(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 16,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _Balon extends StatelessWidget {
  final MesajAsistent mesaj;
  const _Balon(this.mesaj);

  @override
  Widget build(BuildContext context) {
    final m = mesaj;
    final culoare = m.utilizator
        ? AppColors.blue
        : (m.avertizare ? AppColors.redSoft : Colors.white);
    final culoareText = m.utilizator
        ? Colors.white
        : (m.avertizare ? AppColors.red : AppColors.ink);
    return Align(
      alignment: m.utilizator ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        decoration: BoxDecoration(
          color: culoare,
          borderRadius: BorderRadius.circular(16),
          border: m.utilizator || m.avertizare
              ? null
              : Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              m.text,
              style: TextStyle(
                color: culoareText,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
            if (m.citari.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Citari(m.citari),
            ],
          ],
        ),
      ),
    );
  }
}

class _Citari extends StatelessWidget {
  final List<Citare> citari;
  const _Citari(this.citari);

  @override
  Widget build(BuildContext context) {
    // aceeasi pagina citata de mai multe ori apare o singura data
    final unice = <String, Citare>{
      for (final c in citari) '${c.document}|${c.pagina}': c,
    }.values.toList();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          'Surse din RCP (${unice.length})',
          style: const TextStyle(
            color: AppColors.blue,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          for (final c in unice)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.pagina == null
                        ? c.document
                        : '${c.document}, pagina ${c.pagina}',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    c.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      height: 1.4,
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

class _SeGandeste extends StatelessWidget {
  const _SeGandeste();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Asistentul citește și formulează răspunsul…',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AlegeMedicament extends StatefulWidget {
  const _AlegeMedicament();

  @override
  State<_AlegeMedicament> createState() => _AlegeMedicamentState();
}

class _AlegeMedicamentState extends State<_AlegeMedicament> {
  String _interogare = '';

  @override
  Widget build(BuildContext context) {
    final rezultate = _interogare.trim().isEmpty
        ? const <Medicament>[]
        : context
              .read<MedicamenteProvider>()
              .cauta(_interogare, FiltruMedicamente.toate)
              .take(40)
              .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _interogare = v),
                decoration: InputDecoration(
                  hintText: 'Caută medicamentul de atașat',
                  prefixIcon: const Icon(Icons.search, color: AppColors.blue),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rezultate.length,
                itemBuilder: (context, i) {
                  final m = rezultate[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.medication_outlined,
                      color: AppColors.blue,
                    ),
                    title: Text(
                      m.denumire,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      m.rcpUrl.isEmpty
                          ? '${m.dci} · fără RCP disponibil'
                          : m.dci,
                    ),
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
