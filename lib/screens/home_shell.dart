import 'package:flutter/material.dart';

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
        body: IndexedStack(index: index, children: _pagini),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => tabCurent.value = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: 'Medicamente',
            ),
            NavigationDestination(
              icon: Icon(Icons.compare_arrows),
              label: 'Interacțiuni',
            ),
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: 'Calculatoare',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              label: 'ICD-10',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome),
              label: 'Asistent',
            ),
          ],
        ),
      ),
    );
  }
}
