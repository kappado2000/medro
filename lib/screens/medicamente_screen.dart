import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/medicamente_provider.dart';
import '../help/ajutor.dart';
import '../theme/app_theme.dart';
import '../utils/clase_psihotrope.dart';
import '../widgets/date_aplicatie.dart';
import '../widgets/medicament_widgets.dart';
import 'cautare_rcp_screen.dart';
import 'medicament_detail_screen.dart';

class MedicamenteScreen extends StatefulWidget {
  const MedicamenteScreen({super.key});

  @override
  State<MedicamenteScreen> createState() => _MedicamenteScreenState();
}

class _MedicamenteScreenState extends State<MedicamenteScreen> {
  final _controller = TextEditingController();
  String _interogare = '';
  FiltruMedicamente _filtru = FiltruMedicamente.toate;
  ClasaAtc? _clasa;

  static const _filtre = {
    FiltruMedicamente.toate: 'Toate',
    FiltruMedicamente.faraReteta: 'Fără rețetă',
    FiltruMedicamente.cuReteta: 'Cu rețetă',
    FiltruMedicamente.compensate: 'Compensate',
    FiltruMedicamente.favorite: 'Favorite',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) verificaActualizariZilnic(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _alegeClasa() async {
    final ales = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.clear_all, color: AppColors.muted),
              title: const Text('Toate clasele'),
              onTap: () => Navigator.pop(context, -1),
            ),
            for (final (i, c) in clasePsihotrope.indexed)
              ListTile(
                leading: Icon(
                  Icons.psychology_outlined,
                  color: c == _clasa ? AppColors.red : AppColors.blue,
                ),
                title: Text(
                  c.nume,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('ATC ${c.prefix}'),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (ales == null) return;
    setState(() => _clasa = ales < 0 ? null : clasePsihotrope[ales]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicamenteProvider>();
    return Column(
      children: [
        _Header(
          controller: _controller,
          provider: provider,
          onChanged: (v) => setState(() => _interogare = v),
          onClear: () {
            _controller.clear();
            setState(() => _interogare = '');
          },
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _filtre.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                final activ = _clasa != null;
                return ChoiceChip(
                  label: Text(_clasa?.nume ?? 'Clase psihotrope'),
                  selected: activ,
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.psychology_outlined,
                    size: 18,
                    color: activ ? Colors.white : AppColors.blue,
                  ),
                  selectedColor: AppColors.blue,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: activ ? AppColors.blue : AppColors.line,
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: activ ? Colors.white : AppColors.ink,
                  ),
                  onSelected: (_) => _alegeClasa(),
                );
              }
              final filtru = _filtre.keys.elementAt(i - 1);
              final selectat = filtru == _filtru;
              return ChoiceChip(
                label: Text(_filtre[filtru]!),
                selected: selectat,
                showCheckmark: false,
                avatar: filtru == FiltruMedicamente.favorite
                    ? Icon(
                        Icons.favorite,
                        size: 16,
                        color: selectat ? Colors.white : AppColors.red,
                      )
                    : null,
                selectedColor: AppColors.blue,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selectat ? AppColors.blue : AppColors.line,
                ),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selectat ? Colors.white : AppColors.ink,
                ),
                onSelected: (_) => setState(() => _filtru = filtru),
              );
            },
          ),
        ),
        Expanded(child: _buildLista(provider)),
      ],
    );
  }

  Widget _buildLista(MedicamenteProvider provider) {
    if (!provider.incarcat) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.eroare != null) {
      return _Mesaj(
        icon: Icons.error_outline,
        culoare: AppColors.red,
        titlu: 'Baza de medicamente nu a putut fi încărcată',
        text: provider.eroare!,
      );
    }
    final rezultate = provider.cauta(
      _interogare,
      _filtru,
      atcPrefix: _clasa?.prefix ?? '',
    );
    if (rezultate.isEmpty) {
      final favorite =
          _filtru == FiltruMedicamente.favorite && _interogare.isEmpty;
      return _Mesaj(
        icon: favorite ? Icons.favorite_border : Icons.search_off,
        culoare: favorite ? AppColors.red : AppColors.muted,
        titlu: favorite ? 'Niciun medicament favorit' : 'Niciun rezultat',
        text: favorite
            ? 'Apasă inima din pagina unui medicament ca să îl găsești rapid aici.'
            : 'Încearcă denumirea comercială, substanța activă sau codul ATC.',
      );
    }
    final limitat =
        _clasa == null && rezultate.length == MedicamenteProvider.maxRezultate;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        2,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // lista libera e limitata; utilizatorul trebuie sa stie ca nu vede tot
      itemCount: rezultate.length + (limitat ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == rezultate.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Sunt afișate primele ${MedicamenteProvider.maxRezultate} de rezultate. '
              'Scrie mai multe litere sau alege un filtru ca să restrângi lista.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          );
        }
        final m = rezultate[i];
        return MedicamentTile(
          medicament: m,
          favorit: provider.esteFavorit(m),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MedicamentDetailScreen(medicament: m),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final TextEditingController controller;
  final MedicamenteProvider provider;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _Header({
    required this.controller,
    required this.provider,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final vechime = provider.incarcat ? provider.zileVechime() : null;
    final subtitlu = provider.incarcat && provider.eroare == null
        ? '${provider.total} medicamente · ${provider.totalSubstante} substanțe · '
              'ANMDM ${provider.actualizat}'
        : 'Se încarcă nomenclatorul…';
    return Container(
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
              Row(
                children: [
                  const EmblemaCapsula(dimensiune: 40),
                  const SizedBox(width: 12),
                  // pe ecrane inguste cu text mare, titlul se micsoreaza usor in
                  // loc sa impinga butoanele in afara
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'MedRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Căutare în RCP',
                    icon: const Icon(Icons.manage_search, color: Colors.white),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CautareRcpScreen(),
                      ),
                    ),
                  ),
                  const ButonAjutor(ajutorMedicamente),
                ],
              ),
              const SizedBox(height: 6),
              // pe un singur rand: pe ecrane inguste textul se micsoreaza
              // usor in loc sa treaca pe al doilea rand
              // atingerea subtitlului arata versiunea datelor si actualizarile
              InkWell(
                onTap: () => arataDateleAplicatiei(context),
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitlu,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.sync,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ],
                ),
              ),
              if (vechime != null &&
                  vechime > MedicamenteProvider.pragVechimeZile)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Date vechi de $vechime zile – aplicația trebuie actualizată.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Denumire, substanță sau cod ATC',
                  hintStyle: const TextStyle(color: AppColors.muted),
                  prefixIcon: const Icon(Icons.search, color: AppColors.blue),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, color: AppColors.muted),
                          onPressed: onClear,
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
    );
  }
}

class _Mesaj extends StatelessWidget {
  final IconData icon;
  final Color culoare;
  final String titlu;
  final String text;

  const _Mesaj({
    required this.icon,
    required this.culoare,
    required this.titlu,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: culoare),
            const SizedBox(height: 14),
            Text(
              titlu,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Emblema din antet: capsula din iconita aplicatiei, pe un patrat alb.
class EmblemaCapsula extends StatelessWidget {
  final double dimensiune;
  const EmblemaCapsula({super.key, required this.dimensiune});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dimensiune,
      height: dimensiune,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(dimensiune * 0.28),
      ),
      padding: EdgeInsets.all(dimensiune * 0.08),
      child: Image.asset('assets/images/capsula.png'),
    );
  }
}
