import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agendamento.dart';
import '../models/configuracao_notificacao.dart';
import '../widgets/agendamento_list_item.dart';

class AgendamentosPage extends StatefulWidget {
  const AgendamentosPage({super.key});

  @override
  State<AgendamentosPage> createState() => _AgendamentosPageState();
}

class _AgendamentosPageState extends State<AgendamentosPage> {
  final _supabase = Supabase.instance.client;
  late StreamSubscription<AuthState> _authSubscription;
  final TextEditingController _descricaoController = TextEditingController();
  final FocusNode _descricaoFocusNode = FocusNode();
  DateTime? _dataAplicacao;
  DateTime? _validade;
  String? _editingId;
  bool _isLoading = false;

  List<Agendamento> _agendamentos = [];
  bool _notificarAntes = false;
  int _diasAntes = 7;

  static const int _maxDescricaoLength = 100;

  @override
  void initState() {
    super.initState();
    _carregarAgendamentos();
    _carregarConfiguracoes();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        _carregarAgendamentos();
        _carregarConfiguracoes();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _descricaoController.dispose();
    _descricaoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _carregarConfiguracoes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('configuracoes_notificacao')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (data != null && mounted) {
        final config = ConfiguracaoNotificacao.fromMap(data);
        setState(() {
          _notificarAntes = config.notificarAntes;
          _diasAntes = config.diasAntes;
        });
      }
    } catch (_) {}
  }

  Future<void> _carregarAgendamentos() async {
    // Regra 1: só carrega se estiver logado (RLS garante no backend também)
    if (_supabase.auth.currentUser == null) {
      setState(() { _agendamentos = []; _isLoading = false; });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('agendamentos')
          .select()
          .order('validade', ascending: true);
      setState(() {
        _agendamentos =
            (data as List).map((e) => Agendamento.fromMap(e)).toList();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('_carregarAgendamentos: $e');
      _showSnackBar('Não foi possível carregar os agendamentos. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectDate(BuildContext context, bool isAplicacao) async {
    _descricaoFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isAplicacao
          ? (_dataAplicacao ?? DateTime.now())
          : (_validade ?? _dataAplicacao ?? DateTime.now()),
      firstDate: (!isAplicacao && _dataAplicacao != null)
          ? _dataAplicacao!
          : DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF66BB6A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF333333),
            ),
          ),
          child: child!,
        );
      },
    );
    if (context.mounted) {
      _descricaoFocusNode.unfocus();
      FocusScope.of(context).unfocus();
    }
    if (picked != null) {
      setState(() {
        if (isAplicacao) {
          _dataAplicacao = picked;
          if (_validade != null && _validade!.isBefore(picked)) {
            _validade = null;
          }
        } else {
          _validade = picked;
        }
      });
    }
  }

  void _limparFormulario() {
    setState(() {
      _descricaoController.clear();
      _dataAplicacao = null;
      _validade = null;
      _editingId = null;
    });
  }

  Future<void> _salvarAgendamento() async {
    // Regra 2: bloqueia ação sem login
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar('Faça login para cadastrar agendamentos!', isError: true);
      return;
    }

    if (_descricaoController.text.isEmpty ||
        _dataAplicacao == null ||
        _validade == null) {
      _showSnackBar('Preencha todos os campos!', isError: true);
      return;
    }

    final isEditing = _editingId != null;
    final dados = Agendamento(
      descricao: _descricaoController.text,
      dataAplicacao: _dataAplicacao!,
      validade: _validade!,
    ).toMap();

    try {
      if (isEditing) {
        await _supabase
            .from('agendamentos')
            .update(dados)
            .eq('id', _editingId!);
      } else {
        // Regra 1: associa o agendamento ao usuário logado
        await _supabase.from('agendamentos').insert({
          ...dados,
          'user_id': user.id,
        });
      }
      _limparFormulario();
      await _carregarAgendamentos();
      _showSnackBar(
        isEditing
            ? 'Agendamento atualizado com sucesso!'
            : 'Agendamento salvo com sucesso!',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('_salvarAgendamento: $e');
      _showSnackBar('Não foi possível salvar. Tente novamente.', isError: true);
    }
  }

  void _editarAgendamento(Agendamento agendamento) {
    // Regra 2: bloqueia ação sem login
    if (_supabase.auth.currentUser == null) {
      _showSnackBar('Faça login para editar agendamentos!', isError: true);
      return;
    }
    setState(() {
      _descricaoController.text = agendamento.descricao;
      _dataAplicacao = agendamento.dataAplicacao;
      _validade = agendamento.validade;
      _editingId = agendamento.id;
    });
  }

  void _excluirAgendamento(Agendamento agendamento) {
    // Regra 2: bloqueia ação sem login
    if (_supabase.auth.currentUser == null) {
      _showSnackBar('Faça login para excluir agendamentos!', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirmar exclusão',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Deseja realmente excluir o agendamento "${agendamento.descricao}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF777777)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _supabase
                    .from('agendamentos')
                    .delete()
                    .eq('id', agendamento.id!);
                if (_editingId == agendamento.id) _limparFormulario();
                await _carregarAgendamentos();
                _showSnackBar('Agendamento excluído!', isError: true);
              } catch (e) {
                if (kDebugMode) debugPrint('_excluirAgendamento: $e');
                _showSnackBar('Não foi possível excluir. Tente novamente.', isError: true);
              }
            },
            child: const Text(
              'Excluir',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
                'Agendamentos',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // ─── Divider ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Divider(color: Colors.grey.shade300, thickness: 1),
            ),

            // ─── Conteúdo scrollável ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ─── Formulário ───
                    _buildFormulario(),

                    const SizedBox(height: 28),

                    // ─── Título da lista ───
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'Agendamentos salvos:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),

                    // ─── Lista de agendamentos ───
                    _buildListaAgendamentos(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDescricaoField(),
          const SizedBox(height: 12),
          _buildDateField(
            label: 'Data de aplicação',
            value: _formatDate(_dataAplicacao),
            onTap: () => _selectDate(context, true),
          ),
          const SizedBox(height: 12),
          _buildDateField(
            label: 'Validade',
            value: _formatDate(_validade),
            onTap: () => _selectDate(context, false),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton(
                label: 'Limpar',
                icon: Icons.cleaning_services_outlined,
                onPressed: _limparFormulario,
                isPrimary: false,
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                label: 'Salvar',
                icon: Icons.save_outlined,
                onPressed: () => _salvarAgendamento(),
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescricaoField() {
    final count = _descricaoController.text.length;
    return TextField(
      controller: _descricaoController,
      focusNode: _descricaoFocusNode,
      maxLength: _maxDescricaoLength,
      inputFormatters: [
        LengthLimitingTextInputFormatter(_maxDescricaoLength),
      ],
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      decoration: InputDecoration(
        labelText: 'Descrição',
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF777777)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        suffix: Text(
          '$count/$_maxDescricaoLength',
          style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
        ),
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
          borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 14),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF777777)),
          floatingLabelStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF66BB6A),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
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
            borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
          ),
          suffixIcon: const Icon(
            Icons.calendar_today,
            size: 18,
            color: Color(0xFF777777),
          ),
        ),
        child: Text(
          value.isEmpty ? '' : value,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF66BB6A).withValues(alpha: 0.4)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF555555),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                icon,
                size: 18,
                color: isPrimary
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF555555),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaAgendamentos() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
        color: const Color(0xFFFFF8FA),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ─── Cabeçalho ───
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFC8E6C9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Descrição',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Validade ↑',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                SizedBox(width: 32),
              ],
            ),
          ),

          // ─── Itens ───
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: Color(0xFF66BB6A)),
            )
          else if (_agendamentos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _supabase.auth.currentUser == null
                  ? const Column(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 32, color: Color(0xFF999999)),
                        SizedBox(height: 8),
                        Text(
                          'Faça login para ver seus agendamentos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF999999)),
                        ),
                      ],
                    )
                  : const Text(
                      'Nenhum agendamento cadastrado.',
                      style: TextStyle(color: Color(0xFF999999)),
                    ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _agendamentos.length,
              itemBuilder: (context, index) {
                return AgendamentoListItem(
                  agendamento: _agendamentos[index],
                  isEven: index.isEven,
                  notificarAntes: _notificarAntes,
                  diasAntes: _diasAntes,
                  onEdit: () => _editarAgendamento(_agendamentos[index]),
                  onDelete: () => _excluirAgendamento(_agendamentos[index]),
                );
              },
            ),
        ],
      ),
    );
  }
}
