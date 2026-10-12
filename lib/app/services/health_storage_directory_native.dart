import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'health_storage_privacy.dart';

/// Keeps durable local health files in Application Support, outside automatic
/// iCloud backup, without moving/deleting data or enabling cloud sync.
Future<Directory> getProtectedApplicationSupportDirectory({
  BilHealthStoragePrivacy? privacy,
  Future<Directory> Function()? directoryResolver,
}) async {
  await (privacy ?? BilHealthStoragePrivacy.instance).ensureProtected();
  return (directoryResolver ?? getApplicationSupportDirectory)();
}
