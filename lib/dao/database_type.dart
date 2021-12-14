import 'package:hg_orm/dao/api/database.dart';
import 'package:hg_orm/dao/export.dart';

class DatabaseType {
  final Database helper;

  const DatabaseType(this.helper);

  /// sembast数据库
  static final DatabaseType sembast = DatabaseType(SembastDatabaseHelper());
}
