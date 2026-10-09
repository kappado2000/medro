import 'package:flutter/material.dart';

import '../models/medicament.dart';
import '../services/data_store.dart';
import '../theme/app_theme.dart';
import '../utils/rcp_extrase.dart';

/// Informatiile extrase din RCP-ul unui medicament: raspunsuri rapide pe teme
/// (functie renala, sarcina, monitorizare, enzime, QT) si sectiunile complete.
/// Totul e text din document, disponibil fara internet.
class SectiuniRcp extends StatefulWidget {
  final Medicament medicament;
  const SectiuniRcp({super.key, required this.medicament});

  @override
  State<SectiuniRcp> createState() => _SectiuniRcpState();
}

class _SectiuniRcpState extends State<SectiuniRcp> {
  late final Future<Map<String, String>> _sectiuni = RcpStore.instance.sectiuni(
    widget.medicament.rcpUrl,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _sectiuni,
      builder: (context, snapshot) {
        final s = snapshot.data ?? const <String, String>{};
        if (s.isEmpty) return const SizedBox.shrink();
        final rapide = <Widget>[
          if (s['4.6'] != null)
            _Tigla(
              icon: Icons.pregnant_woman,
              titlu: 'Sarcină și alăptare',
              child: _Text(s['4.6']!),
            ),
          for (final tema in temeRcp) ..._tema(tema, s),
        ];
        final complete = <Widget>[
          for (final e in titluriSectiuni.entries)
            if (s[e.key] != null && e.key != '4.6')
              _Tigla(
                icon: Icons.article_outlined,
                titlu: '${e.key} ${e.value}',
                child: _Text(s[e.key]!),
              ),
        ];
        return Column(
          children: [
            if (rapide.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Card(titlu: 'Răspunsuri rapide din RCP', children: rapide),
            ],
            if (complete.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Card(titlu: 'Secțiunile RCP', children: complete),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _tema(TemaRcp tema, Map<String, String> s) {
    final fraze = extrage(tema, s);
    if (fraze.isEmpty) return const [];
    final enzime = tema.id == 'cyp' ? izoenzime(s) : const <String>[];
    return [
      _Tigla(
        icon: _iconite[tema.id] ?? Icons.info_outline,
        titlu: tema.titlu,
        subtitlu: enzime.isEmpty ? null : enzime.join(' · '),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in fraze)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2, right: 8),
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
                    Expanded(child: _Text(f.text)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  static const _iconite = {
    'doza_maxima': Icons.speed,
    'renal': Icons.water_drop_outlined,
    'hepatic': Icons.science_outlined,
    'varstnici': Icons.elderly,
    'monitorizare': Icons.monitor_heart_outlined,
    'cyp': Icons.hub_outlined,
    'qt': Icons.show_chart,
    'anticolinergic': Icons.blur_on,
  };
}

class _Card extends StatelessWidget {
  final String titlu;
  final List<Widget> children;
  const _Card({required this.titlu, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              titlu.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.blue,
              ),
            ),
          ),
          ...children,
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Text(
              'Text extras automat din RCP. Verifică documentul înainte de o decizie.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tigla extends StatelessWidget {
  final IconData icon;
  final String titlu;
  final String? subtitlu;
  final Widget child;

  const _Tigla({
    required this.icon,
    required this.titlu,
    required this.child,
    this.subtitlu,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.blue, size: 22),
        title: Text(
          titlu,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        subtitle: subtitlu == null
            ? null
            : Text(
                subtitlu!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        children: [child],
      ),
    );
  }
}

class _Text extends StatelessWidget {
  final String text;
  const _Text(this.text);

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 14.5,
        height: 1.45,
      ),
    );
  }
}
