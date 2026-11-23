import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:supabase/supabase.dart' hide HttpMethod;

String _formatarData(DateTime data) {
  final ano = data.year.toString().padLeft(4, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');

  return '$ano-$mes-$dia';
}

Response _erro(int status, String mensagem) {
  return Response.json(
    statusCode: status,
    body: {
      'sucesso': false,
      'mensagem': mensagem,
    },
  );
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method.name.toUpperCase() != 'GET') {
    return Response.json(
      statusCode: 405,
      headers: {'Allow': 'GET'},
      body: {
        'sucesso': false,
        'mensagem': 'Método não permitido.',
      },
    );
  }

  final dias = int.tryParse(
    context.request.uri.queryParameters['dias'] ?? '7',
  );

  if (dias == null || dias < 2 || dias > 366) {
    return _erro(400, 'Informe um período entre 2 e 366 dias.');
  }

  try {
    final supabase = context.read<SupabaseClient>();

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    final inicio = DateTime(
      hoje.year,
      hoje.month,
      hoje.day - dias + 1,
    );

    final fim = DateTime(
      hoje.year,
      hoje.month,
      hoje.day + 1,
    );

    final pontos = <Map<String, dynamic>>[];
    final porDia = <String, Map<String, dynamic>>{};

    for (var i = 0; i < dias; i++) {
      final data = DateTime(
        inicio.year,
        inicio.month,
        inicio.day + i,
      );

      final ponto = <String, dynamic>{
        'data': _formatarData(data),
        'pagos': 0,
        'pendentes': 0,
        'cancelados': 0,
      };

      pontos.add(ponto);
      porDia[ponto['data'] as String] = ponto;
    }

    final de = '${_formatarData(inicio)}T00:00:00';
    final ate = '${_formatarData(fim)}T00:00:00';

    final quantidade = await supabase
        .from('pagamento')
        .count(CountOption.exact)
        .gte('data', de)
        .lt('data', ate);

    var deslocamento = 0;

    while (deslocamento < quantidade) {
      final ultimo = deslocamento + 499 < quantidade
          ? deslocamento + 499
          : quantidade - 1;

      final registros = await supabase
          .from('pagamento')
          .select('data, status')
          .gte('data', de)
          .lt('data', ate)
          .order('id')
          .range(deslocamento, ultimo);

      if (registros.isEmpty) break;

      for (final registro in registros) {
        final dataTexto = registro['data']?.toString() ?? '';

        if (dataTexto.length < 10) continue;

        final ponto = porDia[dataTexto.substring(0, 10)];

        if (ponto == null) continue;

        final status = registro['status']
                ?.toString()
                .trim()
                .toUpperCase() ??
            '';

        switch (status) {
          case 'CONFIRMADO':
            ponto['pagos'] = (ponto['pagos'] as int) + 1;
            break;

          case 'PENDENTE':
            ponto['pendentes'] =
                (ponto['pendentes'] as int) + 1;
            break;

          case 'CANCELADO':
            ponto['cancelados'] =
                (ponto['cancelados'] as int) + 1;
            break;
        }
      }

      deslocamento += registros.length;
    }

    return Response.json(
      body: {
        'sucesso': true,
        'dias': dias,
        'pontos': pontos,
      },
    );
  } catch (erro) {
    stderr.writeln(
      'Erro ao consultar evolução dos pagamentos: $erro',
    );

    return _erro(
      500,
      'Não foi possível carregar a evolução dos pagamentos.',
    );
  }
}