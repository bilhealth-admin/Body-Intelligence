import '../domain/cloud_operational_models.dart';

final class CloudSchemaNegotiator {
  const CloudSchemaNegotiator({this.minimumSupportedVersion = 1});
  final int minimumSupportedVersion;

  CloudSchemaAgreement negotiate({
    required int localVersion,
    required int remoteVersion,
  }) {
    final compatible =
        localVersion >= minimumSupportedVersion &&
        remoteVersion >= minimumSupportedVersion;
    return CloudSchemaAgreement(
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      negotiatedVersion: localVersion < remoteVersion
          ? localVersion
          : remoteVersion,
      compatible: compatible,
    );
  }
}
