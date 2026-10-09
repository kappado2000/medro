import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'asistent_screen.dart';
import 'calculatoare_screen.dart';
import 'icd_screen.dart';
import 'interactiuni_screen.dart';
import 'medicamente_screen.dart';

/// Sectiunea afisata; alte ecrane o pot schimba (ex. "Întreabă asistentul").
final tabCurent = ValueNotifier<int>(0);

const tabInteractiuni = 1;
const tabAsistent = 4;

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _pagini = [
    MedicamenteScreen(),
    InteractiuniScreen(),
    CalculatoareScreen(),
    IcdScreen(),
    AsistentScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabCurent,
      builder: (context, index, _) => Scaffold(
        // continutul trece pe sub banerul translucid de jos
        extendBody: true,
        body: IndexedStack(index: index, children: _pagini),
        bottomNavigationBar: _BaraJos(
          index: index,
          onSelect: (i) => tabCurent.value = i,
        ),
      ),
    );
  }
}

/// Bara de jos: un baner plutitor, usor translucid, in acelasi degrade ca
/// antetul. E construita manual, nu cu
/// NavigationBar, ca etichetele sa ramana pe un singur rand la orice latime
/// de ecran si iconitele sa stea aliniate.
class _BaraJos extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _BaraJos({required this.index, required this.onSelect});

  static const _etichete = [
    'Medicamente',
    'Interacțiuni',
    'Calculatoare',
    'ICD-10',
    'Asistent',
  ];

  static const _iconite = <IconData?>[
    null, // capsula desenata, vezi IconCapsula
    Icons.compare_arrows,
    Icons.calculate_outlined,
    Icons.account_tree_outlined,
    Icons.auto_awesome,
  ];

  /// Cat de opac este banerul; restul lasa sa se vada lista de dedesubt.
  static const _opacitate = 0.85;

  @override
  Widget build(BuildContext context) {
    final raza = BorderRadius.circular(26);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: raza,
            boxShadow: [
              BoxShadow(
                color: AppColors.blueDark.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: raza,
            // sticla mata: ce e dedesubt se vede estompat, fara sa incurce textul
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AppColors.headerGradient.begin,
                    end: AppColors.headerGradient.end,
                    colors: [
                      for (final c in AppColors.headerGradient.colors)
                        c.withValues(alpha: _opacitate),
                    ],
                  ),
                  borderRadius: raza,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
                child: Row(
                  children: [
                    for (final (i, eticheta) in _etichete.indexed)
                      Expanded(
                        child: _Destinatie(
                          eticheta: eticheta,
                          icon: _iconite[i],
                          selectat: i == index,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destinatie extends StatelessWidget {
  final String eticheta;
  final IconData? icon;
  final bool selectat;
  final VoidCallback onTap;

  const _Destinatie({
    required this.eticheta,
    required this.icon,
    required this.selectat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selectat,
      label: eticheta,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectat
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: icon == null
                    ? const IconCapsula(culoare: Colors.white, dimensiune: 24)
                    : Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 4),
              // eticheta se micsoreaza usor pe ecrane inguste, nu se rupe
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ExcludeSemantics(
                    child: Text(
                      eticheta,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 0,
                      ),
                    ),
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

/// Iconita de medicament: o capsula inclinata, pe jumatate plina.
class IconCapsula extends StatelessWidget {
  final Color culoare;
  final double dimensiune;

  const IconCapsula({
    super.key,
    required this.culoare,
    required this.dimensiune,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(dimensiune),
      painter: _CapsulaPainter(culoare),
    );
  }
}

class _CapsulaPainter extends CustomPainter {
  final Color culoare;
  const _CapsulaPainter(this.culoare);

  @override
  void paint(Canvas canvas, Size size) {
    final lungime = size.width * 0.96;
    final grosime = size.width * 0.44;
    final contur = size.width * 0.085;
    final capsula = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: lungime, height: grosime),
      Radius.circular(grosime / 2),
    );
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..rotate(-math.pi / 4)
      // jumatatea plina
      ..save()
      ..clipRect(Rect.fromLTRB(-lungime, -grosime, 0, grosime))
      ..drawRRect(capsula, Paint()..color = culoare)
      ..restore()
      ..drawRRect(
        capsula.deflate(contur / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = contur
          ..color = culoare,
      );
  }

  @override
  bool shouldRepaint(_CapsulaPainter veche) => veche.culoare != culoare;
}
