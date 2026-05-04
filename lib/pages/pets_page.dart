import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pet.dart';
import 'pet_detalhe_page.dart';

class PetsPage extends StatefulWidget {
  const PetsPage({super.key});

  @override
  State<PetsPage> createState() => _PetsPageState();
}

class _PetsPageState extends State<PetsPage> {
  final _supabase = Supabase.instance.client;
  List<Pet> _pets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarPets();
  }

  Future<void> _carregarPets() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('pets')
          .select()
          .eq('user_id', user.id)
          .order('nome', ascending: true);
      setState(() {
        _pets = (data as List).map((e) => Pet.fromMap(e)).toList();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('_carregarPets: $e');
      _showSnackBar('Não foi possível carregar os pets.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _adicionarPet(String nome) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('pets').insert({
        'user_id': user.id,
        'nome': nome.trim(),
        'ativo': true,
      });
      await _carregarPets();
      _showSnackBar('Pet adicionado com sucesso!');
    } catch (e) {
      if (kDebugMode) debugPrint('_adicionarPet: $e');
      _showSnackBar('Não foi possível adicionar o pet.', isError: true);
    }
  }

  Future<void> _alternarAtivo(Pet pet) async {
    try {
      await _supabase
          .from('pets')
          .update({'ativo': !pet.ativo})
          .eq('id', pet.id!);
      await _carregarPets();
    } catch (e) {
      if (kDebugMode) debugPrint('_alternarAtivo: $e');
      _showSnackBar('Não foi possível atualizar o pet.', isError: true);
    }
  }

  Future<void> _mostrarDialogNovoPet() async {
    final nomeCtrl = TextEditingController();
    String? nome;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Novo pet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: nomeCtrl,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nome do pet',
            labelStyle:
                const TextStyle(fontSize: 13, color: Color(0xFF777777)),
            prefixIcon: const Icon(Icons.pets,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF777777))),
          ),
          TextButton(
            onPressed: () {
              nome = nomeCtrl.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Salvar',
              style: TextStyle(
                  color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (nome != null && nome!.isNotEmpty) {
      await _adicionarPet(nome!);
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
        title: const Text(
          'Meus Pets',
          style: TextStyle(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogNovoPet,
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF66BB6A)))
          : _pets.isEmpty
              ? _buildEmptyState()
              : _buildPetList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, size: 56, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum pet cadastrado',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque no + para adicionar seu primeiro pet',
            style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }

  Widget _buildPetList() {
    final ativos = _pets.where((p) => p.ativo).toList();
    final inativos = _pets.where((p) => !p.ativo).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        if (ativos.isNotEmpty) ...[
          _buildSectionLabel('Ativos'),
          const SizedBox(height: 8),
          ...ativos.map((pet) => _buildPetCard(pet)),
        ],
        if (inativos.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSectionLabel('Inativos'),
          const SizedBox(height: 8),
          ...inativos.map((pet) => _buildPetCard(pet)),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFFAAAAAA),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildPetCard(Pet pet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PetDetalhePage(pet: pet)),
        ).then((_) => _carregarPets()),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pet.ativo
                  ? const Color(0xFFD0E8D0)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ícone circular
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pet.ativo
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pets,
                  size: 22,
                  color: pet.ativo
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF999999),
                ),
              ),
              const SizedBox(width: 14),

              // Nome e status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.nome,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: pet.ativo
                            ? const Color(0xFF222222)
                            : const Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: pet.ativo
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFFBBBBBB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          pet.ativo ? 'Ativo' : 'Inativo',
                          style: TextStyle(
                            fontSize: 12,
                            color: pet.ativo
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Toggle
              Switch(
                value: pet.ativo,
                onChanged: (_) => _alternarAtivo(pet),
                activeColor: const Color(0xFF2E7D32),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),

              // Seta para detalhe
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFBBBBBB),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
