import 'dart:io';
import 'package:project_tools/project_tools.dart';
import 'generate_readme.dart' show dartFormatter;

void main() {
  for (var project in DartProject.find(Directory.current)) {
    for (var modifiedFile in formatProject(project, dartFormatter)) {
      print('Formatted: ${modifiedFile.project.packageName}:'
          '${modifiedFile.relativePath}');
    }
  }
}
