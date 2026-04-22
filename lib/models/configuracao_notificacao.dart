class ConfiguracaoNotificacao {
  final String? id;
  final bool notificarAntes;
  final int diasAntes;
  final bool notificarApos;
  final int diasApos;

  ConfiguracaoNotificacao({
    this.id,
    this.notificarAntes = false,
    this.diasAntes = 7,
    this.notificarApos = false,
    this.diasApos = 3,
  });

  factory ConfiguracaoNotificacao.fromMap(Map<String, dynamic> map) {
    return ConfiguracaoNotificacao(
      id: map['id'] as String?,
      notificarAntes: map['notificar_antes'] as bool? ?? false,
      diasAntes: map['dias_antes'] as int? ?? 7,
      notificarApos: map['notificar_apos'] as bool? ?? false,
      diasApos: map['dias_apos'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificar_antes': notificarAntes,
      'dias_antes': diasAntes,
      'notificar_apos': notificarApos,
      'dias_apos': diasApos,
    };
  }
}
