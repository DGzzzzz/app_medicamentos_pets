import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agendamento.dart';
import '../models/configuracao_notificacao.dart';
import '../models/pet.dart';
import '../widgets/agendamento_list_item.dart';

class AgendamentosPage extends StatefulWidget {
  const AgendamentosPage({super.key});

  @override
  State<AgendamentosPage> createState() => _AgendamentosPageState();
}

class _AgendamentosPageState extends State<AgendamentosPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  late StreamSubscription<AuthState> _authSubscription;
  final TextEditingController _descricaoController = TextEditingController();
  final FocusNode _descricaoFocusNode = FocusNode();
  DateTime? _dataAplicacao;
  DateTime? _validade;
  String? _editingId;
  bool _isLoading = false;

  List<Agendamento> _agendamentos = [];
  List<Agendamento> _agendamentosFinalizados = [];
  List<Pet> _pets = [];
  Pet? _petSelecionado;
  bool _notificarAntes = false;
  int _diasAntes = 7;

  static const int _maxDescricaoLength = 100;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarAgendamentos();
    _carregarConfiguracoes();
    _carregarPets();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        _carregarAgendamentos();
        _carregarConfiguracoes();
        _carregarPets();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _carregarPets() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _pets = []);
      return;
    }
    try {
      final data = await _supabase
          .from('pets')
          .select()
          .eq('user_id', user.id)
          .order('nome', ascending: true);
      if (mounted) {
        setState(() {
          _pets = (data as List).map((e) => Pet.fromMap(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _carregarAgendamentos() async {
    if (_supabase.auth.currentUser == null) {
      setState(() {
        _agendamentos = [];
        _agendamentosFinalizados = [];
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('agendamentos')
          .select('*, pets(nome)')
          .order('validade', ascending: true);
      final all = (data as List).map((e) => Agendamento.fromMap(e)).toList();
      setState(() {
        _agendamentos = all.where((a) => !a.finalizado).toList();
        _agendamentosFinalizados = all.where((a) => a.finalizado).toList();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('_carregarAgendamentos: $e');
      _showSnackBar(
        'Não foi possível carregar os agendamentos. Tente novamente.',
        isError: true,
      );
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

  Future<void> _selecionarPet() async {
    await _carregarPets();
    _descricaoFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    final petsAtivos = _pets.where((p) => p.ativo).toList();

    Pet? selecionado = _petSelecionado;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Selecionar pet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opção "Nenhum"
              RadioListTile<Pet?>(
                value: null,
                groupValue: selecionado,
                activeColor: const Color(0xFF2E7D32),
                title: const Text('Nenhum',
                    style: TextStyle(fontSize: 14, color: Color(0xFF777777))),
                onChanged: (v) => setDialogState(() => selecionado = v),
              ),
              if (petsAtivos.isNotEmpty)
                Divider(color: Colors.grey.shade200, height: 1),
              ...petsAtivos.map((pet) => RadioListTile<Pet?>(
                    value: pet,
                    groupValue: selecionado,
                    activeColor: const Color(0xFF2E7D32),
                    title: Text(pet.nome,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF333333))),
                    secondary: const Icon(Icons.pets,
                        size: 20, color: Color(0xFF66BB6A)),
                    onChanged: (v) => setDialogState(() => selecionado = v),
                  )),
              if (petsAtivos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Nenhum pet ativo. Adicione pets no seu perfil.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
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
                setState(() => _petSelecionado = selecionado);
                Navigator.pop(ctx);
              },
              child: const Text(
                'Confirmar',
                style: TextStyle(
                    color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _limparFormulario() {
    setState(() {
      _descricaoController.clear();
      _dataAplicacao = null;
      _validade = null;
      _editingId = null;
      _petSelecionado = null;
    });
  }

  Future<void> _salvarAgendamento() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar('Faça login para cadastrar agendamentos!', isError: true);
      return;
    }

    if (_descricaoController.text.isEmpty ||
        _dataAplicacao == null ||
        _validade == null ||
        _petSelecionado == null) {
      _showSnackBar('Preencha todos os campos obrigatórios!', isError: true);
      return;
    }

    final isEditing = _editingId != null;
    final dados = Agendamento(
      descricao: _descricaoController.text,
      dataAplicacao: _dataAplicacao!,
      validade: _validade!,
      petId: _petSelecionado?.id,
    ).toMap();

    try {
      if (isEditing) {
        await _supabase
            .from('agendamentos')
            .update(dados)
            .eq('id', _editingId!);
      } else {
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

  Future<void> _editarAgendamento(Agendamento agendamento) async {
    if (_supabase.auth.currentUser == null) {
      _showSnackBar('Faça login para editar agendamentos!', isError: true);
      return;
    }
    await _carregarPets();
    if (!mounted) return;
    Pet? pet;
    if (agendamento.petId != null) {
      try {
        pet = _pets.firstWhere((p) => p.id == agendamento.petId);
      } catch (_) {
        pet = null;
      }
    }
    setState(() {
      _descricaoController.text = agendamento.descricao;
      _dataAplicacao = agendamento.dataAplicacao;
      _validade = agendamento.validade;
      _editingId = agendamento.id;
      _petSelecionado = pet;
    });
  }

  void _excluirAgendamento(Agendamento agendamento) {
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
                _showSnackBar(
                  'Não foi possível excluir. Tente novamente.',
                  isError: true,
                );
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

  Future<void> _finalizarAgendamento(Agendamento agendamento) async {
    if (_supabase.auth.currentUser == null) {
      _showSnackBar('Faça login para finalizar agendamentos!', isError: true);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirmar finalização',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Deseja finalizar o agendamento "${agendamento.descricao}"?\n\nEle será movido para a aba de finalizados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF777777)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Finalizar',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabase.from('agendamentos').update({
        'finalizado': true,
        'finalizado_em': DateTime.now().toIso8601String(),
      }).eq('id', agendamento.id!);
      if (_editingId == agendamento.id) _limparFormulario();
      await _carregarAgendamentos();
      _showSnackBar('Agendamento finalizado!');
    } catch (e) {
      if (kDebugMode) debugPrint('_finalizarAgendamento: $e');
      _showSnackBar(
        'Não foi possível finalizar. Tente novamente.',
        isError: true,
      );
    }
  }

  Future<void> _reativarAgendamento(Agendamento agendamento) async {
    if (_supabase.auth.currentUser == null) {
      _showSnackBar('Faça login para reativar agendamentos!', isError: true);
      return;
    }
    try {
      await _supabase.from('agendamentos').update({
        'finalizado': false,
        'finalizado_em': null,
      }).eq('id', agendamento.id!);
      await _carregarAgendamentos();
      _showSnackBar('Agendamento reativado!');
    } catch (e) {
      if (kDebugMode) debugPrint('_reativarAgendamento: $e');
      _showSnackBar(
        'Não foi possível reativar. Tente novamente.',
        isError: true,
      );
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

                    // ─── Toggle de abas ───
                    Container(
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
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.all(4),
                        tabs: const [
                          Tab(text: 'Salvos'),
                          Tab(text: 'Finalizados'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── Lista da aba ativa ───
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) => _tabController.index == 0
                          ? _buildListaAgendamentos()
                          : _buildListaFinalizados(),
                    ),

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
          _buildPetField(),
          const SizedBox(height: 12),
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

  Widget _buildPetField() {
    return GestureDetector(
      onTap: _selecionarPet,
      child: InputDecorator(
        isEmpty: _petSelecionado == null,
        decoration: InputDecoration(
          labelText: 'Pet *',
          labelStyle:
              const TextStyle(fontSize: 13, color: Color(0xFF777777)),
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
            borderSide:
                const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
          ),
          suffixIcon: _petSelecionado != null
              ? GestureDetector(
                  onTap: () => setState(() => _petSelecionado = null),
                  child: const Icon(Icons.clear,
                      size: 18, color: Color(0xFF777777)),
                )
              : const Icon(Icons.pets,
                  size: 18, color: Color(0xFF777777)),
        ),
        child: Text(
          _petSelecionado?.nome ?? '',
          style: const TextStyle(fontSize: 14),
        ),
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
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) =>
              null,
      decoration: InputDecoration(
        labelText: 'Descrição',
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF777777)),
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
          borderSide:
              const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
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
          labelStyle:
              const TextStyle(fontSize: 13, color: Color(0xFF777777)),
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
            borderSide:
                const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                final ag = _agendamentos[index];
                return AgendamentoListItem(
                  agendamento: ag,
                  isEven: index.isEven,
                  notificarAntes: _notificarAntes,
                  diasAntes: _diasAntes,
                  petNome: ag.petNome,
                  onEdit: () => _editarAgendamento(ag),
                  onFinalizar: () => _finalizarAgendamento(ag),
                  onDelete: () => _excluirAgendamento(ag),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildListaFinalizados() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
        color: const Color(0xFFFAFAFA),
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
              color: Color(0xFFECEFF1),
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
                      color: Color(0xFF546E7A),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Validade',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF546E7A),
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
          else if (_agendamentosFinalizados.isEmpty)
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
                      'Nenhum agendamento finalizado.',
                      style: TextStyle(color: Color(0xFF999999)),
                    ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _agendamentosFinalizados.length,
              itemBuilder: (context, index) {
                final ag = _agendamentosFinalizados[index];
                return AgendamentoListItem(
                  agendamento: ag,
                  isEven: index.isEven,
                  isFinalizado: true,
                  petNome: ag.petNome,
                  onReativar: () => _reativarAgendamento(ag),
                  onDelete: () => _excluirAgendamento(ag),
                );
              },
            ),
        ],
      ),
    );
  }
}
