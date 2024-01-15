import 'package:mime/mime.dart' as mime;

/// Matches all strings that ends with `.gz` or `.tgz` and has at least one character before that
///
/// We should remove this after [mime#66](dart-lang/mime#66) released.
final gZipRegExp = RegExp('.\\.(gz|tgz)\$');

const applicationGZip = 'application/gzip';

String? lookupMimeType(String path, {List<int>? headerBytes}) {
  final pathMatch = gZipRegExp.firstMatch(path);
  if (pathMatch != null) {
    return applicationGZip;
  }

  return mime.lookupMimeType(path, headerBytes: headerBytes);
}

String lookupMimeTypeWithDefaultType(String path, {List<int>? headerBytes}) {
  path = path.toLowerCase();

  return lookupMimeType(path, headerBytes: headerBytes) ?? octetStream;
}

const String octetStream = 'application/octet-stream';
