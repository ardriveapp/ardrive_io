import 'dart:io';

import 'package:ardrive_io/ardrive_io.dart';
import 'package:file_saver/file_saver.dart' as file_saver;
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;

class MobileIO implements ArDriveIO {
  MobileIO({
    required FileSaver fileSaver,
    required IOFolderAdapter folderAdapter,
    required FileProviderFactory fileProviderFactory,
  })  : _fileSaver = fileSaver,
        _fileProviderFactory = fileProviderFactory;

  final FileSaver _fileSaver;
  final FileProviderFactory _fileProviderFactory;

  @override
  Future<IOFile> pickFile({
    List<String>? allowedExtensions,
    required FileSource fileSource,
  }) async {
    await verifyStoragePermission();

    final provider = _fileProviderFactory.fromSource(fileSource);

    return provider.pickFile(
      fileSource: fileSource,
      allowedExtensions: allowedExtensions,
    );
  }

  @override
  Future<List<IOFile>> pickFiles({
    List<String>? allowedExtensions,
    required FileSource fileSource,
  }) async {
    await verifyStoragePermission();

    final provider =
        _fileProviderFactory.fromSource(fileSource) as MultiFileProvider;

    final files = await provider.pickMultipleFiles(
      fileSource: fileSource,
      allowedExtensions: allowedExtensions,
    );

    return files;
  }

  @override
  Future<IOFolder> pickFolder() async {
    if (Platform.isAndroid) {
      await requestPermissions();
    }

    await verifyStoragePermission();

    final provider = _fileProviderFactory.fromSource(FileSource.fileSystem)
        as MultiFileProvider;

    return provider.getFolder();
  }

  @override
  Future<void> saveFile(IOFile file) async {
    try {
      await _fileSaver.save(file);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> saveFileStream(IOFile file, Future<bool> verified) async {
    try {
      return await _fileSaver.saveStream(file, verified);
    } catch (e) {
      rethrow;
    }
  }
}

/// Opens the file picker dialog to select the folder to save
///
/// This implementation uses the `file_saver` package.
///
/// Throws an `FileSystemPermissionDeniedException` when user deny access to storage
class MobileSelectableFolderFileSaver implements FileSaver {
  @override
  Future<void> save(IOFile file) async {
    await requestPermissions();
    await verifyPermissions();

    await file_saver.FileSaver.instance.saveAs(
      name: file.name,
      bytes: await file.readAsBytes(),
      mimeType: file.contentType,
    );

    return;
  }
  
  @override
  Future<bool> saveStream(IOFile file, Future<bool> verified) {
    // file_saver doesn't seem to support support saving streams
    // TODO: implement saveStream
    throw UnimplementedError();
  }
}

/// Saves a file using the `dart:io` library.
/// It will save on `getDefaultMobileDownloadDir()`
class DartIOFileSaver implements FileSaver {
  Future<File> _emptyFile(IOFile ioFile, String saveDir) async {
    var counter = 0;
    String fileName;
    File testFile;
    while (true) {
      final basename = p.basename(ioFile.name);
      var extension = p.extension(ioFile.name);
      if (extension.isEmpty) {
        extension = mime.extensionFromMime(ioFile.contentType);
      }

      if (counter == 0) {
        fileName = basename + '.' + extension;
      } else {
        fileName = '$basename ($counter).$extension';
      }

      testFile = File(saveDir + fileName);
      if (!await testFile.exists()) break;
      counter++;
    }

    return testFile;
  }

  @override
  Future<void> save(IOFile file) async {
    await requestPermissions();
    await verifyPermissions();

    /// platform_specific_path/Downloads/
    final defaultDownloadDir = await getDefaultMobileDownloadDir();

    final newFile = await _emptyFile(file, defaultDownloadDir);

    await newFile.writeAsBytes(await file.readAsBytes());
  }
  
  @override
  Future<bool> saveStream(IOFile file, Future<bool> verified) async {
    var abort = false;
    verified.then((ok) {if (!ok) abort = true;});
    
    await requestPermissions();
    await verifyPermissions();

    /// platform_specific_path/Downloads/
    final defaultDownloadDir = await getDefaultMobileDownloadDir();

    final newFile = await _emptyFile(file, defaultDownloadDir);

    final sink = newFile.openWrite();

    // NOTE: This is an alternative to `addStream` with lower level control
    const flushThresholdBytes = 10 * 1024 * 1024; // 10 MiB
    var unflushedDataBytes = 0;
    await for (final chunk in file.openReadStream()) {
      if (abort) break;

      sink.add(chunk);
      unflushedDataBytes += chunk.length;
      if (unflushedDataBytes > flushThresholdBytes) {
        await sink.flush();
        unflushedDataBytes = 0;
      }
    }
    await sink.flush();
    await sink.close();
    
    // await sink.addStream(file.openReadStream());
    // await sink.flush();
    // await sink.close();

    final ok = await verified;
    if (!ok) {
      await newFile.delete();
    }

    return ok;
  }
}

/// Defines the API for saving `IOFile` on Storage
abstract class FileSaver {
  factory FileSaver() {
    if (Platform.isAndroid || Platform.isIOS) {
      return DartIOFileSaver();
    }
    throw UnsupportedPlatformException(
        'The ${Platform.operatingSystem} platform is not supported');
  }

  Future<void> save(IOFile file);

  Future<bool> saveStream(IOFile file, Future<bool> verified);
}
