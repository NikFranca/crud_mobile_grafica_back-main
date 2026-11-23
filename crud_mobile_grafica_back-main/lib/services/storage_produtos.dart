import 'dart:io';

import 'package:supabase/supabase.dart';

SupabaseClient? _clienteStorage;

SupabaseClient clienteStorageProdutos() {
  final existente = _clienteStorage;
  if (existente != null) return existente;

  final chave =
      Platform.environment['SUPABASE_SECRET_KEY']?.trim() ?? '';

  if (chave.isEmpty || chave.startsWith('sb_publishable_')) {
    throw StateError(
      'Configure SUPABASE_SECRET_KEY no terminal do backend.',
    );
  }

  final url = Platform.environment['SUPABASE_URL'] ??
      'https://fshgacospypbgxzzpnxt.supabase.co';

  final cliente = SupabaseClient(url, chave);
  _clienteStorage = cliente;

  return cliente;
}