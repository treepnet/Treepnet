import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/selector/selector.dart';

/// A drop down menu to select a new [Locale]
///
/// Requires a [LocaleBloc] to be provided in the widget tree
/// (usually above [MaterialApp])
class LocaleSelector extends StatelessWidget {
  const LocaleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.select((LocaleBloc bloc) => bloc.state);

    return DropdownButton<Locale?>(
      key: const Key('localeSelector_dropdown'),
      onChanged: (locale) =>
          context.read<LocaleBloc>().add(LocaleChanged(locale)),
      value: locale,
      items: [
        // `null` = follow the device language (default until the user picks).
        DropdownMenuItem(
          value: null,
          child: Text(
            l10n.systemDefaultText,
            key: const Key('localeSelector_system_dropdownMenuItem'),
          ),
        ),
        DropdownMenuItem(
          value: const Locale('en', 'US'),
          child: Text(
            l10n.enOptionText,
            key: const Key('localeSelector_en_dropdownMenuItem'),
          ),
        ),
        DropdownMenuItem(
          value: const Locale('ru', 'RU'),
          child: Text(
            l10n.ruOptionText,
            key: const Key('localeSelector_ru_dropdownMenuItem'),
          ),
        ),
      ],
    );
  }
}

class LocaleModalOption extends StatelessWidget {
  const LocaleModalOption({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const LocaleSelector(),
      title: Text(context.l10n.languageText),
    );
  }
}
