import 'package:flutter/material.dart';

import '../help/ajutor.dart';
import '../theme/app_theme.dart';
import '../tools/plan_doze.dart';
import '../widgets/instrument_widgets.dart';

/// Planificator pentru reducerea sau cresterea treptata a unei doze.
class PlanDozeScreen extends StatefulWidget {
  const PlanDozeScreen({super.key});

  @override
  State<PlanDozeScreen> createState() => _PlanDozeScreenState();
}

class _PlanDozeScreenState extends State<PlanDozeScreen> {
  final _start = TextEditingController();
  final _tinta = TextEditingController(text: '0');
  final _pas = TextEditingController(text: '10');
  final _interval = TextEditingController(text: '14');
  final _rotunjire = TextEditingController();
  TipPas _tip = TipPas.procent;
  DateTime _inceput = DateTime.now();

  @override
  void dispose() {
    for (final c in [_start, _tinta, _pas, _interval, _rotunjire]) {
      c.dispose();
    }
    super.dispose();
  }

  void _actualizeaza() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final start = citesteNumar(_start);
    final tinta = citesteNumar(_tinta);
    final pas = citesteNumar(_pas);
    final interval = int.tryParse(_interval.text.trim());
    final complet =
        start != null && tinta != null && pas != null && interval != null;
    final pasi = complet
        ? planDoze(
            start: start,
            tinta: tinta,
            tip: _tip,
            pas: pas,
            intervalZile: interval,
            inceput: _inceput,
            rotunjire: citesteNumar(_rotunjire) ?? 0,
          )
        : const <PasDoza>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de doze'),
        actions: const [ButonAjutor(ajutorInstrumente)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const TitluGrup('Doze'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  CampValoare(
                    eticheta: 'Doza actuală, pe zi',
                    unitate: 'mg',
                    controller: _start,
                    onSchimbat: _actualizeaza,
                  ),
                  CampValoare(
                    eticheta: 'Doza țintă (0 = oprire)',
                    unitate: 'mg',
                    controller: _tinta,
                    onSchimbat: _actualizeaza,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const TitluGrup('Ritm'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SegmentedButton<TipPas>(
                      segments: const [
                        ButtonSegment(
                          value: TipPas.procent,
                          label: Text('% din doza curentă'),
                        ),
                        ButtonSegment(
                          value: TipPas.fix,
                          label: Text('mg la fiecare pas'),
                        ),
                      ],
                      selected: {_tip},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _tip = s.first),
                    ),
                  ),
                  CampValoare(
                    eticheta: 'Schimbare la fiecare pas',
                    unitate: _tip == TipPas.procent ? '%' : 'mg',
                    controller: _pas,
                    onSchimbat: _actualizeaza,
                  ),
                  CampValoare(
                    eticheta: 'Un pas la fiecare',
                    unitate: 'zile',
                    controller: _interval,
                    onSchimbat: _actualizeaza,
                    intreg: true,
                  ),
                  CampValoare(
                    eticheta: 'Fracțiune minimă (opțional)',
                    unitate: 'mg',
                    controller: _rotunjire,
                    onSchimbat: _actualizeaza,
                  ),
                  RandData(
                    eticheta: 'Primul pas începe',
                    data: _inceput,
                    onSchimbat: (d) => setState(() => _inceput = d),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const TitluGrup('Plan'),
          if (pasi.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  complet
                      ? 'Cu aceste valori nu rezultă un plan: verifică dozele și pasul.'
                      : 'Completează doza actuală, doza țintă și ritmul.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final (i, p) in pasi.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      _RandPas(numar: i + 1, pas: p),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _rezumat(pasi),
                style: const TextStyle(color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 10),
            ButonCopiaza(textPlan(pasi, start!, 'mg')),
          ],
          const NotaInstrument(
            'Calcul aritmetic, nu o recomandare. Ritmul se adaptează la medicament, '
            'la durata tratamentului și la toleranța pacientului; unele medicamente '
            'nu au concentrații care să permită toate dozele din plan. La reducerea '
            'procentuală spre zero, planul se oprește când doza scade sub 10% din '
            'cea inițială.',
          ),
        ],
      ),
    );
  }

  String _rezumat(List<PasDoza> pasi) {
    final zile = pasi.last.data.difference(pasi.first.data).inDays;
    final durata = zile == 0
        ? 'într-un singur pas'
        : 'în ${pasi.length} pași, pe ${(zile / 7).ceil()} săptămâni';
    return 'Ținta este atinsă pe ${formatData(pasi.last.data, cuZi: false)}, $durata.';
  }
}

class _RandPas extends StatelessWidget {
  final int numar;
  final PasDoza pas;
  const _RandPas({required this.numar, required this.pas});

  @override
  Widget build(BuildContext context) {
    final oprire = pas.doza == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$numar',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              'din ${formatData(pas.data)}',
              style: const TextStyle(color: AppColors.ink, fontSize: 13.5),
            ),
          ),
          Text(
            oprire ? 'oprire' : '${formatDoza(pas.doza)} mg',
            style: TextStyle(
              color: oprire ? AppColors.red : AppColors.blue,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
