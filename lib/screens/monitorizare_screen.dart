import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../help/ajutor.dart';
import '../models/medicament.dart';
import '../providers/medicamente_provider.dart';
import '../services/data_store.dart';
import '../theme/app_theme.dart';
import '../utils/rcp_extrase.dart';
import '../utils/text_utils.dart';
import 'medicament_detail_screen.dart';

/// Psihotropele la care RCP-ul cere monitorizare, dupa codul ATC.
const substanteMonitorizate = [
  ('Litiu', 'N05AN01'),
  ('Clozapină', 'N05AH02'),
  ('Acid valproic și săruri', 'N03AG01'),
  ('Carbamazepină', 'N03AF01'),
  ('Lamotrigină', 'N03AX09'),
  ('Olanzapină', 'N05AH03'),
  ('Quetiapină', 'N05AH04'),
  ('Risperidonă', 'N05AX08'),
  ('Paliperidonă', 'N05AX13'),
  ('Aripiprazol', 'N05AX12'),
  ('Haloperidol', 'N05AD01'),
  ('Metilfenidat', 'N06BA04'),
  ('Atomoxetină', 'N06BA09'),
  ('Venlafaxină', 'N06AX16'),
];

/// Primul produs cu codul ATC dat ale carui sectiuni RCP au fost extrase,
/// impreuna cu frazele despre monitorizare.
Future<(Medicament, List<FrazaRcp>)?> monitorizareDinRcp(
  MedicamenteProvider medicamente,
  String atc,
) async {
  final tema = temeRcp.firstWhere((t) => t.id == 'monitorizare');
  final incercate = <String>{};
  for (final m in medicamente.cauta(
    '',
    FiltruMedicamente.toate,
    atcPrefix: atc,
  )) {
    if (m.rcpUrl.isEmpty || !incercate.add(m.rcpUrl)) continue;
    final sectiuni = await RcpStore.instance.sectiuni(m.rcpUrl);
    if (sectiuni.isEmpty) continue;
    return (m, extrage(tema, sectiuni, maxim: 40));
  }
  return null;
}

/// Lista substantelor cu monitorizare; fiecare deschide frazele din RCP.
class MonitorizareScreen extends StatelessWidget {
  const MonitorizareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitorizare'),
        actions: const [ButonAjutor(ajutorInstrumente)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Ce cere RCP-ul să urmărești la psihotropele cu monitorizare: analize, '
              'ECG, concentrații plasmatice. Textul este cel din document.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, (nume, atc))
                    in substanteMonitorizate.indexed) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.monitor_heart_outlined,
                      color: AppColors.blue,
                    ),
                    title: Text(
                      nume,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    subtitle: Text(
                      atc,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.muted,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _MonitorizareSubstanta(nume: nume, atc: atc),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              'Pentru orice alt medicament, aceleași fraze apar în pagina lui, la '
              '„Răspunsuri rapide din RCP” → „Monitorizare”.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitorizareSubstanta extends StatefulWidget {
  final String nume;
  final String atc;
  const _MonitorizareSubstanta({required this.nume, required this.atc});

  @override
  State<_MonitorizareSubstanta> createState() => _MonitorizareSubstantaState();
}

class _MonitorizareSubstantaState extends State<_MonitorizareSubstanta> {
  late final Future<(Medicament, List<FrazaRcp>)?> _date = monitorizareDinRcp(
    context.read<MedicamenteProvider>(),
    widget.atc,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.nume)),
      body: FutureBuilder(
        future: _date,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final date = snapshot.data;
          if (date == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Niciun produs cu această substanță nu are RCP-ul extras în '
                  'aplicație (substanța lipsește din nomenclator sau documentul nu a '
                  'putut fi citit).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ),
            );
          }
          final (m, fraze) = date;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: AppColors.blue,
                  ),
                  title: Text(
                    'Din RCP-ul ${m.denumire}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  subtitle: Text(
                    '${titleCase(m.dci)} · deschide pagina medicamentului',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MedicamentDetailScreen(medicament: m),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (fraze.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'În secțiunile 4.2 și 4.4 extrase nu apar fraze despre monitorizare.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    child: Column(
                      children: [
                        for (final f in fraze)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(
                                    top: 2,
                                    right: 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.blueSoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    f.sectiune,
                                    style: const TextStyle(
                                      color: AppColors.blue,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    f.text,
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 14.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  'Fraze extrase automat din RCP, nereformulate; lista poate fi '
                  'incompletă. Verifică documentul și ghidurile în vigoare.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
