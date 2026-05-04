import 'package:flutter/material.dart';
import '../models/agendamento.dart';

class AgendamentoListItem extends StatelessWidget {
  final Agendamento agendamento;
  final bool isEven;
  final bool notificarAntes;
  final int diasAntes;
  final bool isFinalizado;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onFinalizar;
  final VoidCallback? onReativar;

  final String? petNome;

  const AgendamentoListItem({
    super.key,
    required this.agendamento,
    this.isEven = false,
    this.notificarAntes = false,
    this.diasAntes = 7,
    this.isFinalizado = false,
    this.onEdit,
    this.onDelete,
    this.onFinalizar,
    this.onReativar,
    this.petNome,
  });

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final hojeData = DateTime(hoje.year, hoje.month, hoje.day);
    final validade = DateTime(
      agendamento.validade.year,
      agendamento.validade.month,
      agendamento.validade.day,
    );
    final diasRestantes = validade.difference(hojeData).inDays;

    final isVencido = !isFinalizado && diasRestantes < 0;
    final isProximoVencer =
        !isFinalizado && notificarAntes && !isVencido && diasRestantes <= diasAntes;

    final Color textoColor = isFinalizado
        ? const Color(0xFF999999)
        : isVencido
            ? Colors.redAccent
            : const Color(0xFF333333);

    final Color validadeColor = isFinalizado
        ? const Color(0xFF999999)
        : isVencido
            ? Colors.redAccent
            : isProximoVencer
                ? Colors.orange
                : const Color(0xFF555555);

    return Container(
      decoration: BoxDecoration(
        color: isFinalizado
            ? (isEven ? const Color(0xFFF5F5F5) : Colors.white)
            : (isEven ? const Color(0xFFF1F8E9) : Colors.white),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            if (isVencido || isProximoVencer)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Tooltip(
                  message: isVencido
                      ? 'Medicamento vencido'
                      : 'Vence em $diasRestantes ${diasRestantes == 1 ? 'dia' : 'dias'}',
                  child: Icon(
                    isVencido
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: isVencido ? Colors.redAccent : Colors.orange,
                  ),
                ),
              ),

            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    agendamento.descricao,
                    style: TextStyle(fontSize: 14, color: textoColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (petNome != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pets,
                            size: 11, color: Color(0xFFAAAAAA)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            petNome!,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFAAAAAA)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            Expanded(
              flex: 2,
              child: Text(
                agendamento.validadeFormatada,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: validadeColor),
              ),
            ),

            SizedBox(
              width: 32,
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF777777),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'editar') {
                    onEdit?.call();
                  } else if (value == 'finalizar') {
                    onFinalizar?.call();
                  } else if (value == 'reativar') {
                    onReativar?.call();
                  } else if (value == 'excluir') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (!isFinalizado && onEdit != null)
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Color(0xFF555555)),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                  if (!isFinalizado && onFinalizar != null)
                    const PopupMenuItem(
                      value: 'finalizar',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 18, color: Color(0xFF2E7D32)),
                          SizedBox(width: 8),
                          Text('Finalizar',
                              style: TextStyle(color: Color(0xFF2E7D32))),
                        ],
                      ),
                    ),
                  if (isFinalizado && onReativar != null)
                    const PopupMenuItem(
                      value: 'reativar',
                      child: Row(
                        children: [
                          Icon(Icons.restore,
                              size: 18, color: Color(0xFF555555)),
                          SizedBox(width: 8),
                          Text('Reativar'),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Row(
                        children: [
                          Icon(Icons.delete,
                              size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Excluir'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
