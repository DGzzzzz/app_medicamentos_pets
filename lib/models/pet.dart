class Pet {
  final String? id;
  final String nome;
  final bool ativo;
  final DateTime? createdAt;

  Pet({
    this.id,
    required this.nome,
    this.ativo = true,
    this.createdAt,
  });

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id'] as String?,
      nome: map['nome'] as String,
      ativo: map['ativo'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'ativo': ativo,
    };
  }
}
