import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:supabase/supabase.dart';

SupabaseClient? _clienteStorage;

SupabaseClient clienteStorageProdutos() {
  final existente = _clienteStorage;
  if (existente != null) return existente;

  final configuracao = DotEnv();
  final pastaLocal = Platform.environment['LOCALAPPDATA'];

  if (pastaLocal != null && pastaLocal.isNotEmpty) {
    final separador = Platform.pathSeparator;

    final arquivo = File(
      '$pastaLocal${separador}MobileGrafica'
      '${separador}backend.env',
    );

    if (arquivo.existsSync()) {
      configuracao.load([arquivo.path]);
    }
  }

  String lerConfiguracao(String nome) {
    // Prioriza o arquivo local que acabamos de validar.
    final valorArquivo = configuracao[nome]?.trim() ?? '';

    if (valorArquivo.isNotEmpty) {
      return valorArquivo;
    }

    return Platform.environment[nome]?.trim() ?? '';
  }

  final chave = lerConfiguracao('SUPABASE_SECRET_KEY');

  if (!chave.startsWith('sb_secret_')) {
    throw StateError(
      'Configure a Secret key validada no arquivo '
      'MobileGrafica/backend.env.',
    );
  }

  final urlConfigurada = lerConfiguracao('SUPABASE_URL');

  final url = urlConfigurada.isNotEmpty
      ? urlConfigurada
      : 'https://fshgacospypbgxzzpnxt.supabase.co';

  final cliente = SupabaseClient(url, chave);
  _clienteStorage = cliente;

  return cliente;
}