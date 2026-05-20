import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  // On Windows, the documents directory is usually C:\Users\<Username>\Documents
  var userHome = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
  print('USER_HOME: $userHome');
  
  var documentsDir = Directory(p.join(userHome, 'Documents'));
  if (await documentsDir.exists()) {
    print('Documents directory found.');
    var backupsDir = Directory(p.join(documentsDir.path, 'backups'));
    if (await backupsDir.exists()) {
      print('backups folder found inside Documents:');
      backupsDir.listSync().forEach((f) {
        print(' - ${f.path}');
      });
    } else {
      print('backups folder NOT found in Documents.');
    }
  }

  // Also check AppData Local and Roaming for raseed or sqflite databases
  var localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
  print('LOCAL_APP_DATA: $localAppData');
  if (localAppData.isNotEmpty) {
    var searchPaths = [
      p.join(localAppData, 'raseed'),
      p.join(localAppData, 'rseed'),
      p.join(localAppData, 'sqflite'),
      p.join(localAppData, 'com.example.rseed'),
      p.join(localAppData, 'com.raseed.app'),
    ];
    for (var sp in searchPaths) {
      var d = Directory(sp);
      if (await d.exists()) {
        print('Found directory in LOCALAPPDATA: $sp');
        d.listSync(recursive: true).forEach((f) {
          print(' - ${f.path}');
        });
      }
    }
  }
}
