import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/asistent_server.dart';
import 'providers/asistent_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/icd_provider.dart';
import 'providers/interactiuni_provider.dart';
import 'providers/medicamente_provider.dart';
import 'screens/acces_screen.dart';
import 'screens/home_shell.dart';
import 'services/claude_client.dart';
import 'services/data_store.dart';
import 'services/voce.dart';
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
        ChangeNotifierProvider(create: (_) => AuthProvider()..incarca()),
        ChangeNotifierProvider(create: (_) => Voce()),
        ChangeNotifierProvider(create: (_) => MedicamenteProvider()..incarca()),
        ChangeNotifierProvider(create: (_) => IcdProvider()..incarca()),
        ChangeNotifierProvider(
          create: (_) => InteractiuniProvider()..incarca(),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthProvider>();
            return AsistentProvider(
              ClaudeClient(
                null,
                asistentServerUrl,
                asistentServerToken,
                auth.activ ? auth.tokenId : null,
              ),
            )..incarca();
          },
        ),
      ],
      child: MaterialApp(
        title: 'MedRO',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ro'),
        supportedLocales: const [Locale('ro')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // poarta sta peste tot navigatorul, deci blocheaza si ecranele deschise
        builder: (context, child) {
          // Aplicatia arata la fel indiferent de setarile de text ale
          // telefonului: „Text aldin” ar ingrosa tot scrisul, iar marirea
          // textului l-ar scoate din marimile alese. Micsorarea ramane permisa.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              boldText: false,
              textScaler: mq.textScaler.clamp(maxScaleFactor: 1),
            ),
            child: PoartaAcces(child: child!),
          );
        },
        home: const HomeShell(),
      ),
    );
  }
}
