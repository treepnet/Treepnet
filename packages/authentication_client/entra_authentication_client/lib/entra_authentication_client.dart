/// A Microsoft Entra External ID (OIDC) implementation of the
/// authentication client interface.
library;

export 'package:authentication_client/authentication_client.dart';

export 'src/entra_authentication_client.dart';
export 'src/entra_native_auth_api.dart' show EntraAuthApiException;
