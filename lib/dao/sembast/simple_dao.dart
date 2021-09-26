import 'package:hg_entity/hg_entity.dart';
import 'package:hg_entity/status/status.dart';
import 'package:hg_orm/dao/api/export.dart' as hg;
import 'package:sembast/sembast.dart';

import 'convert.dart';
import 'database_helper.dart';

/// 公共的规范与实现
abstract class SimpleDao<T extends SimpleModel> implements hg.Dao<T> {
  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  late Database dataBase;

  /// 类型转换
  late final SembastConvert _convert;

  /// 存储库名称
  late final String _storeName;

  SimpleDao() {
    store = stringMapStoreFactory.store("simple");
    dataBase = SembastDatabaseHelper.database;
    _convert = SembastConvert();
  }

  /// 存储库名称
  String get storeName => _storeName;

  /// 保存，存在更新，不存在插入
  @override
  Future<void> save(T model, [Transaction? tx]) async {
    switch (model.status) {
      case DataStatus.insert:
        await _insert(model, tx);
        break;
      case DataStatus.update:
        await _update(model, tx);
        break;
      case DataStatus.delete:
        await _delete(model, tx);
        break;
      case DataStatus.none:
      case DataStatus.query:
        break;
    }
  }

  Future<void> _insert(T model, [Transaction? tx]) async {
    await store.record(_storeName).add(tx ?? dataBase, _convert.modelValue(model));
  }

  Future<void> _update(T model, [Transaction? tx]) async {
    await store.record(_storeName).update(tx ?? dataBase, _convert.modelValue(model));
  }

  Future<void> _delete(T model, [Transaction? tx]) async {
    await store.record(_storeName).delete(tx ?? dataBase);
  }

  @override
  Future<List<T>> find({hg.Filter? filter, List<hg.Sort>? sorts}) async {
    T? t = await store.record(_storeName).get(dataBase);
    if (null == t) {
      return [];
    }
    return [t];
  }

  @override
  Future<T?> findByID(String id) async {
    List<T> list = await find();
    if (list.isEmpty) {
      return null;
    }
    return list[0];
  }

  @override
  Future<int> count({hg.Filter? filter}) async {
    return await store.count(dataBase);
  }
}
