import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/charging_session.dart';
import '../models/group.dart';
import '../models/vehicle.dart';

enum WppStatus { sent, copied, configMissing, error }

class WppResult {
  final WppStatus status;
  final String snackbarText;
  const WppResult(this.status, this.snackbarText);
}

class WhatsappService {
  static final WhatsappService _instance = WhatsappService._internal();
  factory WhatsappService() => _instance;
  WhatsappService._internal();

  String buildStartMessage(ChargingSession session, Vehicle vehicle) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final previsto = session.horaInicio.add(const Duration(hours: 2));
    final bloco = vehicle.bloco?.isNotEmpty == true
        ? 'Bloco ${vehicle.bloco} / Apto ${vehicle.apto}'
        : 'Apto ${vehicle.apto}';

    return '🔌 *INÍCIO DE CARREGAMENTO*\n\n'
        '👤 *Proprietário:* ${vehicle.nomeProprietario}\n'
        '🚗 *Placa:* ${vehicle.placa}\n'
        '🏠 *$bloco*\n'
        '⏰ *Início:* ${fmt.format(session.horaInicio)}\n'
        '📅 *Previsão de término:* ~${fmt.format(previsto)}\n\n'
        '_Sistema Carregou — Gestão de Carregamento_';
  }

  String buildEndMessage(ChargingSession session, Vehicle vehicle) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final bloco = vehicle.bloco?.isNotEmpty == true
        ? 'Bloco ${vehicle.bloco} / Apto ${vehicle.apto}'
        : 'Apto ${vehicle.apto}';

    return '✅ *CARREGADOR LIBERADO*\n\n'
        '👤 *Proprietário:* ${vehicle.nomeProprietario}\n'
        '🚗 *Placa:* ${vehicle.placa}\n'
        '🏠 *$bloco*\n'
        '⏰ *Início:* ${fmt.format(session.horaInicio)}\n'
        '🏁 *Término:* ${fmt.format(session.horaFim!)}\n'
        '⏱️ *Duração:* ${session.durationFormatted}\n\n'
        '🔋 *Carregador disponível!*\n\n'
        '_Sistema Carregou — Gestão de Carregamento_';
  }

  Future<WppResult> sendMessage(String message, Group group) async {
    return _copyToClipboard(message);
  }

  Future<WppResult> _copyToClipboard(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    return const WppResult(
      WppStatus.copied,
      '📋 Mensagem copiada! Cole no grupo do WhatsApp.',
    );
  }
}
