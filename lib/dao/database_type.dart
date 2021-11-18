import 'package:hg_orm/dao/api/database_helper.dart';
import 'package:hg_orm/dao/export.dart';

class DatabaseType {
  final DatabaseHelper helper;

  const DatabaseType(this.helper);

  /// sembast数据库
  static final DatabaseType sembast = DatabaseType(SembastDatabaseHelper());
}
