import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/asistent_provider.dart';
import 'providers/icd_provider.dart';
import 'providers/interactiuni_provider.dart';
import 'providers/medicamente_provider.dart';
import 'screens/home_shell.dart';
import 'services/data_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // afla daca exista date descarcate mai noi decat cele din pachet
  await DataStore.instance.init();
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
        locale: const Locale('ro'),
        supportedLocales: const [Locale('ro')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeShell(),
      ),
    );
  }
}
