import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';

const _taskName = 'verificar_medicamentos';
const _taskUniqueName = 'medicamentos_pets_daily_check';

const _supabaseUrl = 'https://fehmhdpkbzrjpruzxuqa.supabase.co';
const _supabaseKey = 'sb_publishable_wR9OMVnavXX30_pC__wY0A_28llfZZ5';

// Deve ser top-level e anotada com @pragma para o WorkManager encontrá-la
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseKey);
      await NotificationService.initialize();

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return true; // Não logado, nada a fazer

      final configData = await supabase
          .from('configuracoes_notificacao')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final notificarAntes = configData?['notificar_antes'] as bool? ?? false;
      final diasAntes = configData?['dias_antes'] as int? ?? 7;
      final notificarApos = configData?['notificar_apos'] as bool? ?? false;
      final diasApos = configData?['dias_apos'] as int? ?? 3;

      if (!notificarAntes && !notificarApos) return true;

      final rows = await supabase
              .from('agendamentos')
              .select()
              .eq('user_id', user.id)
              .eq('finalizado', false)
          as List;

      final hoje = DateTime.now();
      final hojeData = DateTime(hoje.year, hoje.month, hoje.day);

      for (final item in rows) {
        final validadeStr = item['validade'] as String?;
        if (validadeStr == null) continue;

        final validade = DateTime.parse(validadeStr);
        final validadeData = DateTime(
          validade.year,
          validade.month,
          validade.day,
        );
        final dias = validadeData.difference(hojeData).inDays;
        final descricao = item['descricao'] as String? ?? 'Medicamento';
        // ID estável por medicamento para não duplicar notificações
        final notifId = item['id'].toString().hashCode.abs() % 100000;

        if (dias < 0 && notificarApos) {
          final vencidoHa = dias.abs();
          // Notifica a cada diasApos dias após o vencimento
          if (vencidoHa % diasApos == 0) {
            await NotificationService.show(
              id: notifId,
              title: 'Medicamento vencido',
              body:
                  '$descricao venceu há $vencidoHa ${vencidoHa == 1 ? "dia" : "dias"}.',
            );
          }
        } else if (dias >= 0 && dias <= diasAntes && notificarAntes) {
          await NotificationService.show(
            id: notifId,
            title: dias == 0 ? 'Medicamento vence hoje!' : 'Vencimento próximo',
            body: dias == 0
                ? '$descricao vence hoje!'
                : '$descricao vence em $dias ${dias == 1 ? "dia" : "dias"}.',
          );
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> agendarVerificacaoDiaria() async {
  await Workmanager().registerPeriodicTask(
    _taskUniqueName,
    _taskName,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
