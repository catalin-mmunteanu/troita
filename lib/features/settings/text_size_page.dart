import 'package:material_ui/material_ui.dart';

import '../../app/text_size.dart';
import 'settings_widgets.dart';

/// Setări → Mărimea textului: the control, and a passage to judge it by.
class TextSizePage extends StatelessWidget {
  const TextSizePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mărimea textului')),
        body: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 40),
          children: <Widget>[
            const TextSizeCard(),
            const SectionHeader('Așa arată'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Sfântul Ierarh Nicolae, Arhiepiscopul Mirelor Lichiei, '
                'făcătorul de minuni. Dezlegare la pește.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Footnote(
              'Mărimea se aplică peste tot în aplicație și se adaugă la cea '
              'din setările telefonului. Se schimbă și din Profil, din Lecturi '
              'și de pe ecranul unei zile, cu A− și A+.',
            ),
          ],
        ),
      );
}
