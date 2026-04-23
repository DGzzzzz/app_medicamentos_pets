import 'package:flutter/material.dart';
import '../models/agendamento.dart';

class AgendamentoListItem extends StatelessWidget {
  final Agendamento agendamento;
  final bool isEven;
  final bool notificarAntes;
  final int diasAntes;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AgendamentoListItem({
    super.key,
    required this.agendamento,
    this.isEven = false,
    this.notificarAntes = false,
    this.diasAntes = 7,
    this.onEdit,
    this.onDelete,
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

    final isVencido = diasRestantes < 0;
    final isProximoVencer =
        notificarAntes && !isVencido && diasRestantes <= diasAntes;

    return Container(
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF1F8E9) : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            // Ícone de alerta (vencido ou próximo do vencimento)
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

            // Descrição
            Expanded(
              flex: 3,
              child: Text(
                agendamento.descricao,
                style: TextStyle(
                  fontSize: 14,
                  color: isVencido
                      ? Colors.redAccent
                      : const Color(0xFF333333),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),

            // Validade
            Expanded(
              flex: 2,
              child: Text(
                agendamento.validadeFormatada,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isVencido
                      ? Colors.redAccent
                      : isProximoVencer
                          ? Colors.orange
                          : const Color(0xFF555555),
                ),
              ),
            ),

            // Menu
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
                  } else if (value == 'excluir') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
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
                  const PopupMenuItem(
                    value: 'excluir',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.redAccent),
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
