import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/catalog_pack.dart';

/// Resolves each parent without following attacker-controlled catalog links.
Future<File> safeCatalogFile(
  Directory root,
  List<String> components, {
  bool createParents = false,
}) async {
  if (components.isEmpty ||
      components.any((value) => !CatalogPack.isSafeComponent(value))) {
    throw const FormatException('Unsafe catalog path component');
  }
  if (createParents) await root.create(recursive: true);
  var current = await root.resolveSymbolicLinks();
  for (var index = 0; index < components.length; index++) {
    current = p.join(current, components[index]);
    final type = await FileSystemEntity.type(current, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw StateError('Catalog paths must not contain symbolic links');
    }
    if (index < components.length - 1 && createParents) {
      await Directory(current).create();
    }
  }
  return File(current);
}

/// Keeps the previously verified file until its replacement is ready.
Future<void> replaceCatalogFile(File temporary, File destination) async {
  final backup = File('${destination.path}.previous');
  if (await FileSystemEntity.type(backup.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw StateError('An unresolved catalog backup already exists');
  }
  final existed = await destination.exists();
  if (existed) await destination.rename(backup.path);
  try {
    await temporary.rename(destination.path);
  } catch (_) {
    if (existed) await backup.rename(destination.path);
    rethrow;
  }
  if (existed) await backup.delete();
}
