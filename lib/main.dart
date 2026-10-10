import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/asistent_server.dart';
import 'providers/asistent_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/icd_provider.dart';
import 'providers/interactiuni_provider.dart';
import 'providers/medicamente_provider.dart';
import 'providers/setari_text_provider.dart';
import 'providers/sinteza_provider.dart';
import 'screens/acces_screen.dart';
import 'screens/home_shell.dart';
import 'services/claude_client.dart';
import 'services/data_store.dart';
import 'services/notificari_sinteza.dart';
import 'services/voce.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // afla daca exista date descarcate mai noi decat cele din pachet
  await DataStore.instance.init();
  runApp(const MedRoApp());
  // atingerea notificarii de sambata deschide direct sectiunea Sinteză
  NotificariSinteza.instance
    ..laAtingere = (() => tabCurent.value = tabSinteza)
    ..init();
}

class MedRoApp extends StatelessWidget {
  const MedRoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..incarca()),
        ChangeNotifierProvider(create: (_) => Voce()),
        ChangeNotifierProvider(create: (_) => SetariTextProvider()..incarca()),
        ChangeNotifierProvider(create: (_) => MedicamenteProvider()..incarca()),
        ChangeNotifierProvider(create: (_) => IcdProvider()..incarca()),
        ChangeNotifierProvider(
          create: (_) => InteractiuniProvider()..incarca(),
        ),
        // se incarca abia la prima deschidere a sectiunii
        ChangeNotifierProvider(create: (_) => SintezaProvider()),
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
      child: Consumer<SetariTextProvider>(
        builder: (context, text, _) => MaterialApp(
          title: 'MedRO',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(grosime: text.grosime.grosime),
          locale: const Locale('ro'),
          supportedLocales: const [Locale('ro')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // poarta sta peste tot navigatorul, deci blocheaza si ecranele deschise
          builder: (context, child) {
            // Scrisul arata cum a fost ales in „Setări text”, nu dupa setarile
            // telefonului: „Text aldin” ar ingrosa tot, iar marimea textului
            // din telefon s-ar aduna peste cea aleasa aici.
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                boldText: false,
                textScaler: TextScaler.linear(text.scara),
              ),
              child: PoartaAcces(child: child!),
            );
          },
          home: const HomeShell(),
        ),
      ),
    );
  }
}
