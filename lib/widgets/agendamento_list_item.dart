import 'package:flutter/material.dart';
import '../models/agendamento.dart';

class AgendamentoListItem extends StatelessWidget {
  final Agendamento agendamento;
  final bool isEven;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AgendamentoListItem({
    super.key,
    required this.agendamento,
    this.isEven = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFFFF0F3) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            // Descrição
            Expanded(
              flex: 3,
              child: Text(
                agendamento.descricao,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF333333),
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
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                ),
              ),
            ),
            // Menu icon
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
