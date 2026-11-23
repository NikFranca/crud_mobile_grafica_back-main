import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:supabase/supabase.dart' hide HttpMethod;

import 'package:crud_mobile_grafica_back/services/sessoes_admin.dart';

Response _erro(int status, String mensagem) {
  return Response.json(
    statusCode: status,
    body: {
      'sucesso': false,
      'mensagem': mensagem,
    },
  );
}

List<String> _statusPagamentos(dynamic valor) {
  final registros = valor is List
      ? valor
      : valor is Map
          ? [valor]
          : <dynamic>[];

  final resultado = <String>{};

  for (final registro in registros) {
    if (registro is! Map) continue;

    final status = registro['status']
            ?.toString()
            .trim()
            .toUpperCase() ??
        '';

    resultado.add(
      status.isEmpty ? 'NAO_INFORMADO' : status,
    );
  }

  return resultado.toList();
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

  if (!SessoesAdmin.validar(
    context.request.headers['authorization'],
  )) {
    return _erro(
      401,
      'Sua sessão expirou. Faça login novamente.',
    );
  }

  final filtro = (
    context.request.uri.queryParameters['pagamento'] ?? 'TODOS'
  ).trim().toUpperCase();

  const filtrosPermitidos = {
    'TODOS',
    'CONFIRMADO',
    'PENDENTE',
    'CANCELADO',
  };

  if (!filtrosPermitidos.contains(filtro)) {
    return _erro(400, 'Filtro de pagamento inválido.');
  }

  try {
    final supabase = context.read<SupabaseClient>();

    final quantidade = await supabase
        .from('pedido')
        .count(CountOption.exact);

    final pedidos = <Map<String, dynamic>>[];
    var deslocamento = 0;

    while (deslocamento < quantidade) {
      final ultimo = deslocamento + 199 < quantidade
          ? deslocamento + 199
          : quantidade - 1;

      final registros = await supabase
          .from('pedido')
          .select(
            'id, data, valor_total, status, '
            'cliente:cliente(nome), '
            'pagamentos:pagamento(status)',
          )
          .order('data', ascending: false)
          .order('id', ascending: false)
          .range(deslocamento, ultimo);

      if (registros.isEmpty) break;

      for (final registro in registros) {
        final pagamentos = _statusPagamentos(
          registro['pagamentos'],
        );

        if (filtro != 'TODOS' &&
            !pagamentos.contains(filtro)) {
          continue;
        }

        final cliente = registro['cliente'];

        final nomeCliente = cliente is Map
            ? cliente['nome']?.toString().trim() ?? ''
            : '';

        pedidos.add({
          'id': registro['id'],
          'data': registro['data'],
          'valor_total': registro['valor_total'],
          'status_pedido': registro['status'],
          'cliente': nomeCliente.isEmpty
              ? 'Cliente não informado'
              : nomeCliente,
          'status_pagamentos': pagamentos,
        });
      }

      deslocamento += registros.length;
    }

    return Response.json(
      body: {
        'sucesso': true,
        'total': pedidos.length,
        'pedidos': pedidos,
      },
    );
  } catch (erro) {
    stderr.writeln('Erro ao listar pedidos: $erro');

    return _erro(
      500,
      'Não foi possível carregar os pedidos.',
    );
  }
}