import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/data_model_cache.dart';
import 'package:hg_orm/dao/database_type.dart';

import '../dao/api/entities.dart';
import '../dao/api/export.dart';
import 'dao_cache.dart';

class DatabaseHelper {
  static bool isCache = true;
  static bool isLogicDelete = true;

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
    // 打开数据库
    await databaseType.helper.open(path);
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
    await databaseType.helper.refresh(path);
    // 清空缓存
    DataModelCache.clear();
    // 监听执行
    await listener?.afterDatabaseRefresh?.call();
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
