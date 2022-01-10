import 'package:hg_orm/dao/api/database.dart';
import 'package:hg_orm/dao/export.dart';

class DatabaseType {
  final Database database;

  const DatabaseType(this.database);

  /// sembast数据库
  static final DatabaseType sembast = DatabaseType(SembastDatabase());
}
