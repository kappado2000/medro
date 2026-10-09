import 'package:flutter/material.dart';

import '../help/ajutor.dart';
import '../theme/app_theme.dart';
import '../tools/depot.dart';
import '../tools/plan_doze.dart';
import '../widgets/instrument_widgets.dart';

/// Calendarul urmatoarelor administrari ale unui antipsihotic depot.
class DepotScreen extends StatefulWidget {
  const DepotScreen({super.key});

  @override
  State<DepotScreen> createState() => _DepotScreenState();
}

class _DepotScreenState extends State<DepotScreen> {
  Depot _depot = depoturi.first;
  late final _interval = TextEditingController(text: '${_depot.interval}');
  late bool _inLuni = _depot.inLuni;
  DateTime _ultima = DateTime.now();

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  void _alege(Depot d) {
    setState(() {
      _depot = d;
      _interval.text = '${d.interval}';
      _inLuni = d.inLuni;
    });
  }

  @override
  Widget build(BuildContext context) {
    final interval = int.tryParse(_interval.text.trim()) ?? 0;
    // fereastra din RCP este valabila doar pentru intervalul standard
    final standard = interval == _depot.interval && _inLuni == _depot.inLuni;
    final program = programDepot(
      ultima: _ultima,
      interval: interval,
      inLuni: _inLuni,
      zileInainte: standard ? _depot.zileInainte : null,
      zileDupa: standard ? _depot.zileDupa : null,
    );
    final azi = DateTime.now();
    final astazi = DateTime(azi.year, azi.month, azi.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Injecții depot'),
        actions: const [ButonAjutor(ajutorInstrumente)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const TitluGrup('Preparat'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Depot>(
                    initialValue: _depot,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    items: [
                      for (final d in depoturi)
                        DropdownMenuItem(value: d, child: Text(d.nume)),
                    ],
                    onChanged: (d) {
                      if (d != null) _alege(d);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _depot.produse,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (_depot.nota.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _depot.nota,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const TitluGrup('Interval'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CampValoare(
                          eticheta: 'O injecție la fiecare',
                          unitate: '',
                          controller: _interval,
                          onSchimbat: () => setState(() {}),
                          intreg: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('zile')),
                            ButtonSegment(value: true, label: Text('luni')),
                          ],
                          selected: {_inLuni},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) =>
                              setState(() => _inLuni = s.first),
                        ),
                      ),
                    ],
                  ),
                  RandData(
                    eticheta: 'Ultima administrare',
                    data: _ultima,
                    onSchimbat: (d) => setState(() => _ultima = d),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const TitluGrup('Următoarele administrări'),
          if (program.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Completează intervalul dintre injecții.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final (i, a) in program.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      _RandAdministrare(a, astazi),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ButonCopiaza(textProgram(_depot.nume, _ultima, program)),
          ],
          NotaInstrument(
            standard
                ? 'Intervalele și ferestrele sunt cele din RCP-urile produselor. '
                      'Verifică RCP-ul la inițiere, la doze omise și la schimbarea preparatului.'
                : 'Ai modificat intervalul standard: fereastra de administrare din RCP '
                      'nu mai este afișată. Verifică RCP-ul.',
          ),
        ],
      ),
    );
  }
}

class _RandAdministrare extends StatelessWidget {
  final Administrare a;
  final DateTime astazi;
  const _RandAdministrare(this.a, this.astazi);

  @override
  Widget build(BuildContext context) {
    final zile = a.data.difference(astazi).inDays;
    final cand = switch (zile) {
      0 => 'astăzi',
      1 => 'mâine',
      < 0 => zile == -1 ? 'ieri' : 'acum ${-zile} zile',
      _ => 'peste $zile zile',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatData(a.data),
                  style: const TextStyle(color: AppColors.ink, fontSize: 15),
                ),
                if (a.deLa != null && a.panaLa != null)
                  Text(
                    'fereastră: ${formatData(a.deLa!, cuZi: false)} – '
                    '${formatData(a.panaLa!, cuZi: false)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            cand,
            style: TextStyle(
              color: zile < 0 ? AppColors.red : AppColors.blue,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
