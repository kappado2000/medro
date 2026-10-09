import 'package:flutter/material.dart';

import '../screens/depot_screen.dart';
import '../screens/monitorizare_screen.dart';
import '../screens/plan_doze_screen.dart';
import 'calculator.dart';

const _categorie = 'Instrumente de prescriere';

Rezultat? _faraFormula(Map<String, Object> _) => null;

/// Instrumente cu ecran propriu, afisate in lista de calculatoare.
final List<Calculator> instrumente = [
  Calculator(
    id: 'plan_doze',
    titlu: 'Plan de reducere sau titrare',
    descriere: 'Calendarul dozelor, pas cu pas, până la doza țintă',
    categorie: _categorie,
    icon: Icons.trending_down,
    campuri: const [],
    sursa: 'Calcul aritmetic.',
    calculeaza: _faraFormula,
    ecran: () => const PlanDozeScreen(),
  ),
  Calculator(
    id: 'depot',
    titlu: 'Injecții depot',
    descriere: 'Datele următoarelor administrări și fereastra din RCP',
    categorie: _categorie,
    icon: Icons.vaccines_outlined,
    campuri: const [],
    sursa: 'RCP-urile produselor.',
    calculeaza: _faraFormula,
    ecran: () => const DepotScreen(),
  ),
  Calculator(
    id: 'monitorizare',
    titlu: 'Monitorizare din RCP',
    descriere: 'Analize și controale cerute la clozapină, valproat…',
    categorie: _categorie,
    icon: Icons.monitor_heart_outlined,
    campuri: const [],
    sursa: 'RCP-urile produselor.',
    calculeaza: _faraFormula,
    ecran: () => const MonitorizareScreen(),
  ),
];
