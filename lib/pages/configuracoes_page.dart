import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/configuracao_notificacao.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  final _supabase = Supabase.instance.client;
  late StreamSubscription<AuthState> _authSubscription;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _configId;

  bool _notificarAntes = false;
  int _diasAntes = 7;
  bool _notificarApos = false;
  int _diasApos = 3;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
    _authSubscription =
        _supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() { _configId = null; });
        _carregarConfiguracoes();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _carregarConfiguracoes() async {
    // Sem login: usa os valores padrão sem consultar o banco
    if (_supabase.auth.currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser!;
      final data = await _supabase
          .from('configuracoes_notificacao')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null) {
        final config = ConfiguracaoNotificacao.fromMap(data);
        setState(() {
          _configId = config.id;
          _notificarAntes = config.notificarAntes;
          _diasAntes = config.diasAntes;
          _notificarApos = config.notificarApos;
          _diasApos = config.diasApos;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_carregarConfiguracoes: $e');
      _showSnackBar('Não foi possível carregar as configurações. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    // Regra 2: bloqueia ação sem login
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar('Faça login para salvar configurações!', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final dados = {
        ...ConfiguracaoNotificacao(
          notificarAntes: _notificarAntes,
          diasAntes: _diasAntes,
          notificarApos: _notificarApos,
          diasApos: _diasApos,
        ).toMap(),
        'user_id': user.id,
      };

      if (_configId != null) {
        await _supabase
            .from('configuracoes_notificacao')
            .update(dados)
            .eq('id', _configId!);
      } else {
        final result = await _supabase
            .from('configuracoes_notificacao')
            .insert(dados)
            .select()
            .single();
        setState(() => _configId = result['id'] as String);
      }
      _showSnackBar('Configurações salvas com sucesso!');
    } catch (e) {
      if (kDebugMode) debugPrint('_salvarConfiguracoes: $e');
      _showSnackBar('Não foi possível salvar. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError
            ? const Color(0xFFEF5350)
            : const Color(0xFF66BB6A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Título ───
            const Padding(
              padding: EdgeInsets.only(top: 20.0, bottom: 8.0),
              child: Text(
                'Configurações',
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF66BB6A),
                      ),
                    )
                  : _supabase.auth.currentUser == null
                      ? _buildLoginRequired()
                      : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notificações',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ─── Card: Notificar antes do vencimento ───
                          _buildCardNotificacao(
                            icon: Icons.notifications_active_outlined,
                            titulo: 'Aviso de vencimento próximo',
                            subtitulo: _notificarAntes
                                ? 'Notificar $_diasAntes ${_diasAntes == 1 ? 'dia' : 'dias'} antes do vencimento'
                                : 'Desativado',
                            ativo: _notificarAntes,
                            onToggle: (v) =>
                                setState(() => _notificarAntes = v),
                            diasLabel: 'Notificar com antecedência de',
                            dias: _diasAntes,
                            onDiasChanged: (v) =>
                                setState(() => _diasAntes = v),
                          ),

                          const SizedBox(height: 16),

                          // ─── Card: Notificar após vencimento ───
                          _buildCardNotificacao(
                            icon: Icons.notification_important_outlined,
                            titulo: 'Lembrete de medicamento vencido',
                            subtitulo: _notificarApos
                                ? 'Renotificar a cada $_diasApos ${_diasApos == 1 ? 'dia' : 'dias'} após o vencimento'
                                : 'Desativado',
                            ativo: _notificarApos,
                            onToggle: (v) => setState(() => _notificarApos = v),
                            diasLabel: 'Repetir notificação a cada',
                            dias: _diasApos,
                            onDiasChanged: (v) => setState(() => _diasApos = v),
                          ),

                          const SizedBox(height: 32),

                          // ─── Botão Salvar ───
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : _salvarConfiguracoes,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                disabledBackgroundColor: const Color(
                                  0xFF2E7D32,
                                ).withValues(alpha: 0.5),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined, size: 20),
                              label: Text(
                                _isSaving
                                    ? 'Salvando...'
                                    : 'Salvar configurações',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginRequired() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Color(0xFF999999)),
            SizedBox(height: 16),
            Text(
              'Faça login para acessar as configurações',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF777777),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardNotificacao({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required bool ativo,
    required ValueChanged<bool> onToggle,
    required String diasLabel,
    required int dias,
    required ValueChanged<int> onDiasChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ativo
              ? const Color(0xFF66BB6A).withValues(alpha: 0.6)
              : Colors.grey.shade200,
          width: ativo ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Cabeçalho do card ───
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ativo
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: ativo
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF999999),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          fontSize: 12,
                          color: ativo
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: ativo,
                  onChanged: onToggle,
                  activeColor: const Color(0xFF2E7D32),
                  activeTrackColor: const Color(
                    0xFF66BB6A,
                  ).withValues(alpha: 0.4),
                ),
              ],
            ),
          ),

          // ─── Stepper de dias (visível só quando ativo) ───
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: ativo
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(color: Colors.grey.shade100, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          diasLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                      _buildStepper(
                        value: dias,
                        minValue: 1,
                        maxValue: 365,
                        onChanged: onDiasChanged,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper({
    required int value,
    required int minValue,
    required int maxValue,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepperButton(
          icon: Icons.remove,
          onPressed: value > minValue ? () => onChanged(value - 1) : null,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value ${value == 1 ? 'dia' : 'dias'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        _buildStepperButton(
          icon: Icons.add,
          onPressed: value < maxValue ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(
          icon,
          size: 20,
          color: onPressed != null
              ? const Color(0xFF2E7D32)
              : const Color(0xFFCCCCCC),
        ),
      ),
    );
  }
}
