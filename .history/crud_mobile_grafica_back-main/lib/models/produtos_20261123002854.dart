class Produto {
  final String? id;
  final String nome;
  final String descricao;
  final double preco;
  final String? imagemUrl;
  final String? categoria;
  final bool ativo;

  const Produto({
    this.id,
    required this.nome,
    this.descricao = '',
    required this.preco,
    this.imagemUrl,
    this.categoria,
    this.ativo = true,
  });

  factory Produto.fromJson(Map<String, dynamic> json) {
    String? textoOpcional(Object? valor, String campo) {
      if (valor == null) return null;

      if (valor is! String) {
        throw FormatException('O campo "$campo" deve ser um texto.');
      }

      final texto = valor.trim();
      return texto.isEmpty ? null : texto;
    }

    final nome = textoOpcional(json['nome'], 'nome');

    if (nome == null) {
      throw const FormatException('O nome do produto é obrigatório.');
    }

    final valor = json['preco'];
    final double? preco = valor is num
        ? valor.toDouble()
        : valor is String
            ? double.tryParse(valor.trim().replaceAll(',', '.'))
            : null;

    if (preco == null || !preco.isFinite || preco <= 0) {
      throw const FormatException(
        'O preço deve ser maior que zero.',
      );
    }

    // Prioriza a coluna real do banco e aceita os nomes antigos.
    final imagemInformada = json.containsKey('imagem')
        ? json['imagem']
        : json['imagemUrl'] ?? json['imagem_url'];

    final imagem = textoOpcional(imagemInformada, 'imagem');

    if (imagem != null) {
      final uri = Uri.tryParse(imagem);

      if (uri == null ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw const FormatException(
          'A imagem deve conter uma URL válida.',
        );
      }
    }

    if (json.containsKey('ativo') && json['ativo'] is! bool) {
      throw const FormatException(
        'O campo ativo deve ser true ou false.',
      );
    }

    return Produto(
      id: textoOpcional(json['id'], 'id'),
      nome: nome,
      descricao: textoOpcional(json['descricao'], 'descricao') ?? '',
      preco: preco,
      imagemUrl: imagem,
      categoria: textoOpcional(json['categoria'], 'categoria'),
      ativo: json['ativo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'descricao': descricao,
      'preco': preco,
      'imagem': imagemUrl,
      'categoria': categoria,
      'ativo': ativo,
    };
  }

  Map<String, dynamic> toDatabaseMap() => toJson();

  Produto copyWith({
    String? id,
    String? nome,
    String? descricao,
    double? preco,
    String? imagemUrl,
    String? categoria,
    bool? ativo,
  }) {
    return Produto(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      preco: preco ?? this.preco,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      categoria: categoria ?? this.categoria,
      ativo: ativo ?? this.ativo,
    );
  }

  @override
  String toString() {
    return 'Produto(id: $id, nome: $nome, preco: $preco, ativo: $ativo)';
  }
}