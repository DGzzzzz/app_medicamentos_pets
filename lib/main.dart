import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'pages/main_page.dart';
import 'services/notification_service.dart';
import 'services/background_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fehmhdpkbzrjpruzxuqa.supabase.co',
    anonKey: 'sb_publishable_wR9OMVnavXX30_pC__wY0A_28llfZZ5',
  );

  await NotificationService.initialize();

  await Workmanager().initialize(callbackDispatcher);
  await agendarVerificacaoDiaria();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Saúde+',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      locale: const Locale('pt', 'BR'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8BC34A),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainPage(),
    );
  }
}
