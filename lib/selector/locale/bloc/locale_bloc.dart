import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'locale_event.dart';

/// Holds the user's language preference.
///
/// State `null` means "follow the device language" — `MaterialApp.locale` is
/// then left null so Flutter resolves the device's preferred locale against the
/// supported locales (falling back to the first supported locale, English, when
/// the device language isn't supported). A non-null state is an explicit choice
/// the user made in-app, which overrides the device language and is persisted.
class LocaleBloc extends HydratedBloc<LocaleEvent, Locale?> {
  LocaleBloc() : super(null) {
    on<LocaleChanged>((event, emit) => emit(event.locale));
  }

  @override
  Locale? fromJson(Map<String, dynamic> json) {
    // Explicit "follow device" choice, or legacy/absent data → null (system).
    if (json['system'] == true) return null;
    final languageCode = json['language_code'] as String?;
    if (languageCode == null) return null;
    return Locale(languageCode, json['country_code'] as String?);
  }

  @override
  Map<String, dynamic>? toJson(Locale? state) {
    // Persist "follow device" explicitly so a prior explicit choice is cleared.
    if (state == null) return {'system': true};
    return {
      'language_code': state.languageCode,
      if (state.countryCode != null) 'country_code': state.countryCode,
    };
  }
}
