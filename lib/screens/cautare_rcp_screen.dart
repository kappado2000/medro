import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../help/ajutor.dart';
import '../models/medicament.dart';
import '../providers/medicamente_provider.dart';
import '../services/cautare_rcp.dart';
import '../theme/app_theme.dart';
import '../utils/clase_psihotrope.dart';
import '../utils/text_utils.dart';
import 'medicament_detail_screen.dart';

/// Unde se cauta: eticheta afisata si sectiunile RCP corespunzatoare.
const zoneCautare = <(String, List<String>)>[
  (
    'Peste tot',
    ['4.1', '4.2', '4.3', '4.4', '4.5', '4.6', '4.7', '4.8', '4.9'],
  ),
  ('Indicații', ['4.1']),
  ('Doze', ['4.2']),
  ('Contraindicații', ['4.3']),
  ('Atenționări', ['4.4']),
  ('Interacțiuni', ['4.5']),
  ('Sarcină', ['4.6']),
  ('Reacții adverse', ['4.8']),
];

/// Cautare in textul RCP-urilor: gaseste medicamentele dupa ce scrie in
/// documentul lor, nu dupa nume.
class CautareRcpScreen extends StatefulWidget {
  const CautareRcpScreen({super.key});

  @override
  State<CautareRcpScreen> createState() => _CautareRcpScreenState();
}

class _CautareRcpScreenState extends State<CautareRcpScreen> {
  final _controller = TextEditingController();
  int _zona = 1; // indicatiile sunt cautarea cea mai frecventa
  ClasaAtc? _clasa;
  StreamSubscription<ProgresCautare>? _cautare;
  ProgresCautare? _progres;
  String _cautat = '';

