import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/database_type.dart';

import '../dao/api/export.dart';
import '../dao/entity/entities.dart';
import 'dao_cache.dart';
import 'data_model_cache.dart';

class DatabaseHelper {
  /// 全局设置是否缓存
  static bool isCache = true;

  /// 全局设置是否逻辑删除
  static bool isLogicDelete = true;

  /// 当前数据库类型
  static DatabaseType? currentDatabaseType;

  /// Type 必须是 ModelType
  /// 需要处理好constructor的依赖顺序，保证被依赖的先注册，因为构造方法中可能含有取值操作
  static Future<void> start({
    required String path,
    required DatabaseType databaseType,
    bool? isCache,
    bool? isLogicDelete,
    Map<Type, Object Function([Map<String, dynamic>? args])> Function()? getConstructorMap,
    Map<Type, Dao> Function()? getDaoMap,
    DatabaseListener? listener,
  }) async {
    DatabaseHelper.isCache = isCache ?? true;
    DatabaseHelper.isLogicDelete = isLogicDelete ?? true;
    currentDatabaseType = databaseType;
    // 打开数据库
    await databaseType.database.open(path);
    await databaseType.database.openKV();
    // 监听执行
    await listener?.afterDatabaseOpen?.call();
    // 注册hg_orm下的构造器
    ormEntitiesMap.forEach((key, value) {
      ConstructorCache.put(key, value);
    });
    // 注册外部构造器
    getConstructorMap?.call().forEach((key, value) {
      ConstructorCache.put(key, value);
    });
    // 监听执行
    await listener?.afterModelRegister?.call();
    // 注册dao
    getDaoMap?.call().forEach((key, value) {
      DaoCache.put(key, value);
    });
    // 监听执行
    await listener?.afterDaoRegister?.call();
  }

  /// 刷新数据库
  static Future<void> refresh({
    required String path,
    required DatabaseType databaseType,
    DatabaseListener? listener,
  }) async {
    // 刷新数据库
    await databaseType.database.refresh(path);
    // 清空缓存
    DataModelCache.clear();
    // 监听执行
    await listener?.afterDatabaseRefresh?.call();
  }

  /// 获取键值对数据库
  static KV get kv {
    assert(currentDatabaseType != null, "使用事务前先打开数据库");
    return currentDatabaseType!.database.kv;
  }

  /// 开启一个事务
  static Future<void> transaction(Future<void> Function(Transaction tx) action) async {
    assert(currentDatabaseType != null, "使用事务前先打开数据库");
    Database database = currentDatabaseType!.database;
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

/// 监听数据库事件
class DatabaseListener {
  /// 打开数据库后事件
  Future<void> Function()? afterDatabaseOpen;

  /// 注册dao后事件
  Future<void> Function()? afterDaoRegister;

  /// 注册model类型后事件，一般用于插入数据
  Future<void> Function()? afterModelRegister;

  /// 刷新数据库后事件
  Future<void> Function()? afterDatabaseRefresh;

  DatabaseListener({
    this.afterDatabaseOpen,
    this.afterDaoRegister,
    this.afterModelRegister,
  });
}
