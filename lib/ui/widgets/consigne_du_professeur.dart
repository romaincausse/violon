import 'package:flutter/material.dart';

/// Le mot du professeur sur le passage en cours (lot K14).
///
/// Il etait range avec le devoir (T1) mais ne se lisait que dans le
/// repertoire, loin du moment ou il sert. Il s'affiche la ou l'on travaille,
/// en une ligne ou deux, dans la voix du professeur et pas dans celle de
/// l'application : entre guillemets, signe d'un chapeau.
class ConsigneDuProfesseur extends StatelessWidget {
  const ConsigneDuProfesseur({required this.mot, super.key});

  final String mot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.school_outlined, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '"${mot.trim()}"',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
