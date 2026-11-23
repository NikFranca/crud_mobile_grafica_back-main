import 'dart:io';

import 'package:crud_mobile_grafica_back/models/produtos.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:supabase/supabase.dart' hide HttpMethod;

Response _erro(int status, String mensagem) {
  return Response.json(
    statusCode: status,
    body: {
      'sucesso': false,
      'mensagem': mensagem,
    },
  );
}

Future<Response> onRequest(RequestContext context, String id) async {
  final produtoId = id.trim();

  final uuidValido = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(produtoId);

  if (!uuidValido) {
    return _erro(
      HttpStatus.badRequest,
      'O ID do produto deve ser um UUID válido.',
    );
  }

  final metodo = context.request.method.name.toUpperCase();

  if (metodo != 'PUT' && metodo != 'DELETE') {
    return Response.json(
      statusCode: HttpStatus.methodNotAllowed,
      headers: {'Allow': 'PUT, DELETE'},
      body: {
        'sucesso': false,
        'mensagem': 'Método não permitido.',
      },
    );
  }

  try {
    final supabase = context.read<SupabaseClient>();

    // EXCLUSÃO
    if (metodo == 'DELETE') {
      final removido = await supabase
          .from('produto')
          .delete()
          .eq('id', produtoId)
          .select('id')
          .maybeSingle();

      if (removido == null) {
        return _erro(
          HttpStatus.notFound,
          'Produto não encontrado ou sem permissão para excluir.',
        );
      }

      return Response.json(
        body: {
          'sucesso': true,
          'mensagem': 'Produto excluído com sucesso.',
          'id': produtoId,
        },
      );
    }

    // ATUALIZAÇÃO
    final dados = await context.request.json();

    if (dados is! Map<String, dynamic>) {
      return _erro(
        HttpStatus.badRequest,
        'Envie um objeto JSON com os dados do produto.',
      );
    }

    final produto = Produto.fromJson(dados);

    final possuiImagem = dados.containsKey('imagem') ||
        dados.containsKey('imagemUrl') ||
        dados.containsKey('imagem_url');

    // Campos opcionais ausentes preservam os valores existentes.
    final atualizacao = <String, dynamic>{
      'nome': produto.nome,
      'preco': produto.preco,
      if (dados.containsKey('descricao'))
        'descricao': produto.descricao,
      if (possuiImagem) 'imagem': produto.imagemUrl,
      if (dados.containsKey('categoria'))
        'categoria': produto.categoria,
      if (dados.containsKey('ativo')) 'ativo': produto.ativo,
    };

    final atualizado = await supabase
        .from('produto')
        .update(atualizacao)
        .eq('id', produtoId)
        .select()
        .maybeSingle();

    if (atualizado == null) {
      return _erro(
        HttpStatus.notFound,
        'Produto não encontrado ou sem permissão para atualizar.',
      );
    }

    return Response.json(
      body: {
        'sucesso': true,
        'mensagem': 'Produto atualizado com sucesso.',
        'produto': atualizado,
      },
    );
  } on FormatException catch (erro) {
    return _erro(
      HttpStatus.badRequest,
      erro.message,
    );
  } on PostgrestException catch (erro) {
    stderr.writeln('Erro na operação do produto: $erro');

    if (erro.code == '23503') {
      return _erro(
        HttpStatus.conflict,
        'Este produto está vinculado a um pedido. '
        'Desative o produto para preservar o histórico.',
      );
    }

    if (erro.code == '42501') {
      return _erro(
        HttpStatus.forbidden,
        'Sem permissão para realizar essa operação.',
      );
    }

    return _erro(
      HttpStatus.internalServerError,
      'Não foi possível concluir a operação no banco.',
    );
  } catch (erro, stackTrace) {
    stderr.writeln('Erro ao alterar produto: $erro');
    stderr.writeln(stackTrace);

    return _erro(
      HttpStatus.internalServerError,
      'Erro interno ao processar o produto.',
    );
  }
}