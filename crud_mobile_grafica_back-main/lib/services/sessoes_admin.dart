import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class SessoesAdmin {
  SessoesAdmin._();

  static final _aleatorio = Random.secure();
  static final Map<String, DateTime> _sessoes = {};

  static String _hash(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }

  static String criar() {
    final agora = DateTime.now().toUtc();

    _sessoes.removeWhere((_, validade) => !validade.isAfter(agora));

    final bytes = List<int>.generate(
      32,
      (_) => _aleatorio.nextInt(256),
    );

    final token = base64UrlEncode(bytes).replaceAll('=', '');

    _sessoes[_hash(token)] = agora.add(const Duration(hours: 8));

    return token;
  }

  static bool validar(String? authorization) {
    if (authorization == null) return false;

    final partes = authorization.trim().split(RegExp(r'\s+'));

    if (partes.length != 2 ||
        partes.first.toLowerCase() != 'bearer') {
      return false;
    }

    final token = partes.last;

    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      return false;
    }

    final chave = _hash(token);
    final validade = _sessoes[chave];

    if (validade == null) return false;

    if (!validade.isAfter(DateTime.now().toUtc())) {
      _sessoes.remove(chave);
      return false;
    }

    return true;
  }
}