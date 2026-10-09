import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicament.dart';
import '../providers/interactiuni_provider.dart';
import '../providers/medicamente_provider.dart';
import '../theme/app_theme.dart';

String etichetaSeveritate(Severitate s) {
  switch (s) {
    case Severitate.majora:
      return 'Majoră';
    case Severitate.moderata:
      return 'Moderată';
    case Severitate.minora:
      return 'Minoră';
    case Severitate.neprecizata:
      return 'Severitate neprecizată';
  }
}

Color culoareSeveritate(Severitate s) {
  switch (s) {
    case Severitate.majora:
      return AppColors.red;
    case Severitate.moderata:
      return AppColors.blue;
    case Severitate.minora:
    case Severitate.neprecizata:
      return AppColors.muted;
  }
}

class InteractiuniScreen extends StatefulWidget {
  const InteractiuniScreen({super.key});

  @override
  State<InteractiuniScreen> createState() => _InteractiuniScreenState();
}

class _InteractiuniScreenState extends State<InteractiuniScreen> {
  final _controller = TextEditingController();
  List<Substanta> get _selectie =>
      context.read<InteractiuniProvider>().selectie;
  String _interogare = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _adauga(Iterable<Substanta> substante) {
    setState(() {
      context.read<InteractiuniProvider>().adaugaInSelectie(substante);
      _controller.clear();
      _interogare = '';
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InteractiuniProvider>();
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Interacțiuni',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.incarcat && provider.eroare == null
                        ? '${provider.totalSubstante} substanțe · DDInter 2.0'
                        : 'Se încarcă baza de interacțiuni…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _interogare = v),
                    decoration: InputDecoration(
                      hintText: 'Adaugă o substanță sau un medicament',
                      hintStyle: const TextStyle(color: AppColors.muted),
                      prefixIcon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.blue,
                      ),
                      suffixIcon: _interogare.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.muted,
                              ),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _interogare = '');
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _continut(provider)),
      ],
    );
  }

  Widget _continut(InteractiuniProvider provider) {
    if (!provider.incarcat) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.eroare != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Baza de interacțiuni nu a putut fi încărcată.\n${provider.eroare}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.red),
          ),
        ),
      );
    }
    if (_interogare.trim().isNotEmpty) return _sugestii(provider);
    return _rezultate(provider);
  }

  Widget _sugestii(InteractiuniProvider provider) {
    final substante = provider.cauta(_interogare);
    // medicamentele gasite dupa denumirea comerciala, cu substantele lor
    final produse = <(Medicament, List<Substanta>)>[];
    final vazute = <String>{};
    for (final m in context.read<MedicamenteProvider>().cauta(
      _interogare,
      FiltruMedicamente.toate,
    )) {
      final s = provider.substanteProdus(m.dci);
      if (s.isEmpty || !vazute.add('${baseName(m.denumire)}|${m.dci}')) {
        continue;
      }
      produse.add((m, s));
      if (produse.length == 15) break;
    }
    if (substante.isEmpty && produse.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nicio substanță găsită în baza de interacțiuni.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (substante.isNotEmpty) const _Titlu('Substanțe'),
        for (final s in substante)
          _Sugestie(
            icon: Icons.science_outlined,
            titlu: s.nume,
            subtitlu: s.denumireEn,
            onTap: () => _adauga([s]),
          ),
        if (produse.isNotEmpty) const _Titlu('Medicamente'),
        for (final (m, s) in produse)
          _Sugestie(
            icon: Icons.medication_outlined,
            titlu: baseName(m.denumire),
            subtitlu: s.map((x) => x.nume).join(' + '),
            onTap: () => _adauga(s),
          ),
      ],
    );
  }

  Widget _rezultate(InteractiuniProvider provider) {
    if (_selectie.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.compare_arrows, size: 56, color: AppColors.blue),
          const SizedBox(height: 16),
          const Text(
            'Verifică interacțiunile dintre medicamente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adaugă două sau mai multe substanțe ori medicamente. Cu o singură '
            'substanță vezi toate interacțiunile ei majore.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 28),
          _Nota(provider.sursa),
        ],
      );
    }
    final interactiuni = provider.verifica(_selectie);
    final perechi = _selectie.length * (_selectie.length - 1) ~/ 2;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _selectie)
              InputChip(
                label: Text(s.nume),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.blue),
                labelStyle: const TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w700,
                ),
                deleteIconColor: AppColors.blue,
                onDeleted: () => provider.scoateDinSelectie(s),
              ),
            if (_selectie.length > 1)
              ActionChip(
                label: const Text('Golește'),
                avatar: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.red,
                ),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.line),
                onPressed: provider.golesteSelectia,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectie.length == 1)
          ..._oSingura(provider, _selectie.first)
        else ...[
          _Sumar(interactiuni: interactiuni, perechi: perechi),
          const SizedBox(height: 12),
          for (final i in interactiuni)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InteractiuneCard(i),
            ),
        ],
        const SizedBox(height: 8),
        _Nota(provider.sursa),
      ],
    );
  }

  List<Widget> _oSingura(InteractiuniProvider provider, Substanta s) {
    final majore = provider.partenere(s, Severitate.majora);
    return [
      _Titlu('Interacțiuni majore ale substanței (${majore.length})'),
      if (majore.isEmpty)
        const Text(
          'Nicio interacțiune majoră înregistrată.',
          style: TextStyle(color: AppColors.muted),
        )
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in majore)
                  ActionChip(
                    label: Text(p.nume),
                    backgroundColor: AppColors.redSoft,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    onPressed: () => _adauga([p]),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Denumirea comerciala fara concentratie: "ZOLOFT 50 mg" -> "ZOLOFT".
String baseName(String denumire) {
  final baza = denumire.split(RegExp(r'[\d®]')).first.trim();
  return baza.isEmpty ? denumire : baza;
}

class _Titlu extends StatelessWidget {
  final String text;
  const _Titlu(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _Sugestie extends StatelessWidget {
  final IconData icon;
  final String titlu;
  final String subtitlu;
  final VoidCallback onTap;

  const _Sugestie({
    required this.icon,
    required this.titlu,
    required this.subtitlu,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: AppColors.blue),
          title: Text(
            titlu,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            subtitlu,
            style: const TextStyle(color: AppColors.muted),
          ),
          trailing: const Icon(Icons.add, color: AppColors.blue),
        ),
      ),
    );
  }
}

/// Textul sumarului, cu acordul corect la singular si plural.
String textSumar(int interactiuni, int perechi, int majore) {
  final verificate = perechi == 1
      ? 'perechea verificată'
      : 'cele $perechi perechi verificate';
  if (interactiuni == 0) {
    return 'Nicio interacțiune înregistrată pentru $verificate.';
  }
  final gasite = interactiuni == 1
      ? 'O interacțiune'
      : '$interactiuni interacțiuni';
  final din = perechi == 1 ? 'la perechea verificată' : 'din $perechi perechi';
  final grave = switch (majore) {
    0 => '',
    1 => interactiuni == 1 ? ', majoră' : ', dintre care una majoră',
    _ =>
      majore == interactiuni
          ? ', toate majore'
          : ', dintre care $majore majore',
  };
  return '$gasite $din$grave.';
}

class _Sumar extends StatelessWidget {
  final List<Interactiune> interactiuni;
  final int perechi;
  const _Sumar({required this.interactiuni, required this.perechi});

  @override
  Widget build(BuildContext context) {
    final majore = interactiuni
        .where((i) => i.severitate == Severitate.majora)
        .length;
    final faraInteractiuni = interactiuni.isEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: majore > 0
            ? const LinearGradient(colors: [AppColors.red, Color(0xFFA81426)])
            : AppColors.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            majore > 0
                ? Icons.warning_amber_rounded
                : (faraInteractiuni
                      ? Icons.info_outline
                      : Icons.compare_arrows),
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              textSumar(interactiuni.length, perechi, majore),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiuneCard extends StatelessWidget {
  final Interactiune interactiune;
  const _InteractiuneCard(this.interactiune);

  @override
  Widget build(BuildContext context) {
    final i = interactiune;
    final culoare = culoareSeveritate(i.severitate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 46,
              decoration: BoxDecoration(
                color: culoare,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i.a.nume} + ${i.b.nume}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    etichetaSeveritate(i.severitate),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: culoare,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  final String sursa;
  const _Nota(this.sursa);

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sursă: $sursa. Datele conțin doar nivelul de severitate, fără mecanism sau '
      'conduită. Lipsa unei interacțiuni din listă nu înseamnă că ea nu există. '
      'Verifică întotdeauna RCP-ul.',
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12.5,
        height: 1.45,
      ),
    );
  }
}
