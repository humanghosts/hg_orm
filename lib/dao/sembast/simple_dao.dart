import 'dart:convert';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/export.dart';
import 'package:sembast/sembast.dart';

import 'convertor.dart';
import 'database_helper.dart';

/// 公共的规范与实现
class SembastSimpleDao<T extends SimpleModel> extends SimpleDao<T> {
  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  late Database dataBase;

  /// 数据库地址
  late String _storeName;

  SembastSimpleDao() : super(convertor: const SembastConvertor()) {
    _storeName = T.toString();
    store = stringMapStoreFactory.store("simple");
    dataBase = SembastDatabaseHelper.database;
  }

  @override
  SembastConvertor get convertor => super.convertor as SembastConvertor;

  /// 保存，存在更新，不存在插入
  @override
  Future<void> save(T model, [Transaction? tx]) async {
    switch (model.state) {
      case States.insert:
        await _insert(model, tx);
        break;
      case States.update:
        await _update(model, tx);
        break;
      case States.delete:
        await _delete(model, tx);
        break;
      case States.none:
      case States.query:
        break;
    }
  }

  Future<void> _insert(T model, [Transaction? tx]) async {
    await store.record(_storeName).add(tx ?? dataBase, convertor.modelConvert(model));
  }

  Future<void> _update(T model, [Transaction? tx]) async {
    /// 这里用put不用update的原因是：
    /// sembast的update是foreach map的update，如果以前有key，现在没有key，
    /// 无法清空数据，所以就直接替换了
    await store.record(_storeName).put(tx ?? dataBase, convertor.modelConvert(model));
  }

  Future<void> _delete(T model, [Transaction? tx]) async {
    await store.record(_storeName).delete(tx ?? dataBase);
  }

  @override
  Future<void> remove(T model) async {
    model.state = States.delete;
    await save(model);
  }

  @override
  Future<List<T>> find() async {
    Object? value = await store.record(_storeName).get(dataBase);
    if (null == value) {
      return [];
    }
    Map<String, Object?> map = json.decode(json.encode(value)) as Map<String, Object?>;
    T t = ConstructorCache.get(T);
    await convertor.convertToModel(t, map);
    t.state = States.query;
    return [t];
  }
}
