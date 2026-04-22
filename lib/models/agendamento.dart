class Agendamento {
  final String? id;
  final String descricao;
  final DateTime dataAplicacao;
  final DateTime validade;

  Agendamento({
    this.id,
    required this.descricao,
    required this.dataAplicacao,
    required this.validade,
  });

  factory Agendamento.fromMap(Map<String, dynamic> map) {
    return Agendamento(
      id: map['id'] as String,
      descricao: map['descricao'] as String,
      dataAplicacao: DateTime.parse(map['data_aplicacao'] as String),
      validade: DateTime.parse(map['validade'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao,
      'data_aplicacao': dataAplicacao.toIso8601String().substring(0, 10),
      'validade': validade.toIso8601String().substring(0, 10),
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
