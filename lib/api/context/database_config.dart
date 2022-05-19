import 'package:hg_orm/hg_orm.dart';

/// 数据库配置
abstract class DatabaseConfig {
  final Database database;

  DatabaseConfig(this.database);
}
