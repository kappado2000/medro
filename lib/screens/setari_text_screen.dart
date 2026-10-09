import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/setari_text_provider.dart';
import '../theme/app_theme.dart';

/// Marimea si grosimea scrisului din aplicatie, cu o previzualizare care se
/// schimba pe loc.
class SetariTextScreen extends StatelessWidget {
  const SetariTextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final setari = context.watch<SetariTextProvider>();
    final procent = (setari.scara * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Setări text')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _Titlu('Previzualizare'),
          const _Previzualizare(),
          const SizedBox(height: 18),
          _Titlu('Mărime: $procent%'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Mai mic',
                        icon: const Icon(Icons.text_decrease),
                        onPressed:
                            setari.scara <= SetariTextProvider.scaraMinima
                            ? null
                            : () => setari.seteazaScara(
                                setari.scara - SetariTextProvider.pas,
                              ),
                      ),
                      Expanded(
                        child: Slider(
                          value: setari.scara,
                          min: SetariTextProvider.scaraMinima,
                          max: SetariTextProvider.scaraMaxima,
                          divisions:
                              ((SetariTextProvider.scaraMaxima -
                                          SetariTextProvider.scaraMinima) /
                                      SetariTextProvider.pas)
                                  .round(),
                          label: '$procent%',
                          onChanged: setari.seteazaScara,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mai mare',
                        icon: const Icon(Icons.text_increase),
                        onPressed:
                            setari.scara >= SetariTextProvider.scaraMaxima
                            ? null
                            : () => setari.seteazaScara(
                                setari.scara + SetariTextProvider.pas,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _Titlu('Grosime'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<GrosimeText>(
                  segments: [
                    for (final g in GrosimeText.values)
                      ButtonSegment(
                        value: g,
                        label: Text(
                          g.eticheta,
                          style: TextStyle(fontWeight: g.grosime),
                        ),
                      ),
                  ],
                  selected: {setari.grosime},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setari.seteazaGrosime(s.first),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: setari.implicite ? null : setari.reseteaza,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Revino la valorile inițiale'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: Text(
              'Setările se aplică în toată aplicația și se păstrează pe acest telefon. '
              'Titlurile de ecran și numele din carduri rămân îngroșate la orice '
              'alegere. Aplicația nu urmează „Text aldin” și mărimea textului din '
              'setările telefonului; se folosesc cele de aici.',
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

/// Un card ca in lista de medicamente si un paragraf, ca efectul sa se vada
/// pe textele cele mai intalnite.
class _Previzualizare extends StatelessWidget {
  const _Previzualizare();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'LEPONEX 100 mg',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Clozapinum',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            Text(
              'compr. · CNAS C1',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            Divider(height: 22),
            Text(
              'Hipersensibilitate la substanța activă sau la oricare dintre '
              'excipienți. Pacienți care nu pot efectua periodic teste sanguine.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
