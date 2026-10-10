import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../help/ajutor.dart';
import '../models/sinteza.dart';
import '../providers/sinteza_provider.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';

Color culoareSectiune(SectiuneSinteza s) => switch (s) {
  SectiuneSinteza.psihiatrie => SintezaColors.psihiatrie,
  SectiuneSinteza.siguranta => SintezaColors.siguranta,
  SectiuneSinteza.medicina => SintezaColors.medicina,
  SectiuneSinteza.stiinta => SintezaColors.stiinta,
  SectiuneSinteza.arta => SintezaColors.arta,
  SectiuneSinteza.arhitectura => SintezaColors.arhitectura,
  SectiuneSinteza.altele => SintezaColors.altele,
};

IconData iconSectiune(SectiuneSinteza s) => switch (s) {
  SectiuneSinteza.psihiatrie => Icons.psychology_outlined,
  SectiuneSinteza.siguranta => Icons.health_and_safety_outlined,
  SectiuneSinteza.medicina => Icons.biotech_outlined,
  SectiuneSinteza.stiinta => Icons.science_outlined,
  SectiuneSinteza.arta => Icons.palette_outlined,
  SectiuneSinteza.arhitectura => Icons.architecture,
  SectiuneSinteza.altele => Icons.auto_stories_outlined,
};

TextStyle _serif(double marime, {FontWeight? grosime, Color? culoare}) =>
    TextStyle(
      fontFamily: fontLectura,
      fontFamilyFallback: fontLecturaRezerve,
      fontSize: marime,
      fontWeight: grosime,
      color: culoare ?? SintezaColors.cerneala,
    );

/// "2026-10-10" -> "10 octombrie 2026"; sirul neschimbat daca nu e o data.
String dataPeLitere(String iso) {
  const luni = [
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', 'iulie', //
    'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${d.day} ${luni[d.month - 1]} ${d.year}';
}

Future<void> _deschideLegatura(BuildContext context, String url) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pagina nu a putut fi deschisă.')),
    );
  }
}

/// Sinteza saptamanala: noutati din psihiatrie si psihoterapie, din restul
/// cercetarii medicale, din stiinte, din arta si din arhitectura.
class SintezaScreen extends StatefulWidget {
  const SintezaScreen({super.key});

  @override
  State<SintezaScreen> createState() => _SintezaScreenState();
}

class _SintezaScreenState extends State<SintezaScreen> {
  /// Sectiunea aleasa din filtre; null inseamna toate.
  SectiuneSinteza? _filtru;

  @override
  void initState() {
    super.initState();
    tabCurent.addListener(_laSchimbareaSectiunii);
    _laSchimbareaSectiunii();
  }

  @override
  void dispose() {
    tabCurent.removeListener(_laSchimbareaSectiunii);
    super.dispose();
  }

  // editia se descarca abia cand sectiunea este deschisa prima oara
  void _laSchimbareaSectiunii() {
    if (tabCurent.value != tabSinteza) return;
    // amanat cu un pas: la pornire apelul vine din initState, in timpul
    // construirii, cand providerul nu are voie sa anunte schimbari
    Future.microtask(() {
      if (mounted) context.read<SintezaProvider>().incarcaLaPrimaDeschidere();
    });
  }

