import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/medicamente_provider.dart';
import '../theme/app_theme.dart';
import '../utils/clase_psihotrope.dart';
import '../widgets/medicament_widgets.dart';
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: rezultate.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const _CruceRosie(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'MedRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitlu,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
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

/// Crucea rosie din emblema, desenata din doua bare groase (iconita standard
/// "plus" este prea subtire).
class _CruceRosie extends StatelessWidget {
  const _CruceRosie();

  static const _lungime = 24.0;
  static const _grosime = 9.0;

  @override
  Widget build(BuildContext context) {
    Widget bara(double latime, double inaltime) => Container(
      width: latime,
      height: inaltime,
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [bara(_lungime, _grosime), bara(_grosime, _lungime)],
    );
  }
}
