import 'dart:io';

import 'package:ardrive_io/ardrive_io.dart';
import 'package:ardrive_io/src/io_exception.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:permission_handler/permission_handler.dart';

/// Returns the folder name to the given path
///
/// Accepts a non empty String
String getBasenameFromPath(String entityPath) {
  if (entityPath.isEmpty) {
    throw EntityPathException();
  }

  return path.basename(entityPath);
}

/// Returns the Gets the part of [entityPath] before the last separator.
/// Accepts a non empty String
String getDirname(String entityPath) {
  if (entityPath.isEmpty) {
    throw EntityPathException();
  }

  return path.dirname(entityPath);
}

/// Gets the path to the default mobile downloads dir
///
/// Before usage it needs `Storage` permission
/// call:
///
/// ``` dart
/// await requestPermissions();
/// await verifyPermissions();
/// ```
Future<String> getDefaultMobileDownloadDir() async {
  if (Platform.isAndroid) {
    return _getDefaultAndroidDir();
  } else if (Platform.isIOS) {
    return _getDefaultIOSDir();
  } else {
    throw UnsupportedPlatformException(
      'getDefaultMobileDownloadDir only applies to mobile.',
    );
  }
}

/// Returns the file extension from the file `name`, when having, in other case the extension
/// will be provided by the `contentType`.
///
/// use `withExtensionDot` when want only the extension without the ` .`
///
/// For example: `application/pdf` => `pdf`
///
/// By default it will return with the ` .`
///
/// For example: `application/pdf` => `.pdf`
String getFileExtension({
  required String name,
  required String contentType,
  bool withExtensionDot = true,
}) {
  String ext = path.extension(name);

  if (ext.isNotEmpty) {
    if (withExtensionDot) {
      return ext;
    }

    return ext.replaceFirst('.', '');
  } else {
    ext = mime.extensionFromMime(contentType);

    if (withExtensionDot) {
      return '.$ext';
    }

    return ext;
  }
}

Future<String> _getDefaultIOSDir() async {
  final iosDirectory = await path_provider.getApplicationDocumentsDirectory();
  final iosDownloadsDirectory = Directory(iosDirectory.path + '/Downloads/');

  if (!iosDownloadsDirectory.existsSync()) {
    iosDownloadsDirectory.createSync();
  }

  return iosDownloadsDirectory.path;
}

Future<String> _getDefaultAndroidDir() async {
  final Directory defaultAndroidDownloadDir =
      Directory('/storage/emulated/0/Download/');

  if (await Permission.manageExternalStorage.isGranted &&
      await defaultAndroidDownloadDir.exists()) {
    return defaultAndroidDownloadDir.path;
  } else {
    final externalDir = await path_provider.getExternalStorageDirectory();

    if (externalDir != null) {
      return externalDir.path;
    } else {
      final directory = await path_provider.getApplicationDocumentsDirectory();
      return directory.path;
    }
  }
}

/// Searches for an empty filename in the given [saveDir] and returns it.
/// If the file already exists, it will append a number to the filename in brackets.
/// Returns only the name of the file as a string.
Future<String> emptyFileName(String saveDir, String fileName, String? fileContentType) async {
  String testFileName;
  int counter = 0;
  while (true) {
    final baseWithoutExt = path.basenameWithoutExtension(fileName);

    if (counter == 0) {
      testFileName = baseWithoutExt;
    } else {
      testFileName = '$baseWithoutExt ($counter)';
    }

    var extension = path.extension(fileName); // includes '.'
    if (extension.isNotEmpty) {
      extension = extension.substring(1);
    } else {
      extension = mime.extensionFromMime(fileContentType ?? ''); // excludes '.'
    }
    
    if (extension.isNotEmpty) {
      testFileName += '.$extension';
    }

    final testFile = File(saveDir + testFileName);
    if (!await testFile.exists()) break;
    
    counter++;
  }

  return testFileName;
}

Future<File> emptyFile(String saveDir, IOFile ioFile) async {
  final fileName = await emptyFileName(saveDir, ioFile.name, ioFile.contentType);
  return File(saveDir + fileName);
}
