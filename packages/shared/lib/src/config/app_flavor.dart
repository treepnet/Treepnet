// ignore_for_file: public_member_api_docs

import 'package:env/env.dart';

enum Flavor { development, staging, production }

sealed class AppEnv {
  const AppEnv();

  String getEnv(Env env);
}

class AppFlavor extends AppEnv {
  const AppFlavor._({required this.flavor});

  factory AppFlavor.development() =>
      const AppFlavor._(flavor: Flavor.development);
  factory AppFlavor.staging() => const AppFlavor._(flavor: Flavor.staging);
  factory AppFlavor.production() =>
      const AppFlavor._(flavor: Flavor.production);

  final Flavor flavor;

  @override
  String getEnv(Env env) => switch (env) {
    Env.powerSyncUrl => switch (flavor) {
      Flavor.development => EnvDev.powersyncUrl,
      Flavor.production => EnvProd.powersyncUrl,
      Flavor.staging => EnvProd.powersyncUrl,
    },
  };
}
