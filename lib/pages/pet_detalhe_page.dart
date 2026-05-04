import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agendamento.dart';
import '../models/pet.dart';

class PetDetalhePage extends StatefulWidget {
  final Pet pet;

  const PetDetalhePage({super.key, required this.pet});

  @override
  State<PetDetalhePage> createState() => _PetDetalhePageState();
}

class _PetDetalhePageState extends State<PetDetalhePage> {
  final _supabase = Supabase.instance.client;
  late Pet _pet;
  List<Agendamento> _agendamentos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _carregarAgendamentos();
  }

  Future<void> _carregarAgendamentos() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('agendamentos')
          .select()
          .eq('pet_id', _pet.id!)
          .order('validade', ascending: false);
      setState(() {
        _agendamentos =
            (data as List).map((e) => Agendamento.fromMap(e)).toList();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('PetDetalhePage._carregarAgendamentos: $e');
      _showSnackBar('Não foi possível carregar o histórico.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _alternarAtivo() async {
    try {
      await _supabase
          .from('pets')
          .update({'ativo': !_pet.ativo})
          .eq('id', _pet.id!);
      setState(() {
        _pet = Pet(
          id: _pet.id,
          nome: _pet.nome,
          ativo: !_pet.ativo,
          createdAt: _pet.createdAt,
        );
      });
    } catch (e) {
      if (kDebugMode) debugPrint('PetDetalhePage._alternarAtivo: $e');
      _showSnackBar('Não foi possível atualizar o pet.', isError: true);
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
      appBar: AppBar(
        title: Text(
          _pet.nome,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF222222)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1, thickness: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Card do pet ───
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _pet.ativo
                      ? const Color(0xFFD0E8D0)
                      : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _pet.ativo
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pets,
                      size: 26,
                      color: _pet.ativo
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pet.nome,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _pet.ativo
                                    ? const Color(0xFF66BB6A)
                                    : const Color(0xFFBBBBBB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _pet.ativo ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                fontSize: 13,
                                color: _pet.ativo
                                    ? const Color(0xFF66BB6A)
                                    : const Color(0xFFAAAAAA),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Switch(
                        value: _pet.ativo,
                        onChanged: (_) => _alternarAtivo(),
                        activeColor: const Color(0xFF2E7D32),
                      ),
                      Text(
                        _pet.ativo ? 'Desativar' : 'Ativar',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFAAAAAA)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Título do histórico ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Colors.grey.shade300, thickness: 1),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text(
              'Histórico de Agendamentos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ),

          // ─── Lista do histórico ───
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF66BB6A)))
                : _agendamentos.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum agendamento\nregistrado para este pet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF999999)),
                          ),
                        ),
                      )
                    : _buildHistorico(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorico() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
          color: const Color(0xFFFFF8FA),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Cabeçalho
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
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
                      'Validade',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  SizedBox(width: 80),
                ],
              ),
            ),

            // Itens
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _agendamentos.length,
              itemBuilder: (context, index) {
                return _buildHistoricoItem(
                    _agendamentos[index], index.isEven);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricoItem(Agendamento ag, bool isEven) {
    return Container(
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF1F8E9) : Colors.white,
        border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              ag.descricao,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF333333)),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              ag.validadeFormatada,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF555555)),
            ),
          ),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: ag.finalizado
                    ? const Color(0xFFECEFF1)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ag.finalizado ? 'Finalizado' : 'Ativo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ag.finalizado
                      ? const Color(0xFF546E7A)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
