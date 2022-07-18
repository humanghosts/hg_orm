import 'package:hg_orm/hg_orm.dart';

/// 数据库配置
abstract class DatabaseConfig {
  /// 数据库
  final Database database;

  DatabaseConfig(this.database);
}
