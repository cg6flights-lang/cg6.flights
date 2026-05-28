import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Mensajes',
      icon: Icons.mark_unread_chat_alt_outlined,
      summary:
          'Mensajeria interna trazable por usuario, unidad o alcance autorizado.',
      actions: ['Enviar mensaje', 'Ver recibidos', 'Ver enviados'],
    );
  }
}
