import 'package:hg_orm/hg_orm.dart';

/// 数据库配置
class SembastConfig extends DatabaseConfig {
  SembastConfig({required String path, bool? isLogicDelete}) : super(SembastDatabase(path: path, isLogicDelete: isLogicDelete));
}
