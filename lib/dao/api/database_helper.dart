import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/cache.dart';
import 'package:hg_orm/dao/api/entities.dart';

import 'dao.dart';

abstract class DatabaseHelper {
  final DatabaseListener? listener;

  DatabaseHelper(this.listener);

  /// Type must use ModelType
  Future<void> initial({
    Map<Type, Object Function([Map<String, dynamic>? args])> Function()? getConstructorMap,
    Map<Type, Dao> Function()? getDaoMap,
  }) async {
    // 打开数据库
    await open();
    await listener?.afterDatabaseOpen?.call();
    ormEntitiesMap.forEach((key, value) {
      ConstructorCache.put(key, value);
    });
    getConstructorMap?.call().forEach((key, value) {
      ConstructorCache.put(key, value);
    });
    await listener?.afterModelRegister?.call();
    // 注册dao
    getDaoMap?.call().forEach((key, value) {
      DaoCache.put(key, value);
    });
    await listener?.afterDaoRegister?.call();
  }

  /// db专属，打开数据库
  Future<void> open();
}

/// 监听数据库事件
class DatabaseListener {
  /// 打开数据库后事件
  Future<void> Function()? afterDatabaseOpen;

  /// 注册dao后事件
  Future<void> Function()? afterDaoRegister;

  /// 注册model类型后事件，一般用于插入数据
  Future<void> Function()? afterModelRegister;

  DatabaseListener({
    this.afterDatabaseOpen,
    this.afterDaoRegister,
    this.afterModelRegister,
  });
}
