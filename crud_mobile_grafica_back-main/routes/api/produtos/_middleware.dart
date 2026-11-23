import 'package:crud_mobile_grafica_back/services/sessoes_admin.dart';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return (context) async {
    final metodo = context.request.method.name.toUpperCase();

    const metodosDeEscrita = {
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
    };

    if (metodosDeEscrita.contains(metodo)) {
      final autorizado = SessoesAdmin.validar(
        context.request.headers['authorization'],
      );

      if (!autorizado) {
        return Response.json(
          statusCode: 401,
          body: {
            'sucesso': false,
            'mensagem': 'Sua sessão expirou. Faça login novamente.',
          },
        );
      }
    }

    return handler(context);
  };
}