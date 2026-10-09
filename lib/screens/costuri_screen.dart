import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../help/ajutor.dart';
import '../providers/asistent_provider.dart';
import '../services/costuri.dart';
import '../theme/app_theme.dart';
import '../tools/plan_doze.dart';

/// Cate intrebari au fost puse asistentului si cat au costat.
class CosturiScreen extends StatelessWidget {
  const CosturiScreen({super.key});

  Future<void> _goleste(BuildContext context) async {
    final asistent = context.read<AsistentProvider>();
    final da = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergi jurnalul?'),
        content: const Text(
          'Se șterg toate înregistrările de pe acest telefon. Cheltuielile reale '
          'rămân vizibile în consola Anthropic.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Renunță'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Șterge', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (da == true) await asistent.golesteCosturi();
  }

  @override
  Widget build(BuildContext context) {
    final jurnal = context.watch<AsistentProvider>().costuri;
    final acum = DateTime.now();
    final recente = jurnal.toate.take(50).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Costuri'),
        actions: [
          const ButonAjutor(ajutorCosturi),
          if (!jurnal.gol)
            IconButton(
              tooltip: 'Șterge jurnalul',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _goleste(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: _Caseta('Azi', jurnal.zi(acum))),
              const SizedBox(width: 10),
              Expanded(
                child: _Caseta('Luna aceasta', jurnal.luna(acum), accent: true),
              ),
              const SizedBox(width: 10),
              Expanded(child: _Caseta('Total', jurnal.total)),
            ],
          ),
          const SizedBox(height: 16),
          if (jurnal.gol)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nicio întrebare înregistrată încă. Fiecare răspuns al asistentului '
                  'apare aici, cu numărul de tokeni și costul lui.',
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ),
            )
          else ...[
            const _Titlu('Pe luni'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final (i, (luna, s)) in jurnal.peLuni.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      _Rand(
                        titlu: numeLuna(luna),
                        subtitlu: _interogari(s.interogari),
                        valoare: formatUsd(s.cost),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Titlu(
              recente.length < jurnal.total.interogari
                  ? 'Ultimele ${recente.length} întrebări'
                  : 'Întrebări',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final (i, q) in recente.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      _Rand(
                        titlu:
                            '${formatData(q.data, cuZi: false)}, ${_ora(q.data)}',
                        subtitlu: _detalii(q),
                        valoare: formatUsd(q.cost),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const _Titlu('Cum se calculează'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Se plătește pe tokeni (bucăți de text de 3–4 caractere), nu pe '
                    'întrebare. Prețuri în USD pentru un milion de tokeni:',
                    style: TextStyle(color: AppColors.ink, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  for (final t in tarife.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${t.nume}: intrare ${_pret(t.intrare)} · document nou '
                        '${_pret(t.scriereCache)} · document refolosit '
                        '${_pret(t.citireCache)} · răspuns ${_pret(t.iesire)}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  const Text(
                    'Documentul RCP se plătește întreg la prima întrebare din '
                    'conversație și la o zecime la următoarele, dacă vin în câteva '
                    'minute.',
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              'Sumele sunt estimări calculate din tokenii raportați la fiecare '
              'răspuns și cuprind doar întrebările puse de pe acest telefon. '
              'Factura reală este în consola Anthropic, la Usage și Cost.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _pret(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} \$';

  static String _ora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _interogari(int n) => switch (n) {
    1 => 'o întrebare',
    _ => n % 100 >= 20 || n % 100 == 0 ? '$n de întrebări' : '$n întrebări',
  };

  static String _detalii(Interogare q) {
    final c = q.consum;
    return [
      tarifPentru(c.model).nume,
      '${formatTokeni(c.totalIntrare)} tokeni trimiși',
      '${formatTokeni(c.iesire)} primiți',
      if (q.documente == 1) 'un RCP',
      if (q.documente > 1) '${q.documente} RCP-uri',
      if (c.citireCache > 0) 'document refolosit',
    ].join(' · ');
  }
}

class _Caseta extends StatelessWidget {
  final String titlu;
  final Sumar sumar;
  final bool accent;
  const _Caseta(this.titlu, this.sumar, {this.accent = false});

  @override
  Widget build(BuildContext context) {
    final culoare = accent ? Colors.white : AppColors.ink;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: accent ? AppColors.headerGradient : null,
        color: accent ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: accent ? null : Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titlu,
            style: TextStyle(
              color: accent ? Colors.white70 : AppColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatUsd(sumar.cost),
              style: TextStyle(color: culoare, fontSize: 17),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CosturiScreen._interogari(sumar.interogari),
              style: TextStyle(
                color: accent ? Colors.white70 : AppColors.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Titlu extends StatelessWidget {
  final String text;
  const _Titlu(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _Rand extends StatelessWidget {
  final String titlu;
  final String subtitlu;
  final String valoare;
  const _Rand({
    required this.titlu,
    required this.subtitlu,
    required this.valoare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titlu,
                  style: const TextStyle(color: AppColors.ink, fontSize: 13.5),
                ),
                Text(
                  subtitlu,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            valoare,
            style: const TextStyle(color: AppColors.blue, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
