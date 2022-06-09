import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/hg_orm.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static Database? _database;

  static Database get database {
    assert(_database != null, "先打开数据库");
    return _database!;
  }

  /// 需要处理好constructor的依赖顺序，保证被依赖的先注册，因为构造方法中可能含有取值操作
  static Future<void> open({required DatabaseConfig config}) async {
    _database = config.database;
    await config.database.open();
    await config.database.openKV();
    // 注册hg_orm下的构造器
    ormEntitiesMap.forEach((key, value) => ConstructorCache.put(key, value));
  }

  /// 刷新数据库
  static Future<void> refresh() async {
    // 刷新数据库
    await database.refresh();
    // 清空缓存
    DataModelCache.clear();
  }

  /// 获取键值对数据库
  static KV get kv => database.kv;

  /// 开启一个事务
  static Future<void> transaction(Future<void> Function(Transaction tx) action) async {
    return await database.transaction((tx) async {
      await action(tx);
    });
  }

  /// 有事务使用事务，没有事务新开一个事务
  static Future<void> withTransaction(Transaction? tx, Future<void> Function(Transaction tx) action) async {
    if (null == tx) {
      await transaction(action);
    } else {
      await action(tx);
    }
  }
}
