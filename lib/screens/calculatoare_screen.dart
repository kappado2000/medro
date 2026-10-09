import 'package:flutter/material.dart';

import '../calculators/calculator.dart';
import '../calculators/lista_calculatoare.dart';
import '../help/ajutor.dart';
import '../theme/app_theme.dart';
import '../utils/text_utils.dart';
import 'calculator_screen.dart';

class CalculatoareScreen extends StatefulWidget {
  const CalculatoareScreen({super.key});

  @override
  State<CalculatoareScreen> createState() => _CalculatoareScreenState();
}

class _CalculatoareScreenState extends State<CalculatoareScreen> {
  final _controller = TextEditingController();
  String _interogare = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = normalizeForSearch(_interogare);
    final vizibile = [
      for (final c in calculatoare)
        if (q.isEmpty ||
            normalizeForSearch('${c.titlu} ${c.descriere} ${c.categorie}')
                .contains(q))
          c,
    ];
    final categorii = <String, List<Calculator>>{};
    for (final c in vizibile) {
      categorii.putIfAbsent(c.categorie, () => []).add(c);
    }

    return Column(
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: const Text(
                          'Calculatoare',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const ButonAjutor(ajutorCalculatoare),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${calculatoare.length} formule și scoruri clinice',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _interogare = v),
                    decoration: InputDecoration(
                      hintText: 'Caută un calculator',
                      hintStyle: const TextStyle(color: AppColors.muted),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.blue,
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
        ),
        Expanded(
          child: vizibile.isEmpty
              ? const Center(
                  child: Text(
                    'Niciun calculator găsit',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    for (final e in categorii.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          e.key.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                      for (final c in e.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CalculatorTile(c),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _CalculatorTile extends StatelessWidget {
  final Calculator calculator;
  const _CalculatorTile(this.calculator);

  @override
  Widget build(BuildContext context) {
    final c = calculator;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CalculatorScreen(calculator: c)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(c.icon, color: AppColors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.titlu,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.descriere,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
