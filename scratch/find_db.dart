import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var dbPath = await databaseFactory.getDatabasesPath();
  print('DATABASES_PATH: $dbPath');

  var dir = Directory(dbPath);
  if (await dir.exists()) {
    print('Contents of DATABASES_PATH:');
    dir.listSync().forEach((f) {
      print(' - ${f.path} (Size: ${f.statSync().size} bytes)');
    });
  } else {
    print('DATABASES_PATH does not exist!');
  }
}
