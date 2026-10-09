import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../help/ajutor.dart';
import '../models/medicament.dart';
import '../providers/asistent_provider.dart';
import '../providers/interactiuni_provider.dart';
import '../providers/medicamente_provider.dart';
import '../theme/app_theme.dart';
import '../utils/text_utils.dart';
import '../widgets/medicament_widgets.dart';
import '../widgets/sectiuni_rcp.dart';
import 'home_shell.dart';

class MedicamentDetailScreen extends StatelessWidget {
  final Medicament medicament;
  const MedicamentDetailScreen({super.key, required this.medicament});

  Future<void> _deschide(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documentul nu a putut fi deschis.')),
      );
    }
  }

  /// Pentru produsele autorizate centralizat documentele sunt la EMA.
  String get _emaUrl {
    final nume = medicament.denumire.split(RegExp(r'[\d®]')).first.trim();
    return Uri.https('www.ema.europa.eu', '/en/medicines', {
      'search_api_fulltext': nume,
    }).toString();
  }

  @override
  Widget build(BuildContext context) {
    final m = medicament;
    final provider = context.watch<MedicamenteProvider>();
    final favorit = provider.esteFavorit(m);
    final echivalente = provider.echivalente(m);
    final explicatie = explicatiePrescriptie(m.prescriptie);
    final contraindicatii = provider.contraindicatii(m);
    final substante = context.read<InteractiuniProvider>().substanteProdus(
      m.dci,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.blue,
            title: Text(
              m.denumire,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              const ButonAjutor(ajutorPaginaMedicament),
              IconButton(
                tooltip: favorit ? 'Scoate din favorite' : 'Adaugă la favorite',
                icon: Icon(
                  favorit ? Icons.favorite : Icons.favorite_border,
                  color: favorit ? AppColors.red : Colors.white,
                ),
                onPressed: () => provider.comutaFavorit(m),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.denumire,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    titleCase(m.dci),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pastila(
                        icon: iconForma(m.forma),
                        text: m.forma.toLowerCase(),
                      ),
                      if (m.concentratie.isNotEmpty)
                        _Pastila(
                          icon: Icons.science_outlined,
                          text: m.concentratie,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.list(
              children: [
                if (contraindicatii != null) ...[
                  _Contraindicatii(contraindicatii),
                  const SizedBox(height: 14),
                ],
                _Documente(
                  medicament: m,
                  onRcp: () => _deschide(context, m.rcpUrl),
                  onProspect: () => _deschide(context, m.prospectUrl),
                  onEma: () => _deschide(context, _emaUrl),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<AsistentProvider>().ataseaza(m);
                      tabCurent.value = tabAsistent;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      side: const BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      'Întreabă asistentul despre acest medicament',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (substante.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<InteractiuniProvider>().adaugaInSelectie(
                          substante,
                        );
                        tabCurent.value = tabInteractiuni;
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.compare_arrows, size: 18),
                      label: const Text(
                        'Verifică interacțiunile acestui medicament',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
                SectiuniRcp(medicament: m),
                const SizedBox(height: 14),
                _Sectiune(
                  titlu: 'Eliberare',
                  child: Row(
                    children: [
                      PrescriptieBadge(m.prescriptie),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          explicatie ?? 'Cod de prescripție din nomenclator',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Sectiune(
                  titlu: 'Compensare CNAS',
                  child: _CompensareCnas(medicament: m, provider: provider),
                ),
                const SizedBox(height: 14),
                _Sectiune(
                  titlu: 'Clasificare',
                  child: Column(
                    children: [
                      _Rand('Cod ATC', m.atc),
                      _Rand('Acțiune terapeutică', titleCase(m.actiune)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Sectiune(
                  titlu: 'Autorizare',
                  child: Column(
                    children: [
                      _Rand('Deținător APP', m.detinator),
                      _Rand('Producător', m.producator),
                      if (m.centralizat)
                        const _Rand('Procedură', 'Autorizat centralizat (UE)'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Sectiune(
                  titlu: 'Ambalaje (${m.ambalaje.length})',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, a) in m.ambalaje.indexed) ...[
                        if (i > 0) const Divider(height: 20),
                        _AmbalajRand(a),
                      ],
                    ],
                  ),
                ),
                if (echivalente.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Aceeași substanță activă (${echivalente.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  for (final e in echivalente.take(40))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MedicamentTile(
                        medicament: e,
                        favorit: provider.esteFavorit(e),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MedicamentDetailScreen(medicament: e),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompensareCnas extends StatelessWidget {
  final Medicament medicament;
  final MedicamenteProvider provider;
  const _CompensareCnas({required this.medicament, required this.provider});

  @override
  Widget build(BuildContext context) {
    final m = medicament;
    const text = TextStyle(color: AppColors.ink, fontSize: 14.5, height: 1.35);
    const nota = TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4);
    if (provider.dataCompensare.isEmpty) {
      return const Text(
        'Lista de compensare nu este disponibilă.',
        style: text,
      );
    }
    final sursa =
        'Lista CNAS din ${provider.dataCompensare}, prețuri pentru farmacii comunitare.';
    final dupaNume = provider.compensareDupaNume(m);
    if (dupaNume.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in dupaNume) ...[
            Text(c.ambalajCnas ?? '', style: text),
            const SizedBox(height: 6),
            _RandCompensare(c),
            const SizedBox(height: 6),
          ],
          Text(
            '$sursa Ambalajele sunt cele din lista CNAS; codurile lor diferă de '
            'cele din nomenclatorul actual.',
            style: nota,
          ),
        ],
      );
    }
    if (m.liste.isEmpty) {
      final substanta = provider.listeSubstanta(m.dci);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            substanta.isEmpty
                ? 'Nu figurează în lista de medicamente compensate.'
                : 'Substanța activă figurează în sublista ${substanta.join(', ')}, dar '
                      'ambalajele acestui produs nu apar în lista de prețuri.',
            style: text,
          ),
          const SizedBox(height: 8),
          Text(sursa, style: nota),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in m.ambalaje)
          if (provider.compensareAmbalaj(a.cim).isNotEmpty) ...[
            Text(a.descriere, style: text),
            const SizedBox(height: 6),
            for (final c in provider.compensareAmbalaj(a.cim))
              _RandCompensare(c),
            const SizedBox(height: 6),
          ],
        Text(sursa, style: nota),
      ],
    );
  }
}

/// Contraindicatiile din RCP, intr-o caseta rosie de avertizare. Textele lungi
/// apar prescurtat, cu posibilitatea de a fi extinse.
class _Contraindicatii extends StatefulWidget {
  final String text;
  const _Contraindicatii(this.text);

  @override
  State<_Contraindicatii> createState() => _ContraindicatiiState();
}

class _ContraindicatiiState extends State<_Contraindicatii> {
  static const _randuriRestranse = 7;
  bool _extins = false;

  @override
  Widget build(BuildContext context) {
    const stil = TextStyle(color: AppColors.ink, fontSize: 14.5, height: 1.4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 22),
              SizedBox(width: 8),
              // se micsoreaza pe ecrane inguste cu text marit, in loc sa iasa
              // din caseta
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CONTRAINDICAȚII',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, limite) {
              final masurare = TextPainter(
                text: TextSpan(text: widget.text, style: stil),
                maxLines: _randuriRestranse,
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: limite.maxWidth);
              final lung = masurare.didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.text,
                    style: stil,
                    maxLines: _extins ? null : _randuriRestranse,
                    overflow: _extins ? null : TextOverflow.ellipsis,
                  ),
                  if (lung)
                    TextButton(
                      onPressed: () => setState(() => _extins = !_extins),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.red,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _extins ? 'Arată mai puțin' : 'Arată tot',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Text extras automat din RCP, secțiunea 4.3. Verifică documentul.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// O incadrare CNAS: sublista, procentul, pretul maximal si contributia.
class _RandCompensare extends StatelessWidget {
  final Compensare c;
  const _RandCompensare(this.c);

  static String _lei(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} lei';

  @override
  Widget build(BuildContext context) {
    const nota = TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blueSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              c.lista,
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compensare ${procentCompensare(c.lista)}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Preț maximal ${_lei(c.pret)} · contribuție maximă '
                  '${_lei(c.contributie)}',
                  style: nota,
                ),
                if (c.contributiePensionari != null)
                  Text(
                    'Pensionari cu venituri mici: ${_lei(c.contributiePensionari!)}',
                    style: nota,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Documente extends StatelessWidget {
  final Medicament medicament;
  final VoidCallback onRcp;
  final VoidCallback onProspect;
  final VoidCallback onEma;

  const _Documente({
    required this.medicament,
    required this.onRcp,
    required this.onProspect,
    required this.onEma,
  });

  @override
  Widget build(BuildContext context) {
    final m = medicament;
    if (m.rcpUrl.isEmpty && m.prospectUrl.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onEma,
          icon: const Icon(Icons.public),
          label: const Text('Caută RCP și prospect la EMA'),
        ),
      );
    }
    return Row(
      children: [
        if (m.rcpUrl.isNotEmpty)
          Expanded(
            child: FilledButton.icon(
              onPressed: onRcp,
              icon: const Icon(Icons.description_outlined),
              label: Text(m.centralizat ? 'RCP și prospect (EMA)' : 'RCP'),
            ),
          ),
        if (m.rcpUrl.isNotEmpty && m.prospectUrl.isNotEmpty)
          const SizedBox(width: 10),
        if (m.prospectUrl.isNotEmpty)
          Expanded(
            child: FilledButton.icon(
              onPressed: onProspect,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.blue,
                side: const BorderSide(color: AppColors.blue, width: 1.5),
              ),
              icon: const Icon(Icons.article_outlined),
              label: const Text('Prospect'),
            ),
          ),
      ],
    );
  }
}

class _Pastila extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pastila({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sectiune extends StatelessWidget {
  final String titlu;
  final Widget child;
  const _Sectiune({required this.titlu, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titlu.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Rand extends StatelessWidget {
  final String eticheta;
  final String valoare;
  const _Rand(this.eticheta, this.valoare);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              eticheta,
              style: const TextStyle(color: AppColors.muted, fontSize: 13.5),
            ),
          ),
          Expanded(
            child: SelectableText(
              valoare.isEmpty ? '—' : valoare,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbalajRand extends StatelessWidget {
  final Ambalaj ambalaj;
  const _AmbalajRand(this.ambalaj);

  @override
  Widget build(BuildContext context) {
    final a = ambalaj;
    final detalii = [
      'CIM ${a.cim}',
      if (a.volum.isNotEmpty) a.volum,
      if (a.valabilitate.isNotEmpty) 'valabilitate ${a.valabilitate}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.descriere,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          detalii,
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
      ],
    );
  }
}
