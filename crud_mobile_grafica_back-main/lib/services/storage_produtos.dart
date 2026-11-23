import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:supabase/supabase.dart';

SupabaseClient? _clienteStorage;

SupabaseClient clienteStorageProdutos() {
  final existente = _clienteStorage;
  if (existente != null) return existente;

  final configuracao = DotEnv();

  // Configuração local do Windows, fora da pasta do Git.
  final pastaLocal = Platform.environment['LOCALAPPDATA'];

  if (pastaLocal != null && pastaLocal.isNotEmpty) {
    final separador = Platform.pathSeparator;

    final arquivo = File(
      '$pastaLocal${separador}MobileGrafica${separador}backend.env',
    );

    if (arquivo.existsSync()) {
      configuracao.load([arquivo.path]);
    }
  }

  // Prioriza a variável do terminal.
  String lerConfiguracao(String nome) {
    final valorTerminal = Platform.environment[nome]?.trim() ?? '';

    if (valorTerminal.isNotEmpty) {
      return valorTerminal;
    }

    return configuracao[nome]?.trim() ?? '';
  }

  final chave = lerConfiguracao('SUPABASE_SECRET_KEY');

  if (chave.isEmpty) {
    throw StateError(
      'Chave secreta ausente. Configure SUPABASE_SECRET_KEY '
      'no terminal ou no arquivo local MobileGrafica/backend.env.',
    );
  }

  if (chave.startsWith('sb_publishable_')) {
    throw StateError(
      'Foi informada uma chave pública. '
      'Use a Secret key ou a chave legada service_role.',
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