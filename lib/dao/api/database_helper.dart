import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/context.dart';

import 'dao.dart';

abstract class DatabaseHelper {
  final DatabaseListener? listener;

  DatabaseHelper(this.listener);

  /// Type must use ModelType
  Future<void> initial({
    Map<Type, Model Function()> Function()? getModelMap,
    Map<Type, Dao> Function()? getDaoMap,
  }) async {
    // 打开数据库
    await open();
    await listener?.afterDatabaseOpen?.call();
    Map<Type, Model Function()>? modelMap = getModelMap?.call();
    if (null != modelMap) {
      modelMap.forEach((key, value) {
        NewModelCache.register(key, value);
      });
    }
    await listener?.afterModelRegister?.call();
    Map<Type, Dao>? daoMap = getDaoMap?.call();
    // 注册dao
    if (null != daoMap) {
      daoMap.forEach((key, value) {
        DaoCache.register(key, value);
      });
    }
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
