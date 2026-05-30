import 'package:sqflite/sqflite.dart';

void main() {
  print('databaseFactory is: $databaseFactory');
  try {
    // Let's see if we can find other variables
    // print(databaseFactorySqflitePlugin);
  } catch (e) {
    print('Error: $e');
  }
}
