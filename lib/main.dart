import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/asistent_provider.dart';
import 'providers/icd_provider.dart';
import 'providers/interactiuni_provider.dart';
import 'providers/medicamente_provider.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedRoApp());
}

class MedRoApp extends StatelessWidget {
  const MedRoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MedicamenteProvider()..incarca()),
        ChangeNotifierProvider(create: (_) => IcdProvider()..incarca()),
        ChangeNotifierProvider(
          create: (_) => InteractiuniProvider()..incarca(),
        ),
        ChangeNotifierProvider(create: (_) => AsistentProvider()..incarca()),
      ],
      child: MaterialApp(
        title: 'MedRO',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
