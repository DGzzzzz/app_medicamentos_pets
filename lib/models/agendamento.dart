class Agendamento {
  final String? id;
  final String descricao;
  final DateTime dataAplicacao;
  final DateTime validade;
  final bool finalizado;
  final DateTime? finalizadoEm;
  final String? petId;
  final String? petNome;

  Agendamento({
    this.id,
    required this.descricao,
    required this.dataAplicacao,
    required this.validade,
    this.finalizado = false,
    this.finalizadoEm,
    this.petId,
    this.petNome,
  });

  factory Agendamento.fromMap(Map<String, dynamic> map) {
    return Agendamento(
      id: map['id'] as String,
      descricao: map['descricao'] as String,
      dataAplicacao: DateTime.parse(map['data_aplicacao'] as String),
      validade: DateTime.parse(map['validade'] as String),
      finalizado: map['finalizado'] as bool? ?? false,
      finalizadoEm: map['finalizado_em'] != null
          ? DateTime.parse(map['finalizado_em'] as String)
          : null,
      petId: map['pet_id'] as String?,
      petNome: map['pets'] is Map
          ? (map['pets'] as Map<String, dynamic>)['nome'] as String?
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao,
      'data_aplicacao': dataAplicacao.toIso8601String().substring(0, 10),
      'validade': validade.toIso8601String().substring(0, 10),
      'pet_id': petId,
    };
  }

  String get validadeFormatada {
    return '${validade.day.toString().padLeft(2, '0')}/'
        '${validade.month.toString().padLeft(2, '0')}/'
        '${validade.year}';
  }

  String get dataAplicacaoFormatada {
    return '${dataAplicacao.day.toString().padLeft(2, '0')}/'
        '${dataAplicacao.month.toString().padLeft(2, '0')}/'
        '${dataAplicacao.year}';
  }
}