  Future<void> _arataArhiva(SintezaProvider provider) async {
    final ales = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SintezaColors.card,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Ediții',
                style: _serif(20, grosime: FontWeight.w700),
              ),
            ),
            for (final e in provider.editii)
              ListTile(
                leading: Icon(
                  e.id == provider.editie?.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: SintezaColors.legatura,
                ),
                title: Text(e.interval, style: _serif(16)),
                subtitle: Text(
                  e.titlu,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SintezaColors.estompat),
                ),
                onTap: () => Navigator.pop(context, e.id),
              ),
          ],
        ),
      ),
    );
    if (ales != null) await provider.alege(ales);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SintezaProvider>();
    final editie = provider.editie;
    // antetul e inchis la culoare, deci ceasul si bateria raman albe si dupa
    // intoarcerea dintr-un articol, a carui bara este deschisa la culoare
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Column(
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
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sinteză',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        if (provider.editii.length > 1)
                          IconButton(
                            tooltip: 'Ediții anterioare',
                            icon: const Icon(
                              Icons.history,
                              color: Colors.white,
                            ),
                            onPressed: () => _arataArhiva(provider),
                          ),
                        const ButonAjutor(ajutorSinteza),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      editie == null
                          ? 'Psihiatrie, medicină, științe, artă, arhitectură'
                          : 'Săptămâna ${editie.interval} · '
                                '${editie.articole.length} articole',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: SintezaColors.hartie,
              child: _continut(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _continut(SintezaProvider provider) {
    final editie = provider.editie;
    if (editie == null) {
      if (provider.eroare == null) {
        // inainte de prima deschidere a sectiunii pagina sta ascunsa in
        // IndexedStack, unde un indicator animat ar rula degeaba
        if (!provider.seIncarca) return const SizedBox.shrink();
        return const Center(
          child: CircularProgressIndicator(color: SintezaColors.legatura),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: SintezaColors.estompat,
              ),
              const SizedBox(height: 12),
              Text(
                provider.eroare!,
                textAlign: TextAlign.center,
                style: _serif(16, culoare: SintezaColors.estompat),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: provider.seIncarca ? null : provider.reincarca,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SintezaColors.legatura,
                ),
                child: const Text('Încearcă din nou'),
              ),
            ],
          ),
        ),
      );
    }

    final sectiuni = [
      for (final s in SectiuneSinteza.values)
        if ((_filtru == null || _filtru == s) &&
            editie.dinSectiunea(s).isNotEmpty)
          s,
    ];
    return RefreshIndicator(
      color: SintezaColors.legatura,
      onRefresh: provider.reincarca,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Centrat(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (provider.eroare != null) ...[
                  Text(
                    provider.eroare!,
                    style: const TextStyle(
                      color: SintezaColors.arta,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  editie.titlu,
                  style: _serif(
                    23,
                    grosime: FontWeight.w700,
                  ).copyWith(height: 1.25),
                ),
                if (editie.introducere.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    editie.introducere,
                    style: _serif(
                      15.5,
                      culoare: SintezaColors.estompat,
                    ).copyWith(height: 1.5),
                  ),
                ],
                const SizedBox(height: 16),
                _Filtre(
                  sectiuni: [
                    for (final s in SectiuneSinteza.values)
                      if (editie.dinSectiunea(s).isNotEmpty) s,
                  ],
                  ales: _filtru,
                  laAlegere: (s) => setState(() => _filtru = s),
                ),
                for (final s in sectiuni) ...[
                  const SizedBox(height: 22),
                  _TitluSectiune(s),
                  for (final (i, a) in editie.dinSectiunea(s).indexed) ...[
                    const SizedBox(height: 12),
                    _CardArticol(
                      articol: a,
                      mare: i == 0,
                      laAtingere: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ArticolSintezaScreen(editie: editie, articol: a),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Text(
                  'Ediția din ${dataPeLitere(editie.data)}. Textele sunt rezumate '
                  'scrise de un model AI pe baza surselor citate; pentru '
                  'detalii și verificare, deschide sursa fiecărui articol.',
                  style: const TextStyle(
                    color: SintezaColors.estompat,
                    fontSize: 12,
                    height: 1.45,
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

/// Tine coloana de text la o latime comoda de citit pe tablete si in browser.
class _Centrat extends StatelessWidget {
  final Widget child;
  const _Centrat({required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: child,
    ),
  );
}

class _Filtre extends StatelessWidget {
  /// Sectiunile care au articole in editia afisata.
  final List<SectiuneSinteza> sectiuni;
  final SectiuneSinteza? ales;
  final ValueChanged<SectiuneSinteza?> laAlegere;
  const _Filtre({
    required this.sectiuni,
    required this.ales,
    required this.laAlegere,
  });

  @override
  Widget build(BuildContext context) {
    Widget pastila(String eticheta, SectiuneSinteza? s) {
      final selectat = ales == s;
      final culoare = s == null ? SintezaColors.cerneala : culoareSectiune(s);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          selected: selectat,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => laAlegere(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selectat ? culoare : SintezaColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selectat ? culoare : SintezaColors.linie,
                ),
              ),
              child: Text(
                eticheta,
                style: TextStyle(
                  fontSize: 13,
                  color: selectat ? Colors.white : SintezaColors.cerneala,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          pastila('Toate', null),
          for (final s in sectiuni) pastila(s.scurt, s),
        ],
      ),
    );
  }
}

class _TitluSectiune extends StatelessWidget {
  final SectiuneSinteza sectiune;
  const _TitluSectiune(this.sectiune);

  @override
  Widget build(BuildContext context) {
    final culoare = culoareSectiune(sectiune);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(iconSectiune(sectiune), color: culoare, size: 20),
            const SizedBox(width: 8),
            // numele lung al primei sectiuni se rupe pe ecranele inguste
            Expanded(
              child: Text(
                sectiune.eticheta.toUpperCase(),
                style: TextStyle(
                  color: culoare,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 2, width: 44, color: culoare),
      ],
    );
  }
}

/// Imaginea unui articol; cat se incarca sau daca lipseste, in locul ei sta
/// un fond in culoarea sectiunii.
class ImagineArticol extends StatelessWidget {
  final ArticolSinteza articol;
  const ImagineArticol(this.articol, {super.key});

  @override
  Widget build(BuildContext context) {
    final culoare = culoareSectiune(articol.sectiune);
    final fond = ColoredBox(
      color: culoare.withValues(alpha: 0.14),
      child: Center(
        child: Icon(
          iconSectiune(articol.sectiune),
          color: culoare.withValues(alpha: 0.55),
          size: 36,
        ),
      ),
    );
    if (articol.imagine.isEmpty) return fond;
    return Image.network(
      articol.imagine,
      fit: BoxFit.cover,
      // in browser, imaginile de pe alte site-uri se afiseaza ca element <img>
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      frameBuilder: (context, child, frame, sincron) => Stack(
        fit: StackFit.expand,
        children: [
          fond,
          AnimatedOpacity(
            opacity: frame == null && !sincron ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: child,
          ),
        ],
      ),
      errorBuilder: (_, _, _) => fond,
    );
  }
}

class _CardArticol extends StatelessWidget {
  final ArticolSinteza articol;

  /// Primul articol al sectiunii are imaginea mare, deasupra titlului.
  final bool mare;
  final VoidCallback laAtingere;

  const _CardArticol({
    required this.articol,
    required this.mare,
    required this.laAtingere,
  });

  @override
  Widget build(BuildContext context) {
    final titlu = Text(
      articol.titlu,
      style: _serif(
        mare ? 19 : 16.5,
        grosime: FontWeight.w700,
      ).copyWith(height: 1.25),
    );
    final subsol = Text(
      '${articol.sursa.titlu} · ${articol.minuteLectura} min de citit',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: SintezaColors.estompat, fontSize: 12),
    );
    return Material(
      color: SintezaColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: laAtingere,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SintezaColors.linie),
          ),
          child: mare
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ImagineArticol(articol),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titlu,
                          const SizedBox(height: 8),
                          Text(
                            articol.rezumat,
                            style: _serif(
                              14.5,
                              culoare: SintezaColors.estompat,
                            ).copyWith(height: 1.45),
                          ),
                          const SizedBox(height: 10),
                          subsol,
                        ],
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [titlu, const SizedBox(height: 8), subsol],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: ImagineArticol(articol),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Pagina de lectura a unui articol.
class ArticolSintezaScreen extends StatelessWidget {
  final EditieSinteza editie;
  final ArticolSinteza articol;

  const ArticolSintezaScreen({
    super.key,
    required this.editie,
    required this.articol,
  });

  @override
  Widget build(BuildContext context) {
    final a = articol;
    final culoare = culoareSectiune(a.sectiune);
    final pozitie = editie.articole.indexOf(a);
    final urmatorul = pozitie >= 0 && pozitie + 1 < editie.articole.length
        ? editie.articole[pozitie + 1]
        : null;
    return Scaffold(
      backgroundColor: SintezaColors.hartie,
      appBar: AppBar(
        backgroundColor: SintezaColors.hartie,
        foregroundColor: SintezaColors.cerneala,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          '${a.sectiune.eticheta} · ${editie.interval}',
          style: const TextStyle(fontSize: 14, color: SintezaColors.estompat),
        ),
      ),
      body: SelectionArea(
        child: ListView(
          padding: EdgeInsets.only(
            bottom: 32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _Centrat(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.imagine.isNotEmpty) ...[
                    AspectRatio(aspectRatio: 16 / 9, child: ImagineArticol(a)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                      child: Text(
                        'Imagine: ${a.creditImagine}',
                        style: const TextStyle(
                          color: SintezaColors.estompat,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            a.sectiune.eticheta.toUpperCase(),
                            if (a.loc.isNotEmpty) a.loc,
                          ].join('  ·  '),
                          style: TextStyle(
                            color: culoare,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          a.titlu,
                          style: _serif(
                            26,
                            grosime: FontWeight.w700,
                          ).copyWith(height: 1.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          a.rezumat,
                          style: _serif(
                            18,
                            culoare: SintezaColors.estompat,
                          ).copyWith(height: 1.45, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${a.minuteLectura} min de citit',
                          style: const TextStyle(
                            color: SintezaColors.estompat,
                            fontSize: 12,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: SintezaColors.linie),
                        ),
                        for (final p in a.paragrafe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              p,
                              style: _serif(17).copyWith(height: 1.62),
                            ),
                          ),
                        if (a.deCeConteaza.isNotEmpty)
                          _DeCeConteaza(a.deCeConteaza, culoare),
                        const SizedBox(height: 24),
                        const _TitluBloc('Sursa'),
                        _RandLegatura(
                          icon: Icons.article_outlined,
                          titlu: a.sursa.titlu,
                          detaliu: [
                            if (a.dataSursa.isNotEmpty)
                              dataPeLitere(a.dataSursa),
                            a.sursa.site,
                          ].join(' · '),
                          url: a.sursa.url,
                        ),
                        if (a.alteSurse.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const _TitluBloc('Aceeași știre, în alte redacții'),
                          for (final s in a.alteSurse)
                            _RandLegatura(
                              icon: Icons.newspaper_outlined,
                              titlu: s.titlu,
                              detaliu: s.site,
                              url: s.url,
                            ),
                        ],
                        if (a.trimiteri.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const _TitluBloc('Află mai mult'),
                          for (final t in a.trimiteri)
                            _RandLegatura(
                              icon: t.site.endsWith('wikipedia.org')
                                  ? Icons.menu_book_outlined
                                  : Icons.explore_outlined,
                              titlu: t.titlu,
                              detaliu: t.site,
                              url: t.url,
                            ),
                        ],
                        if (urmatorul != null) ...[
                          const SizedBox(height: 28),
                          _Urmatorul(editie: editie, articol: urmatorul),
                        ],
                      ],
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

class _DeCeConteaza extends StatelessWidget {
  final String text;
  final Color culoare;
  const _DeCeConteaza(this.text, this.culoare);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: culoare.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: culoare, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DE CE CONTEAZĂ',
            style: TextStyle(
              color: culoare,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(text, style: _serif(16).copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _TitluBloc extends StatelessWidget {
  final String text;
  const _TitluBloc(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: SintezaColors.estompat,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

/// O trimitere care se deschide in browser.
class _RandLegatura extends StatelessWidget {
  final IconData icon;
  final String titlu;
  final String detaliu;
  final String url;

  const _RandLegatura({
    required this.icon,
    required this.titlu,
    required this.detaliu,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: SintezaColors.card,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _deschideLegatura(context, url),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SintezaColors.linie),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Icon(icon, color: SintezaColors.legatura, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titlu,
                        style: const TextStyle(
                          color: SintezaColors.legatura,
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                      if (detaliu.isNotEmpty)
                        Text(
                          detaliu,
                          style: const TextStyle(
                            color: SintezaColors.estompat,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.open_in_new,
                  color: SintezaColors.estompat,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Urmatorul extends StatelessWidget {
  final EditieSinteza editie;
  final ArticolSinteza articol;
  const _Urmatorul({required this.editie, required this.articol});

  @override
  Widget build(BuildContext context) {
    final culoare = culoareSectiune(articol.sectiune);
    return Material(
      color: SintezaColors.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                ArticolSintezaScreen(editie: editie, articol: articol),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SintezaColors.linie),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'URMĂTORUL · ${articol.sectiune.eticheta.toUpperCase()}',
                      style: TextStyle(
                        color: culoare,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      articol.titlu,
                      style: _serif(
                        16,
                        grosime: FontWeight.w700,
                      ).copyWith(height: 1.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: culoare),
            ],
          ),
        ),
      ),
    );
  }
}
