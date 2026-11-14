import 'package:envied/envied.dart';

part 'env.prod.g.dart';

/// {@template env}
/// Prod Environment variables. Used to access environment variables in the app.
/// {@endtemplate}
@Envied(path: '.env.prod', obfuscate: true)
abstract class EnvProd {
  /// PowerSync ulr secret.
  @EnviedField(varName: 'POWERSYNC_URL', obfuscate: true)
  static String powersyncUrl = _EnvProd.powersyncUrl;
}
