import 'dart:async';
import 'dart:convert';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/export.dart';
import 'package:hg_orm/dao/api/export.dart' as api;
import 'package:sembast/sembast.dart';

import 'convertors.dart';
import 'database.dart';

class SembastDataDao<T extends DataModel> extends api.DataDao<T> {
  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  Database get dataBase => SembastDatabaseHelper.database;

  @override
  SembastConvertors get convertors => super.convertors as SembastConvertors;

  SembastDataDao({bool? isLogicDelete, bool? isCache})
      : super(
          isLogicDelete: isLogicDelete,
          isCache: isCache,
          convertors: SembastConvertors.instance,
        ) {
    store = stringMapStoreFactory.store(T.toString());
  }

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

  /// 保存
  /// 保存前后不会修改model的状态
  /// 如果想要改变model状态，手动或者重新查询
  @override
  Future<void> save(T model, {api.Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    switch (model.state) {
      case States.insert:
        await _insert(model, tx: tx);
        break;
      case States.update:
        await _update(model, tx: tx);
        break;
      case States.delete:
        await _delete(model, isLogicDelete: isLogicDelete, tx: tx);
        break;
      case States.none:
      case States.query:
        break;
    }
  }

  Future<void> _insert(T model, {api.Transaction? tx}) async {
    model.createTime.value = DateTime.now();
    model.timestamp.value = DateTime.now();
    await store
        .record(model.id.value)
        .add(api.Transaction.getOr(tx, dataBase), await convertors.modelConvertor.getValue(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache));
    DataModelCache.put(model);
  }

  Future<void> _update(T model, {api.Transaction? tx}) async {
    model.timestamp.value = DateTime.now();
    await store
        .record(model.id.value)
        .put(api.Transaction.getOr(tx, dataBase), await convertors.modelConvertor.getValue(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache));
    DataModelCache.put(model);
  }

  Future<void> _delete(T model, {api.Transaction? tx, bool? isLogicDelete}) async {
    bool logicDelete = isLogicDelete ?? this.isLogicDelete;
    if (logicDelete) {
      model.isDelete.value = true;
      model.deleteTime.value = DateTime.now();
      await store
          .record(model.id.value)
          .update(api.Transaction.getOr(tx, dataBase), await convertors.modelConvertor.getValue(model, tx: tx, isLogicDelete: logicDelete, isCache: isCache));
      DataModelCache.remove(model.id.value);
      return;
    }
    await store.record(model.id.value).delete(api.Transaction.getOr(tx, dataBase));
    DataModelCache.remove(model.id.value);
  }

  /// 保存，存在更新，不存在插入
  @override
  Future<void> saveList(List<T> modelList, {api.Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (modelList.isEmpty) {
      return;
    }
    await withTransaction(tx, (tx) async {
      for (T model in modelList) {
        await save(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      }
    });
  }

  @override
  Future<void> update(String id, Map<String, Object?> value, {api.Transaction? tx}) async {
    await store.record(id).update(
      api.Transaction.getOr(tx, dataBase),
      {
        ...value,
        sampleModel.timestamp.name: convertors.attributeConvertor.datetime.getValue(DateTime.now()),
      },
    );
    DataModelCache.remove(id);
  }

  @override
  Future<void> updateList(List<String> idList, Map<String, Object?> value, {api.Transaction? tx}) async {
    if (idList.isEmpty) {
      return;
    }
    await withTransaction(tx, (tx) async {
      for (String id in idList) {
        await update(id, value, tx: tx);
      }
    });
  }

  /// 更新，同时移除缓存
  @override
  Future<void> updateWhere(api.Filter filter, Map<String, Object?> value, {api.Transaction? tx}) async {
    List removeIdList = [];
    await withTransaction(tx, (tx) async {
      List idList = await store.findKeys(tx.getTx(), finder: Finder(filter: await convertors.filterConvertor.to(filter)));
      if (idList.isEmpty) {
        return;
      }
      // 换成id的过滤条件，简化一下
      Finder finder = Finder(filter: Filter.inList(sampleModel.id.name, idList));
      // 更新
      await store.update(
        tx.getTx(),
        {
          ...value,
          sampleModel.timestamp.name: convertors.attributeConvertor.datetime.getValue(DateTime.now()),
        },
        finder: finder,
      );
      removeIdList = idList;
    });
    for (var id in removeIdList) {
      DataModelCache.remove(id as String);
    }
  }

  /// 逻辑移除
  @override
  Future<void> remove(T model, {api.Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    model.state = States.delete;
    await save(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
  }

  /// 移除
  @override
  Future<void> removeList(List<T> modelList, {api.Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (modelList.isEmpty) {
      return;
    }
    await withTransaction(tx, (tx) async {
      for (T model in modelList) {
        await remove(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      }
    });
  }

  /// 移除，同时移除缓存
  @override
  Future<void> removeWhere(api.Filter filter, {api.Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    List removeIdList = [];
    await withTransaction(tx, (tx) async {
      bool logicDelete = isLogicDelete ?? this.isLogicDelete;
      // 删除前留下ID，便于后面删除缓存
      List idList = await store.findKeys(tx.getTx(), finder: Finder(filter: await convertors.filterConvertor.to(filter)));
      if (idList.isEmpty) {
        return;
      }
      // 换成id的过滤条件，简化一下
      Finder finder = Finder(filter: Filter.inList(sampleModel.id.name, idList));
      if (logicDelete) {
        // 逻辑删除
        await store.update(
          tx.getTx(),
          {
            sampleModel.isDelete.name: true,
            sampleModel.deleteTime.name: convertors.attributeConvertor.datetime.getValue(DateTime.now()),
            sampleModel.timestamp.name: convertors.attributeConvertor.datetime.getValue(DateTime.now()),
          },
          finder: finder,
        );
      } else {
        // 永久删除
        await store.delete(tx.getTx(), finder: finder);
      }
      removeIdList = idList;
    });
    // 移除缓存
    for (var id in removeIdList) {
      DataModelCache.remove(id as String);
    }
  }

  /// 恢复，同时修改状态为query
  @override
  Future<void> recover(T model, {api.Transaction? tx, bool? isCache}) async {
    if (model.isDelete.value == false) {
      return;
    }
    model.isDelete.value = false;
    model.deleteTime.value = null;
    // 直接替换数据
    await store.record(model.id.value).put(
        api.Transaction.getOr(tx, dataBase), await convertors.modelConvertor.getValue(model, tx: tx, isLogicDelete: false, isCache: isCache ?? this.isCache));
    model.state = States.query;
    DataModelCache.put(model);
  }

  @override
  Future<void> recoverList(List<T> modelList, {api.Transaction? tx, bool? isCache}) async {
    if (modelList.isEmpty) {
      return;
    }
    await withTransaction(tx, (tx) async {
      for (T model in modelList) {
        await recover(model, tx: tx, isCache: isCache);
      }
    });
  }

  /// 恢复，同时移除缓存
  @override
  Future<void> recoverWhere(api.Filter filter, {api.Transaction? tx, bool? isCache}) async {
    List recoverIdList = [];
    await withTransaction(tx, (tx) async {
      // 删除前留下ID，便于后面删除缓存
      List idList = await store.findKeys(tx.getTx(), finder: Finder(filter: await convertors.filterConvertor.to(filter)));
      if (idList.isEmpty) {
        return;
      }
      // 换成id的过滤条件，简化一下
      Finder finder = Finder(filter: Filter.inList(sampleModel.id.name, idList));
      await store.update(
        tx.getTx(),
        {
          sampleModel.isDelete.name: false,
          sampleModel.deleteTime.name: null,
          sampleModel.timestamp.name: convertors.attributeConvertor.datetime.getValue(DateTime.now()),
        },
        finder: finder,
      );
      recoverIdList = idList;
    });
    // 按照同样的条件查询一下id，防止缓存和数据库不一致
    for (var id in recoverIdList) {
      DataModelCache.remove(id as String);
    }
  }

  /// 通过ID查询
  @override
  Future<T?> findByID(String id, {api.Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    List<T> newModelList = await find(
      tx: tx,
      filter: api.SingleFilter.equals(field: sampleModel.id.name, value: id),
      isLogicDelete: isLogicDelete,
      isCache: isCache,
    );
    if (newModelList.isEmpty) {
      return null;
    }
    return newModelList[0];
  }

  /// 通过ID列表查询
  @override
  Future<List<T>> findByIDList(List idList, {api.Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    return await find(
      tx: tx,
      filter: api.SingleFilter.inList(field: sampleModel.id.name, value: idList),
      isLogicDelete: isLogicDelete,
      isCache: isCache,
    );
  }

  /// 自定义查询
  @override
  Future<List<T>> find({
    api.Transaction? tx,
    api.Filter? filter,
    List<api.Sort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? isCache,
    bool? isLogicDelete,
  }) async {
    bool logicDelete = isLogicDelete ?? this.isLogicDelete;
    api.Filter? logicFilter = _getLogicFilter(filter, logicDelete);
    List<SortOrder> sortOrders = [];
    if (sorts != null) {
      for (var one in sorts) {
        SortOrder? oneSortOrder = await convertors.sortConvertor.to(one);
        if (null == oneSortOrder) continue;
        sortOrders.add(oneSortOrder);
      }
    }
    Finder finder = Finder(
      filter: await convertors.filterConvertor.to(logicFilter),
      sortOrders: sortOrders,
      limit: limit,
      offset: offset,
      start: start,
      end: end,
    );
    List<RecordSnapshot> record = await store.find(api.Transaction.getOr(tx, dataBase), finder: finder);
    List<T> modeList = await _merge(record, tx, logicDelete, isCache ?? this.isCache);
    return modeList;
  }

  /// 获取逻辑删除条件
  api.Filter? _getLogicFilter(api.Filter? filter, bool isLogicDelete) {
    if (!isLogicDelete) {
      return filter;
    }
    api.Filter logicFindFilter;
    if (null == filter) {
      logicFindFilter = api.SingleFilter.notEquals(field: sampleModel.isDelete.name, value: true);
    } else {
      logicFindFilter = api.GroupFilter.and([
        api.SingleFilter.notEquals(field: sampleModel.isDelete.name, value: true),
        filter,
      ]);
    }
    return logicFindFilter;
  }

  /// 查询首个
  @override
  Future<T?> findFirst({
    api.Transaction? tx,
    api.Filter? filter,
    List<api.Sort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? isLogicDelete,
    bool? isCache,
  }) async {
    bool logicDelete = isLogicDelete ?? this.isLogicDelete;
    api.Filter? logicFilter = _getLogicFilter(filter, logicDelete);
    List<SortOrder> sortOrders = [];
    if (sorts != null) {
      for (var one in sorts) {
        SortOrder? oneSortOrder = await convertors.sortConvertor.to(one);
        if (null == oneSortOrder) continue;
        sortOrders.add(oneSortOrder);
      }
    }
    Finder finder = Finder(
      filter: await convertors.filterConvertor.to(logicFilter),
      sortOrders: sortOrders,
      limit: limit,
      offset: offset,
      start: start,
      end: end,
    );
    RecordSnapshot? record = await store.findFirst(api.Transaction.getOr(tx, dataBase), finder: finder);
    if (null == record) {
      return null;
    }
    List<T> newModelList = await _merge([record], tx, logicDelete, isCache ?? this.isCache);
    return newModelList[0];
  }

  /// 计数
  @override
  Future<int> count({api.Filter? filter, api.Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    api.Filter? logicFilter = _getLogicFilter(filter, isLogicDelete ?? this.isLogicDelete);
    int num = await store.count(api.Transaction.getOr(tx, dataBase), filter: await convertors.filterConvertor.to(logicFilter));
    return num;
  }

  /// 查询
  Future<List<T>> _merge(List<RecordSnapshot> recordList, api.Transaction? tx, bool isLogicDelete, bool isCache) async {
    // 为空 返回空数组
    if (recordList.isEmpty) return <T>[];
    // 最终的返回结果
    List<T> resultList = [];
    // 讲recordList转换位mapList，便于对数据进行修改
    List<Map<String, Object?>> mapList = [];
    // 遍历查询出的数据，有缓存使用缓存中的数据
    for (RecordSnapshot record in recordList) {
      // 单个数据转换为map
      Map<String, Object?> map = json.decode(json.encode(record.value)) as Map<String, Object?>;
      // 不使用缓存，直接返回
      if (!isCache) {
        mapList.add(map);
        continue;
      }
      // 获取dataModel的主键
      String id = map[sampleModel.id.name] as String;
      // 查询缓存是否存在当前dataModel
      DataModelCacheNode<T>? cacheNode = DataModelCache.get(id);
      // 缓存不存在，将转换后的结果收集
      if (cacheNode == null) {
        mapList.add(map);
        // 获取一个新的对象
        T newModel = ConstructorCache.get(T);
        // 修改对象的id
        newModel.id.value = id;
        // 未转换的Model先放入undone缓存
        DataModelCache.put(newModel, DataModelCacheType.undone);
        continue;
      }
      // 缓存存在
      // 不需要关心缓存是几级缓存，直接赋值即可，多级缓存只是为了解决循环依赖
      T cacheModel = cacheNode.model;
      resultList.add(cacheModel);
    }
    if (mapList.isNotEmpty) {
      // 填充数据
      List<T> fillList = await _convert(mapList, tx, isLogicDelete, isCache);
      // 收集填充后的数据
      resultList.addAll(fillList);
    }
    for (T model in resultList) {
      model.state = States.query;
    }
    return resultList;
  }

  /// 填充数据
  Future<List<T>> _convert(List<Map<String, Object?>> mapList, api.Transaction? tx, bool isLogicDelete, bool isCache) async {
    List<T> modelList = [];
    for (var map in mapList) {
      String id = map[sampleModel.id.name] as String;
      // 在merge中，fill之前，已经将mode放入undone缓存中，这里直接取即可
      DataModelCacheNode<T> cacheNode = DataModelCache.get(id)!;
      await convertors.modelConvertor.getModelByModel(cacheNode.model, map, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      // 转换完成的model缓存升级
      if (isCache) DataModelCache.levelUp(id);
      // 放入数据收集中
      modelList.add(cacheNode.model);
    }
    // 填充后操作
    return modelList;
  }
}
