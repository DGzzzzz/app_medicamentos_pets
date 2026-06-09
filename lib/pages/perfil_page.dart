import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pets_page.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  late StreamSubscription<AuthState> _authSubscription;

  User? _currentUser;

  // Controladores dos formulários
  final _emailLoginCtrl = TextEditingController();
  final _senhaLoginCtrl = TextEditingController();
  final _emailRegistroCtrl = TextEditingController();
  final _senhaRegistroCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();

  // Estados de UI
  bool _mostrarSenhaLogin = false;
  bool _mostrarSenhaRegistro = false;
  bool _registroEmailEnviado = false;
  bool _isLoadingAuth = false;
  bool _isLoadingPerfil = false;
  bool _isSavingPerfil = false;
  bool _isUploadingFoto = false;
  String? _fotoUrl;

  // Valores originais para detectar alterações no perfil
  String _nomeInicial = '';
  String? _fotoUrlInicial;

  bool get _perfilAlterado =>
      _nomeCtrl.text.trim() != _nomeInicial || _fotoUrl != _fotoUrlInicial;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUser = _supabase.auth.currentUser;
    _nomeCtrl.addListener(() { if (mounted) setState(() {}); });

    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _currentUser = data.session?.user);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (mounted) _mostrarDialogNovaSenha(); },
        );
        return;
      }
      setState(() {
        _currentUser = data.session?.user;
        _isLoadingAuth = false;
      });
      if (_currentUser != null) _carregarPerfil();
    });

    if (_currentUser != null) _carregarPerfil();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authSubscription.cancel();
    _emailLoginCtrl.dispose();
    _senhaLoginCtrl.dispose();
    _emailRegistroCtrl.dispose();
    _senhaRegistroCtrl.dispose();
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarPerfil() async {
    if (_currentUser == null) return;
    setState(() => _isLoadingPerfil = true);
    try {
      final data = await _supabase
          .from('perfis')
          .select()
          .eq('id', _currentUser!.id)
          .maybeSingle();

      if (!mounted) return;
      if (data != null) {
        setState(() {
          _nomeCtrl.text = data['nome_completo'] ?? '';
          _fotoUrl = data['foto_url'];
          _nomeInicial = _nomeCtrl.text;
          _fotoUrlInicial = _fotoUrl;
        });
      } else {
        // Preenche com dados do OAuth (Google) se disponível
        final meta = _currentUser!.userMetadata;
        setState(() {
          _nomeCtrl.text = meta?['full_name'] ?? meta?['name'] ?? '';
          _fotoUrl = meta?['avatar_url'];
          _nomeInicial = _nomeCtrl.text;
          _fotoUrlInicial = _fotoUrl;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_carregarPerfil: $e');
      _showSnackBar('Não foi possível carregar o perfil. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingPerfil = false);
    }
  }

  Future<void> _salvarPerfil() async {
    setState(() => _isSavingPerfil = true);
    try {
      await _supabase.from('perfis').upsert({
        'id': _currentUser!.id,
        'nome_completo': _nomeCtrl.text.trim(),
        'foto_url': _fotoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        setState(() {
          _nomeInicial = _nomeCtrl.text.trim();
          _fotoUrlInicial = _fotoUrl;
        });
      }
      _showSnackBar('Perfil salvo com sucesso!');
    } catch (e) {
      if (kDebugMode) debugPrint('_salvarPerfil: $e');
      _showSnackBar('Não foi possível salvar. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingPerfil = false);
    }
  }

  Future<void> _loginComEmail() async {
    if (_emailLoginCtrl.text.trim().isEmpty || _senhaLoginCtrl.text.isEmpty) {
      _showSnackBar('Preencha email e senha!', isError: true);
      return;
    }
    setState(() => _isLoadingAuth = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailLoginCtrl.text.trim(),
        password: _senhaLoginCtrl.text,
      );
    } on AuthException catch (e) {
      _showSnackBar(_traduzirErro(e.message), isError: true);
    } catch (_) {
      _showSnackBar('Erro inesperado. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingAuth = false);
    }
  }

  Future<void> _registrarComEmail() async {
    if (_emailRegistroCtrl.text.trim().isEmpty ||
        _senhaRegistroCtrl.text.isEmpty) {
      _showSnackBar('Preencha email e senha!', isError: true);
      return;
    }
    setState(() => _isLoadingAuth = true);
    try {
      final response = await _supabase.auth.signUp(
        email: _emailRegistroCtrl.text.trim(),
        password: _senhaRegistroCtrl.text,
      );
      // Supabase retorna identities vazio quando o email já está cadastrado
      if (response.user != null &&
          (response.user!.identities?.isEmpty ?? false)) {
        _emailLoginCtrl.text = _emailRegistroCtrl.text.trim();
        _showSnackBar(
          'Este email já possui uma conta. Redirecionando para o login...',
          isError: true,
        );
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) _tabController.animateTo(0);
        return;
      }
      if (mounted) setState(() => _registroEmailEnviado = true);
      _showSnackBar('Conta criada! Verifique seu email para confirmar.');
    } on AuthException catch (e) {
      _showSnackBar(_traduzirErro(e.message), isError: true);
    } catch (_) {
      _showSnackBar('Erro inesperado. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingAuth = false);
    }
  }

  Future<void> _recuperarSenha() async {
    final emailCtrl = TextEditingController(text: _emailLoginCtrl.text.trim());
    String? emailParaEnvio;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Recuperar senha',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe seu email para receber o link de redefinição de senha.',
              style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFF777777)),
                prefixIcon: const Icon(Icons.email_outlined,
                    size: 20, color: Color(0xFF777777)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF777777))),
          ),
          TextButton(
            onPressed: () {
              emailParaEnvio = emailCtrl.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Enviar',
              style: TextStyle(
                  color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (emailParaEnvio == null || emailParaEnvio!.isEmpty) return;

    try {
      await _supabase.auth.resetPasswordForEmail(
        emailParaEnvio!,
        redirectTo: 'medicamentospets://login-callback',
      );
      _showSnackBar('Link de recuperação enviado para $emailParaEnvio!');
    } on AuthException catch (e) {
      _showSnackBar(_traduzirErro(e.message), isError: true);
    } catch (_) {
      _showSnackBar('Erro ao enviar email. Tente novamente.', isError: true);
    }
  }

  Future<void> _loginComGoogle() async {
    setState(() => _isLoadingAuth = true);
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'medicamentospets://login-callback',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('_loginComGoogle: $e');
      _showSnackBar('Não foi possível conectar com o Google. Tente novamente.', isError: true);
    } finally {
      // O browser foi aberto; reseta o loading imediatamente.
      // O onAuthStateChange cuida do login quando o usuário voltar.
      if (mounted) setState(() => _isLoadingAuth = false);
    }
  }

  Future<void> _alterarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    final ext = picked.name.split('.').last.toLowerCase();
    const validExts = ['jpg', 'jpeg', 'png', 'webp'];
    if (!validExts.contains(ext)) {
      _showSnackBar('Formato inválido. Use JPG, PNG ou WebP.', isError: true);
      return;
    }

    setState(() => _isUploadingFoto = true);
    try {
      final bytes = await picked.readAsBytes();
      // Pasta = userId, arquivo = avatar.ext → permite validação por RLS
      final filePath = '${_currentUser!.id}/avatar.$ext';

      await _supabase.storage.from('avatares').uploadBinary(
            filePath,
            bytes,
            fileOptions:
                FileOptions(upsert: true, contentType: 'image/$ext'),
          );

      final url = _supabase.storage.from('avatares').getPublicUrl(filePath);
      // Cache-bust para forçar reload da imagem
      setState(() =>
          _fotoUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      if (kDebugMode) debugPrint('_alterarFoto: $e');
      _showSnackBar('Não foi possível enviar a foto. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingFoto = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair da conta',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: const Text('Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF777777))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _supabase.auth.signOut();
      if (mounted) {
        setState(() {
          _nomeCtrl.clear();
          _fotoUrl = null;
          _nomeInicial = '';
          _fotoUrlInicial = null;
          _registroEmailEnviado = false;
        });
      }
    }
  }

  bool get _isEmailUser =>
      _currentUser?.identities?.any((i) => i.provider == 'email') ?? false;

  Future<void> _mostrarDialogNovaSenha() async {
    final novaSenhaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    bool mostrarNova = false;
    bool mostrarConfirmar = false;
    String? novaSenha;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Criar nova senha',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Defina sua nova senha abaixo.',
                style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: novaSenhaCtrl,
                label: 'Nova senha',
                icon: Icons.lock_outline,
                obscure: !mostrarNova,
                suffix: IconButton(
                  icon: Icon(
                    mostrarNova
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF777777),
                  ),
                  onPressed: () =>
                      setDialogState(() => mostrarNova = !mostrarNova),
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: confirmarCtrl,
                label: 'Confirmar nova senha',
                icon: Icons.lock_reset,
                obscure: !mostrarConfirmar,
                suffix: IconButton(
                  icon: Icon(
                    mostrarConfirmar
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF777777),
                  ),
                  onPressed: () => setDialogState(
                      () => mostrarConfirmar = !mostrarConfirmar),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final nova = novaSenhaCtrl.text;
                final confirmar = confirmarCtrl.text;
                if (nova.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content:
                        Text('A senha deve ter pelo menos 6 caracteres.'),
                    backgroundColor: Color(0xFFEF5350),
                  ));
                  return;
                }
                if (nova != confirmar) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('As senhas não coincidem.'),
                    backgroundColor: Color(0xFFEF5350),
                  ));
                  return;
                }
                novaSenha = nova;
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar',
                  style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (novaSenha == null) return;
    try {
      await _supabase.auth.updateUser(UserAttributes(password: novaSenha!));
      _showSnackBar('Senha redefinida com sucesso!');
    } catch (e) {
      if (kDebugMode) debugPrint('_mostrarDialogNovaSenha: $e');
      _showSnackBar('Não foi possível redefinir a senha. Tente novamente.',
          isError: true);
    }
  }

  Future<void> _mostrarDialogAlterarSenha() async {
    final senhaAtualCtrl = TextEditingController();
    final novaSenhaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    bool mostrarAtual = false;
    bool mostrarNova = false;
    bool mostrarConfirmar = false;
    String? senhaAtual;
    String? novaSenha;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Alterar senha',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: senhaAtualCtrl,
                label: 'Senha atual',
                icon: Icons.lock_outline,
                obscure: !mostrarAtual,
                suffix: IconButton(
                  icon: Icon(
                    mostrarAtual
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF777777),
                  ),
                  onPressed: () =>
                      setDialogState(() => mostrarAtual = !mostrarAtual),
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: novaSenhaCtrl,
                label: 'Nova senha',
                icon: Icons.lock_reset,
                obscure: !mostrarNova,
                suffix: IconButton(
                  icon: Icon(
                    mostrarNova
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF777777),
                  ),
                  onPressed: () =>
                      setDialogState(() => mostrarNova = !mostrarNova),
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: confirmarCtrl,
                label: 'Confirmar nova senha',
                icon: Icons.lock_reset,
                obscure: !mostrarConfirmar,
                suffix: IconButton(
                  icon: Icon(
                    mostrarConfirmar
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF777777),
                  ),
                  onPressed: () => setDialogState(
                      () => mostrarConfirmar = !mostrarConfirmar),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF777777))),
            ),
            TextButton(
              onPressed: () {
                final atual = senhaAtualCtrl.text;
                final nova = novaSenhaCtrl.text;
                final confirmar = confirmarCtrl.text;
                if (atual.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Informe a senha atual.'),
                    backgroundColor: Color(0xFFEF5350),
                  ));
                  return;
                }
                if (nova.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text(
                        'A nova senha deve ter pelo menos 6 caracteres.'),
                    backgroundColor: Color(0xFFEF5350),
                  ));
                  return;
                }
                if (nova != confirmar) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('As senhas não coincidem.'),
                    backgroundColor: Color(0xFFEF5350),
                  ));
                  return;
                }
                senhaAtual = atual;
                novaSenha = nova;
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar',
                  style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (senhaAtual == null || novaSenha == null) return;
    await _alterarSenha(senhaAtual!, novaSenha!);
  }

  Future<void> _alterarSenha(String senhaAtual, String novaSenha) async {
    setState(() => _isLoadingAuth = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _currentUser!.email!,
        password: senhaAtual,
      );
      await _supabase.auth.updateUser(UserAttributes(password: novaSenha));
      _showSnackBar('Senha alterada com sucesso!');
    } on AuthException catch (e) {
      _showSnackBar(_traduzirErro(e.message), isError: true);
    } catch (e) {
      if (kDebugMode) debugPrint('_alterarSenha: $e');
      _showSnackBar('Não foi possível alterar a senha. Tente novamente.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingAuth = false);
    }
  }

  String _traduzirErro(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email ou senha incorretos.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Confirme seu email antes de entrar.';
    }
    if (message.contains('User already registered')) {
      return 'Este email já está cadastrado.';
    }
    if (message.contains('Password should be at least')) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    if (message.contains('Unable to validate email address')) {
      return 'Email inválido.';
    }
    if (message.contains('security purposes') ||
        message.contains('rate limit') ||
        message.contains('email_rate_limit')) {
      return 'Aguarde alguns minutos antes de solicitar novamente.';
    }
    return 'Ocorreu um erro. Tente novamente.';
  }

  Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Não foi possível abrir o link.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            isError ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 20.0, bottom: 8.0),
              child: Text(
                'Minha Conta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Divider(color: Colors.grey.shade300, thickness: 1),
            ),
            Expanded(
              child: _currentUser == null
                  ? _buildLoginView()
                  : _buildPerfilView(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  VIEW: NÃO LOGADO
  // ─────────────────────────────────────────

  Widget _buildLoginView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Image.asset(
          'web/PET_saude/PET_saude.png',
          height: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        const Text(
          'Entre para salvar suas configurações',
          style: TextStyle(fontSize: 13, color: Color(0xFF777777)),
        ),
        const SizedBox(height: 20),

        // TabBar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF555555),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            padding: const EdgeInsets.all(4),
            tabs: const [Tab(text: 'Entrar'), Tab(text: 'Criar conta')],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildTabEntrar(), _buildTabRegistro()],
          ),
        ),
      ],
    );
  }

  Widget _buildTabEntrar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          _buildTextField(
            controller: _emailLoginCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _senhaLoginCtrl,
            label: 'Senha',
            icon: Icons.lock_outline,
            obscure: !_mostrarSenhaLogin,
            suffix: IconButton(
              icon: Icon(
                _mostrarSenhaLogin
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: const Color(0xFF777777),
              ),
              onPressed: () =>
                  setState(() => _mostrarSenhaLogin = !_mostrarSenhaLogin),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _recuperarSenha,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Esqueci minha senha',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildBotaoPrimario(
            label: 'Entrar',
            isLoading: _isLoadingAuth,
            onPressed: _loginComEmail,
          ),
          const SizedBox(height: 16),
          _buildDivisorOu(),
          const SizedBox(height: 16),
          _buildBotaoGoogle(),
        ],
      ),
    );
  }

  Widget _buildTabRegistro() {
    if (_registroEmailEnviado) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read_outlined,
                size: 64, color: Color(0xFF66BB6A)),
            const SizedBox(height: 16),
            const Text(
              'Verifique seu email!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222)),
            ),
            const SizedBox(height: 8),
            Text(
              'Enviamos um link de confirmação para ${_emailRegistroCtrl.text}. Após confirmar, faça login.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, color: Color(0xFF777777)),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() => _registroEmailEnviado = false);
                _tabController.animateTo(0);
              },
              child: const Text('Ir para login',
                  style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          _buildTextField(
            controller: _emailRegistroCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _senhaRegistroCtrl,
            label: 'Senha (mínimo 6 caracteres)',
            icon: Icons.lock_outline,
            obscure: !_mostrarSenhaRegistro,
            suffix: IconButton(
              icon: Icon(
                _mostrarSenhaRegistro
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: const Color(0xFF777777),
              ),
              onPressed: () => setState(
                  () => _mostrarSenhaRegistro = !_mostrarSenhaRegistro),
            ),
          ),
          const SizedBox(height: 20),
          _buildBotaoPrimario(
            label: 'Criar conta',
            isLoading: _isLoadingAuth,
            onPressed: _registrarComEmail,
          ),
          const SizedBox(height: 16),
          _buildDivisorOu(),
          const SizedBox(height: 16),
          _buildBotaoGoogle(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  VIEW: LOGADO
  // ─────────────────────────────────────────

  Widget _buildPerfilView() {
    if (_isLoadingPerfil) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF66BB6A)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // ─── Avatar ───
          GestureDetector(
            onTap: _alterarFoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: const Color(0xFFE8F5E9),
                  backgroundImage:
                      _fotoUrl != null ? NetworkImage(_fotoUrl!) : null,
                  child: _fotoUrl == null
                      ? const Icon(Icons.person,
                          size: 56, color: Color(0xFF2E7D32))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                    child: _isUploadingFoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque para alterar a foto',
            style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 28),

          // ─── Email (somente leitura) ───
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined,
                    size: 18, color: Color(0xFF999999)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _currentUser?.email ?? '',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF777777)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Nome completo ───
          _buildTextField(
            controller: _nomeCtrl,
            label: 'Nome completo',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 28),

          // ─── Botão salvar ───
          _buildBotaoPrimario(
            label: 'Salvar perfil',
            isLoading: _isSavingPerfil,
            onPressed: _perfilAlterado ? _salvarPerfil : null,
          ),

          // ─── Alterar senha (somente contas e-mail) ───
          if (_isEmailUser) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _mostrarDialogAlterarSenha,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF66BB6A)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.lock_outline, size: 20),
                label: const Text('Alterar senha',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // ─── Meus Pets ───
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetsPage()),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                side: const BorderSide(color: Color(0xFF66BB6A)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.pets, size: 20),
              label: const Text(
                'Meus Pets',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ─── Botão sair ───
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Sair da conta',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),

          // ─── Links legais ───
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _abrirUrl(
                    'https://politica-privacidade-chi.vercel.app/'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Política de Privacidade',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF999999)),
                ),
              ),
              Text('·',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400)),
              TextButton(
                onPressed: () => _abrirUrl(
                    'https://exclusao-dados-lime.vercel.app/'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Exclusão de Dados',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF999999)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  WIDGETS COMPARTILHADOS
  // ─────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF777777)),
        prefixIcon:
            Icon(icon, size: 20, color: const Color(0xFF777777)),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildBotaoPrimario({
    required String label,
    required bool isLoading,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          disabledBackgroundColor:
              const Color(0xFF2E7D32).withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDivisorOu() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('ou',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildBotaoGoogle() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoadingAuth ? null : _loginComGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF333333),
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'G',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Continuar com Google',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
