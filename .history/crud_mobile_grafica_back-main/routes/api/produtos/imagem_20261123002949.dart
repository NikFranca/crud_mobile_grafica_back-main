import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:supabase/supabase.dart' hide HttpMethod;
import 'package:uuid/uuid.dart';

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

bool _temAssinatura(
  List<int> bytes,
  List<int> assinatura, {
  int inicio = 0,
}) {
  if (bytes.length < inicio + assinatura.length) {
    return false;
  }

  for (var i = 0; i < assinatura.length; i++) {
    if (bytes[inicio + i] != assinatura[i]) {
      return false;
    }
  }

  return true;
}

String? _extensaoImagem(List<int> bytes) {
  if (_temAssinatura(
    bytes,
    [137, 80, 78, 71, 13, 10, 26, 10],
  )) {
    return 'png';
  }

  if (_temAssinatura(bytes, [255, 216, 255])) {
    return 'jpg';
  }

  if (_temAssinatura(bytes, [82, 73, 70, 70]) &&
      _temAssinatura(bytes, [87, 69, 66, 80], inicio: 8)) {
    return 'webp';
  }

  return null;
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: HttpStatus.methodNotAllowed,
      headers: {'Allow': 'POST'},
      body: {
        'sucesso': false,
        'mensagem': 'Use POST para enviar uma imagem.',
      },
    );
  }

  try {
    final dados = await context.request.json();

    if (dados is! Map<String, dynamic>) {
      return _erro(
        HttpStatus.badRequest,
        'Envie um objeto JSON.',
      );
    }

    final imagemBase64 = dados['imagemBase64'];

    if (imagemBase64 is! String || imagemBase64.isEmpty) {
      return _erro(
        HttpStatus.badRequest,
        'O campo imagemBase64 é obrigatório.',
      );
    }

    final limiteBase64 = ((_limiteBytes + 2) ~/ 3) * 4;

    if (imagemBase64.length > limiteBase64) {
      return _erro(
        HttpStatus.requestEntityTooLarge,
        'A imagem deve ter até 5 MB.',
      );
    }

    final bytes = base64Decode(imagemBase64);

    if (bytes.isEmpty) {
      return _erro(
        HttpStatus.badRequest,
        'A imagem está vazia.',
      );
    }

    if (bytes.length > _limiteBytes) {
      return _erro(
        HttpStatus.requestEntityTooLarge,
        'A imagem deve ter até 5 MB.',
      );
    }

    final extensao = _extensaoImagem(bytes);

    if (extensao == null) {
      return _erro(
        HttpStatus.badRequest,
        'Selecione uma imagem PNG, JPG ou WebP.',
      );
    }

    final nomeInformado = dados['nomeArquivo'];
    final nomeOriginal =
        nomeInformado is String ? nomeInformado : 'produto';

    var nomeSeguro = nomeOriginal
        .split(RegExp(r'[\\/]'))
        .last
        .replaceFirst(RegExp(r'\.[^.]*$'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');

    if (nomeSeguro.isEmpty) nomeSeguro = 'produto';

    if (nomeSeguro.length > 60) {
      nomeSeguro = nomeSeguro.substring(0, 60);
    }

    final caminho = '${_uuid.v4()}-$nomeSeguro.$extensao';

    const tipos = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'webp': 'image/webp',
    };

    final supabase = context.read<SupabaseClient>();
    final storage = supabase.storage.from(_bucket);

    await storage.uploadBinary(
      caminho,
      bytes,
      fileOptions: FileOptions(
        contentType: tipos[extensao]!,
        upsert: false,
      ),
    );

    final url = storage.getPublicUrl(caminho);

    return Response.json(
      statusCode: HttpStatus.created,
      body: {
        'sucesso': true,
        'imagem': url,
        'caminho': caminho,
      },
    );
  } on FormatException {
    return _erro(
      HttpStatus.badRequest,
      'JSON ou conteúdo Base64 inválido.',
    );
  } on StorageException catch (erro) {
    stderr.writeln('Erro ao enviar imagem: $erro');

    final codigo = int.tryParse('${erro.statusCode}');

    if (codigo == 401 || codigo == 403) {
      return _erro(
        HttpStatus.forbidden,
        'O cliente Supabase do backend não tem permissão '
        'para enviar imagens neste bucket.',
      );
    }

    if (codigo == 404) {
      return _erro(
        HttpStatus.notFound,
        'Bucket Imagens_produtos não encontrado ou sem acesso.',
      );
    }

    return _erro(
      HttpStatus.badGateway,
      'Não foi possível enviar a imagem ao Storage.',
    );
  } catch (erro, stackTrace) {
    stderr.writeln('Erro no upload: $erro');
    stderr.writeln(stackTrace);

    return _erro(
      HttpStatus.internalServerError,
      'Erro interno ao enviar a imagem.',
    );
  }
}