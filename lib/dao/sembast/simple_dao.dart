import 'dart:convert';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/export.dart' as hg;
import 'package:sembast/sembast.dart';

import 'convertor.dart';
import 'database_helper.dart';

/// 公共的规范与实现
abstract class SimpleDao<T extends SimpleModel> implements hg.Dao<T> {
  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  late Database dataBase;

  /// 类型转换
  late final SembastConvertor _convert;

  /// 存储库名称
  late final String _storeName;

  /// 实体例
  late final T _sampleModel;

  SimpleDao() {
    _storeName = T.toString();
    store = stringMapStoreFactory.store("simple");
    dataBase = SembastDatabaseHelper.database;
    _convert = SembastConvertor();
    _sampleModel = ConstructorCache.get(T) as T;
  }

  /// Dao处理的实体的样本，用于获取属性等字段
  T get sampleModel => _sampleModel;

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
    await store.record(_storeName).add(tx ?? dataBase, _convert.modelValue(model));
  }

  Future<void> _update(T model, [Transaction? tx]) async {
    await store.record(_storeName).update(tx ?? dataBase, _convert.modelValue(model));
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
  Future<List<T>> find({hg.Filter? filter, List<hg.Sort>? sorts}) async {
    Object? value = await store.record(_storeName).get(dataBase);
    if (null == value) {
      return [];
    }
    Map<String, Object?> map = json.decode(json.encode(value)) as Map<String, Object?>;
    T t = ConstructorCache.get(T);
    await _convert.setModel(t, map);
    t.state = States.query;
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

  @override
  Future<void> recover(T model) async {}

  @override
  Future<void> recoverById(String id) async {}
}
