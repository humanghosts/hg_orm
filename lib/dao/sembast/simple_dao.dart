import 'dart:convert';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/export.dart' as api;
import 'package:sembast/sembast.dart';

import 'convertors.dart';
import 'database.dart';

/// 公共的规范与实现
class SembastSimpleDao<T extends SimpleModel> extends api.SimpleDao<T> {
  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  Database get dataBase => SembastDatabaseHelper.database;

  /// 数据库地址
  late String _storeName;

  SembastSimpleDao() : super(convertors: SembastConvertors.instance) {
    _storeName = T.toString();
    store = stringMapStoreFactory.store("simple");
  }

  @override
  SembastConvertors get convertors => super.convertors as SembastConvertors;

  @override
  Future<void> transaction(Future<void> Function(api.Transaction tx) action) async {
    return await dataBase.transaction((tx) async {
      await action(api.Transaction(tx));
    });
  }

  @override
  Future<void> withTransaction(api.Transaction? tx, Future<void> Function(api.Transaction tx) action) async {
    if (null == tx) {
      await transaction((tx) async {
        await action(tx);
      });
    } else {
      await action(tx);
    }
  }

  /// 保存，存在更新，不存在插入
  @override
  Future<void> save(T model, {api.Transaction? tx}) async {
    switch (model.state) {
      case States.insert:
        await _insert(model, tx: tx);
        break;
      case States.update:
        await _update(model, tx: tx);
        break;
      case States.delete:
        await _delete(model, tx: tx);
        break;
      case States.none:
      case States.query:
        break;
    }
  }

  Future<void> _insert(T model, {api.Transaction? tx}) async {
    await store
        .record(_storeName)
        .add(api.Transaction.getOr(tx, dataBase), await convertors.modelConvertor.getValue(model, tx: tx, isLogicDelete: true, isCache: true));
  }

  Future<void> _update(T model, {api.Transaction? tx}) async {
    /// 这里用put不用update的原因是：
    /// sembast的update是foreach map的update，如果以前有key，现在没有key，
    /// 无法清空数据，所以就直接替换了
    await store
        .record(_storeName)
        .put(api.Transaction.getOr(tx, dataBase), await convertors.modelConvertor.getValue(model, tx: tx, isLogicDelete: true, isCache: true));
  }

  Future<void> _delete(T model, {api.Transaction? tx}) async {
    await store.record(_storeName).delete(api.Transaction.getOr(tx, dataBase));
  }

  @override
  Future<void> remove(T model, {api.Transaction? tx}) async {
    model.state = States.delete;
    await save(model);
  }

  @override
  Future<void> update(String id, Map<String, Object?> value, {api.Transaction? tx}) async {
    await store.record(_storeName).update(api.Transaction.getOr(tx, dataBase), value);
  }

  @override
  Future<List<T>> find({api.Transaction? tx}) async {
    List<T> modelList = [];
    await withTransaction(tx, (tx) async {
      Object? value = await store.record(_storeName).get(tx.getTx());
      if (null == value) {
        return;
      }
      Map<String, Object?> map = json.decode(json.encode(value)) as Map<String, Object?>;
      T t = ConstructorCache.get(T);
      await convertors.modelConvertor.getModelByModel(t, map, tx: tx, isLogicDelete: true, isCache: true);
      t.state = States.query;
      modelList.add(t);
    });
    return modelList;
  }
}
