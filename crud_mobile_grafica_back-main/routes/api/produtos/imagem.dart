import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_frog/dart_frog.dart';
import 'package:supabase/supabase.dart' hide HttpMethod;
import 'package:uuid/uuid.dart';

import 'package:crud_mobile_grafica_back/services/sessoes_admin.dart';
import 'package:crud_mobile_grafica_back/services/storage_produtos.dart';

const _bucket = 'Imagens_produtos';
const _limiteBytes = 5 * 1024 * 1024;
const _uuid = Uuid();

Response _erro(int status, String mensagem) {
  return Response.json(
    statusCode: status,
    body: {
      'sucesso': false,
      'mensagem': mensagem,
    },
  );
}

bool _comecaCom(Uint8List bytes, List<int> assinatura) {
  if (bytes.length < assinatura.length) return false;

  for (var i = 0; i < assinatura.length; i++) {
    if (bytes[i] != assinatura[i]) return false;
  }

  return true;
}

String? _detectarExtensao(Uint8List bytes) {
  if (_comecaCom(bytes, [137, 80, 78, 71, 13, 10, 26, 10])) {
    return 'png';
  }

  if (_comecaCom(bytes, [255, 216, 255])) {
    return 'jpg';
  }

  if (bytes.length >= 12 &&
      _comecaCom(bytes, [82, 73, 70, 70]) &&
      bytes[8] == 87 &&
      bytes[9] == 69 &&
      bytes[10] == 66 &&
      bytes[11] == 80) {
    return 'webp';
  }

  return null;
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method.name.toUpperCase() != 'POST') {
    return Response.json(
      statusCode: 405,
      headers: {'Allow': 'POST'},
      body: {
        'sucesso': false,
        'mensagem': 'Método não permitido.',
      },
    );
  }

  final autorizado = SessoesAdmin.validar(
    context.request.headers['authorization'],
  );

  if (!autorizado) {
    return _erro(
      401,
      'Faça login novamente para enviar a imagem.',
    );
  }

  try {
    final dados = await context.request.json();

    if (dados is! Map<String, dynamic>) {
      return _erro(400, 'Envie um objeto JSON.');
    }

    final imagemBase64 = dados['imagemBase64'];

    if (imagemBase64 is! String || imagemBase64.isEmpty) {
      return _erro(400, 'O campo imagemBase64 é obrigatório.');
    }

    final limiteBase64 = ((_limiteBytes + 2) ~/ 3) * 4;

    if (imagemBase64.length > limiteBase64) {
      return _erro(413, 'A imagem deve ter até 5 MB.');
    }

    final bytes = base64Decode(imagemBase64);

    if (bytes.isEmpty) {
      return _erro(400, 'A imagem está vazia.');
    }

    if (bytes.length > _limiteBytes) {
      return _erro(413, 'A imagem deve ter até 5 MB.');
    }

    final extensao = _detectarExtensao(bytes);

    if (extensao == null) {
      return _erro(
        415,
        'Escolha uma imagem PNG, JPG ou WebP.',
      );
    }

    const tipos = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'webp': 'image/webp',
    };

    final caminho = '${_uuid.v4()}.$extensao';

    final storage = clienteStorageProdutos()
        .storage
        .from(_bucket);

    await storage
        .uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(
            contentType: tipos[extensao]!,
            upsert: false,
          ),
        )
        .timeout(const Duration(seconds: 60));

    final url = storage.getPublicUrl(caminho);

    return Response.json(
      statusCode: 201,
      body: {
        'sucesso': true,
        'imagem': url,
        'caminho': caminho,
      },
    );
  } on FormatException {
    return _erro(
      400,
      'Os dados da imagem estão inválidos.',
    );
  } on TimeoutException {
    return _erro(
      504,
      'O envio da imagem demorou para confirmar.',
    );
  } on StateError catch (erro) {
    stderr.writeln('Configuração do upload: ${erro.message}');

    return _erro(
      503,
      'O envio de imagens ainda não está configurado no servidor.',
    );
  } on StorageException catch (erro) {
    final mensagem = erro.message.replaceAll(
      RegExp(r'sb_secret_[A-Za-z0-9_-]+'),
      '[chave ocultada]',
    );

    stderr.writeln(
      'Erro do Storage: ${erro.statusCode} — $mensagem',
    );

    return _erro(
      502,
      'O serviço de imagens recusou o envio.',
    );
  } catch (erro, stackTrace) {
    stderr.writeln('Falha no upload: ${erro.runtimeType}');
    stderr.writeln(stackTrace);

    return _erro(
      500,
      'Não foi possível enviar a imagem.',
    );
  }
}