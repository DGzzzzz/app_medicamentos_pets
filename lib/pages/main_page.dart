import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'agendamentos_page.dart';
import 'configuracoes_page.dart';
import 'perfil_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _currentNavIndex;
  late StreamSubscription<AuthState> _authSubscription;

  final List<Widget> _pages = const [
    PerfilPage(),
    AgendamentosPage(),
    ConfiguracoesPage(),
  ];

  @override
  void initState() {
    super.initState();

    // Regra 3 e 4: tela inicial depende do estado de login
    final isLoggedIn =
        Supabase.instance.client.auth.currentUser != null;
    _currentNavIndex = isLoggedIn ? 1 : 0;

    // Navega automaticamente ao logar / deslogar
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // Garante que PerfilPage esteja visível para exibir o dialog de nova senha
        setState(() => _currentNavIndex = 0);
        return;
      }
      final loggedIn = data.session?.user != null;
      setState(() => _currentNavIndex = loggedIn ? 1 : 0);
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentNavIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) => setState(() => _currentNavIndex = index),
      ),
    );
  }
}
