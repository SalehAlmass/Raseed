import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  print('Starting search for raseed.db...');
  final home = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Eng_Saleh';
  final dir = Directory(home);
  
  await for (final entity in dir.list(recursive: true, followLinks: false).handleError((e) {
    // Ignore permissions errors
  })) {
    if (entity is File && p.basename(entity.path) == 'raseed.db') {
      print('FOUND DATABASE: ${entity.path} (Size: ${entity.lengthSync()} bytes)');
    }
  }
  print('Search finished.');
}