  @override
  void dispose() {
    _cautare?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _cauta() {
    FocusScope.of(context).unfocus();
    final interogare = _controller.text.trim();
    _cautare?.cancel();
    if (cuvinteCautate(interogare).isEmpty) {
      setState(() {
        _progres = null;
        _cautat = '';
      });
      return;
    }
    setState(() {
      _cautat = interogare;
      _progres = const ProgresCautare(0, []);
    });
    _cautare =
        cautaInRcp(
          interogare,
          sectiuni: zoneCautare[_zona].$2,
          contraindicatii: context
              .read<MedicamenteProvider>()
              .toateContraindicatiile,
        ).listen((p) {
          if (mounted) setState(() => _progres = p);
        });
  }

  @override
  Widget build(BuildContext context) {
    final med = context.watch<MedicamenteProvider>();
    final progres = _progres;
    final rezultate = progres == null
        ? const <(PotrivireRcp, List<Medicament>)>[]
        : _cuProduse(med, progres.potriviri);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Căutare în RCP'),
        actions: const [ButonAjutor(ajutorCautareRcp)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _cauta(),
              decoration: InputDecoration(
                hintText: 'ex. tulburare bipolară, prolactină',
                prefixIcon: const Icon(
                  Icons.manage_search,
                  color: AppColors.blue,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Caută',
                  icon: const Icon(Icons.arrow_forward, color: AppColors.blue),
                  onPressed: _cauta,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              itemCount: zoneCautare.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 0) return _chipClasa();
                final ales = _zona == i - 1;
                return ChoiceChip(
                  label: Text(zoneCautare[i - 1].$1),
                  selected: ales,
                  showCheckmark: false,
                  selectedColor: AppColors.blue,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: ales ? AppColors.blue : AppColors.line,
                  ),
                  labelStyle: TextStyle(
                    color: ales ? Colors.white : AppColors.ink,
                  ),
                  onSelected: (_) {
                    setState(() => _zona = i - 1);
                    if (_cautat.isNotEmpty) _cauta();
                  },
                );
              },
            ),
          ),
          if (progres != null && !progres.gata)
            LinearProgressIndicator(value: progres.parcurs, minHeight: 3),
          Expanded(child: _continut(progres, rezultate)),
        ],
      ),
    );
  }

  Widget _chipClasa() {
    final activ = _clasa != null;
    return ChoiceChip(
      label: Text(_clasa?.nume ?? 'Orice clasă'),
      selected: activ,
      showCheckmark: false,
      avatar: Icon(
        Icons.psychology_outlined,
        size: 18,
        color: activ ? Colors.white : AppColors.blue,
      ),
      selectedColor: AppColors.blue,
      backgroundColor: Colors.white,
      side: BorderSide(color: activ ? AppColors.blue : AppColors.line),
      labelStyle: TextStyle(color: activ ? Colors.white : AppColors.ink),
      onSelected: (_) async {
        final aleasa = await showModalBottomSheet<ClasaAtc?>(
          context: context,
          backgroundColor: Colors.white,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Orice clasă'),
                  onTap: () => Navigator.pop(context),
                ),
                for (final c in clasePsihotrope)
                  ListTile(
                    title: Text(c.nume),
                    subtitle: Text(c.prefix),
                    onTap: () => Navigator.pop(context, c),
                  ),
              ],
            ),
          ),
        );
        if (mounted) setState(() => _clasa = aleasa);
      },
    );
  }

  /// Leaga fiecare text gasit de produsele care il au si aplica filtrul de
  /// clasa. Un text comun mai multor concentratii apare o singura data.
  List<(PotrivireRcp, List<Medicament>)> _cuProduse(
    MedicamenteProvider med,
    List<PotrivireRcp> potriviri,
  ) {
    final out = <(PotrivireRcp, List<Medicament>)>[];
    final vazute = <String>{};
    for (final p in potriviri) {
      final produse = [
        for (final m in med.produseCuTextul(p.cheie))
          if (_clasa == null || m.atc.startsWith(_clasa!.prefix)) m,
      ];
      if (produse.isEmpty) continue;
      // contraindicatiile si sectiunile aceluiasi produs nu se repeta
      if (!vazute.add('${baseDenumire(produse.first)}|${produse.first.dci}')) {
        continue;
      }
      out.add((p, produse));
    }
    out.sort(
      (a, b) => a.$2.first.denumireNorm.compareTo(b.$2.first.denumireNorm),
    );
    return out;
  }

  static String baseDenumire(Medicament m) =>
      m.denumire.split(RegExp(r'[\d®]')).first.trim();

  Widget _continut(
    ProgresCautare? progres,
    List<(PotrivireRcp, List<Medicament>)> rezultate,
  ) {
    if (progres == null) {
      return const _Mesaj(
        icon: Icons.manage_search,
        titlu: 'Caută în textul RCP-urilor',
        text:
            'Scrie unul sau mai multe cuvinte și apasă săgeata. Găsești '
            'medicamentele în al căror RCP apar toate cuvintele, în aceeași '
            'secțiune. Alege mai sus secțiunea și, dacă vrei, clasa.',
      );
    }
    if (rezultate.isEmpty) {
      return progres.gata
          ? _Mesaj(
              icon: Icons.search_off,
              titlu: 'Nimic găsit',
              text:
                  'Niciun RCP nu conține „$_cautat” în ${zoneCautare[_zona].$1.toLowerCase()}'
                  '${_clasa == null ? '' : ', la ${_clasa!.nume.toLowerCase()}'}. '
                  'Încearcă mai puține cuvinte sau altă secțiune.',
            )
          : const SizedBox();
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: rezultate.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              progres.gata
                  ? '${rezultate.length} medicamente'
                        '${progres.trunchiat ? ' (primele găsite; restrânge căutarea)' : ''}'
                  : 'Se caută… ${rezultate.length} până acum',
              style: const TextStyle(color: AppColors.muted),
            ),
          );
        }
        final (p, produse) = rezultate[i - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _Rezultat(potrivire: p, produse: produse),
        );
      },
    );
  }
}

class _Rezultat extends StatelessWidget {
  final PotrivireRcp potrivire;
  final List<Medicament> produse;
  const _Rezultat({required this.potrivire, required this.produse});

  @override
  Widget build(BuildContext context) {
    final m = produse.first;
    final contraindicatie = potrivire.sectiune == '4.3';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MedicamentDetailScreen(medicament: m),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      m.denumire,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              Text(
                [
                  titleCase(m.dci),
                  if (produse.length > 1)
                    'același text la încă ${produse.length - 1} '
                        '${produse.length == 2 ? 'produs' : 'produse'}',
                ].join(' · '),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2, right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: contraindicatie
                          ? AppColors.redSoft
                          : AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      potrivire.sectiune,
                      style: TextStyle(
                        color: contraindicatie ? AppColors.red : AppColors.blue,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      potrivire.fragment,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mesaj extends StatelessWidget {
  final IconData icon;
  final String titlu;
  final String text;
  const _Mesaj({required this.icon, required this.titlu, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 12),
        Icon(icon, size: 52, color: AppColors.blue),
        const SizedBox(height: 14),
        Text(
          titlu,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, height: 1.45),
        ),
      ],
    );
  }
}
