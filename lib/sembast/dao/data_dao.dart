import 'dart:async';
import 'dart:convert';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/api/export.dart' as api;
import 'package:sembast/sembast.dart';

import '../../sembast/dao/convertors.dart';
import '../context/database.dart';

class SembastDataDao<T extends DataModel> extends api.DataDao<T> {
  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  Database get dataBase => (api.DatabaseHelper.database as SembastDatabase).database;

  @override
  SembastConvertors get convertors => super.convertors as SembastConvertors;

  SembastDataDao({bool? isLogicDelete})
      : super(
          isLogicDelete: isLogicDelete,
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
      await transaction(action);
    } else {
      await action(tx);
    }
  }

  /// 保存
  /// 保存前后不会修改model的状态
  /// 如果想要改变model状态，手动或者重新查询
  @override
  Future<void> save(T model, {api.Transaction? tx, bool? isLogicDelete}) async {
    States oldStates = model.state;
    model.createTime.value ??= DateTime.now();
    model.timestamp.value = DateTime.now();
    await store
        .record(model.id.value)
        .put(api.Transaction.getOr(tx, dataBase), await convertors.modelConvertor.getValue(model, tx: tx, isLogicDelete: isLogicDelete));
    api.DataModelCache.put(model);
    if (oldStates == States.none) {
      model.state = States.insert;
    } else {
      model.state = States.update;
    }
  }

  /// 保存，存在更新，不存在插入
  @override
  Future<void> saveList(List<T> modelList, {api.Transaction? tx, bool? isLogicDelete}) async {
    if (modelList.isEmpty) return;
    await withTransaction(tx, (tx) async {
      for (T model in modelList) {
        await save(model, tx: tx, isLogicDelete: isLogicDelete);
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
    api.DataModelCache.remove(id);
  }

  @override
  Future<void> updateList(List<String> idList, Map<String, Object?> value, {api.Transaction? tx}) async {
    if (idList.isEmpty) return;
    await withTransaction(tx, (tx) async {
      for (String id in idList) {
        await update(id, value, tx: tx);
      }
    });
  }

  /// 更新，同时移除缓存
  @override
  Future<void> updateWhere(api.Filter filter, Map<String, Object?> value, {api.Transaction? tx}) async {
    List<String> removeIdList = [];
    await withTransaction(tx, (tx) async {
      List<String> idList = await store.findKeys(tx.getTx(), finder: Finder(filter: await convertors.filterConvertor.to(filter))) as List<String>;
      if (idList.isEmpty) return;
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
      api.DataModelCache.remove(id);
    }
  }

  /// 逻辑移除
  @override
  Future<void> remove(T model, {api.Transaction? tx, bool? isLogicDelete}) async {
    bool logicDelete = isLogicDelete ?? this.isLogicDelete;
    if (logicDelete) {
      model.isDelete.value = true;
      model.deleteTime.value = DateTime.now();
      await store
          .record(model.id.value)
          .update(api.Transaction.getOr(tx, dataBase), await convertors.modelConvertor.getValue(model, tx: tx, isLogicDelete: logicDelete));
      api.DataModelCache.remove(model.id.value);
      return;
    }
    await store.record(model.id.value).delete(api.Transaction.getOr(tx, dataBase));
    api.DataModelCache.remove(model.id.value);
    model.state = States.delete;
  }

  /// 移除
  @override
  Future<void> removeList(List<T> modelList, {api.Transaction? tx, bool? isLogicDelete}) async {
    if (modelList.isEmpty) return;
    await withTransaction(tx, (tx) async {
      for (T model in modelList) {
        await remove(model, tx: tx, isLogicDelete: isLogicDelete);
      }
    });
  }

  /// 移除，同时移除缓存
  @override
  Future<void> removeWhere(api.Filter filter, {api.Transaction? tx, bool? isLogicDelete}) async {
    List<String> removeIdList = [];
    await withTransaction(tx, (tx) async {
      bool logicDelete = isLogicDelete ?? this.isLogicDelete;
      // 删除前留下ID，便于后面删除缓存
      List<String> idList = await store.findKeys(tx.getTx(), finder: Finder(filter: await convertors.filterConvertor.to(filter))) as List<String>;
      if (idList.isEmpty) return;
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
      api.DataModelCache.remove(id);
    }
  }

  /// 恢复，同时修改状态为query
  @override
  Future<void> recover(T model, {api.Transaction? tx}) async {
    if (model.isDelete.value == false) return;
    model.isDelete.value = false;
    model.deleteTime.value = null;
    // 直接替换数据
    await store.record(model.id.value).put(
          api.Transaction.getOr(tx, dataBase),
          await convertors.modelConvertor.getValue(
            model,
            tx: tx,
            isLogicDelete: false,
          ),
        );
    model.state = States.query;
    api.DataModelCache.put(model);
  }

  @override
  Future<void> recoverList(List<T> modelList, {api.Transaction? tx}) async {
    if (modelList.isEmpty) return;
    await withTransaction(tx, (tx) async {
      for (T model in modelList) {
        await recover(model, tx: tx);
      }
    });
  }

  /// 恢复，同时移除缓存
  @override
  Future<void> recoverWhere(api.Filter filter, {api.Transaction? tx}) async {
    List<String> recoverIdList = [];
    await withTransaction(tx, (tx) async {
      // 删除前留下ID，便于后面删除缓存
      List<String> idList = await store.findKeys(tx.getTx(), finder: Finder(filter: await convertors.filterConvertor.to(filter))) as List<String>;
      if (idList.isEmpty) return;
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
      api.DataModelCache.remove(id);
    }
  }

  /// 通过ID查询
  @override
  Future<T?> findByID(String id, {api.Transaction? tx, bool? isLogicDelete}) async {
    List<T> newModelList = await find(
      tx: tx,
      filter: api.SingleFilter.equals(field: sampleModel.id.name, value: id),
      isLogicDelete: isLogicDelete,
    );
    if (newModelList.isEmpty) return null;
    return newModelList[0];
  }

  /// 通过ID列表查询
  @override
  Future<List<T>> findByIDList(List<String> idList, {api.Transaction? tx, bool? isLogicDelete}) async {
    List<T> modelList = await find(
      tx: tx,
      filter: api.SingleFilter.inList(field: sampleModel.id.name, value: idList),
      isLogicDelete: isLogicDelete,
    );
    if (modelList.isEmpty) return [];
    // 下面的步骤是为了保证modelList的顺序与idList的顺序一致，毕竟是list，不是set
    Map<String, T> idMap = {};
    for (T model in modelList) {
      idMap[model.id.value] = model;
    }
    List<T> modelListOrder = [];
    for (String id in idList) {
      if (!idMap.containsKey(id)) continue;
      modelListOrder.add(idMap[id]!);
    }
    return modelListOrder;
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
    List<T> modelList = [];
    await withTransaction(tx, (tx) async {
      List<RecordSnapshot> record = await store.find(tx.getTx(), finder: finder);
      modelList = await _merge(record, tx, logicDelete);
    });
    return modelList;
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
    T? data;
    await withTransaction(tx, (tx) async {
      RecordSnapshot? record = await store.findFirst(tx.getTx(), finder: finder);
      if (null != record) {
        List<T> newModelList = await _merge([record], tx, logicDelete);
        data = newModelList[0];
      }
    });
    return data;
  }

  /// 计数
  @override
  Future<int> count({api.Filter? filter, api.Transaction? tx, bool? isLogicDelete}) async {
    api.Filter? logicFilter = _getLogicFilter(filter, isLogicDelete ?? this.isLogicDelete);
    int num = await store.count(api.Transaction.getOr(tx, dataBase), filter: await convertors.filterConvertor.to(logicFilter));
    return num;
  }

  /// 查询
  Future<List<T>> _merge(List<RecordSnapshot> recordList, api.Transaction? tx, bool isLogicDelete) async {
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
      // 获取dataModel的主键
      String id = map[sampleModel.id.name] as String;
      // 查询缓存是否存在当前dataModel
      api.DataModelCacheNode<T>? cacheNode = api.DataModelCache.get(id);
      // 缓存不存在，将转换后的结果收集
      if (cacheNode == null) {
        mapList.add(map);
        // 获取一个新的对象
        T newModel = ConstructorCache.get(T);
        // 修改对象的id
        newModel.id.value = id;
        // 未转换的Model先放入undone缓存
        api.DataModelCache.put(newModel, api.DataModelCacheType.undone);
        continue;
      }
      // 缓存存在
      // 不需要关心缓存是几级缓存，直接赋值即可，多级缓存只是为了解决循环依赖
      T cacheModel = cacheNode.model;
      resultList.add(cacheModel);
    }
    if (mapList.isNotEmpty) {
      // 填充数据
      List<T> fillList = await _convert(mapList, tx, isLogicDelete);
      // 收集填充后的数据
      resultList.addAll(fillList);
    }
    for (T model in resultList) {
      model.state = States.query;
    }
    return resultList;
  }

  /// 填充数据
  Future<List<T>> _convert(List<Map<String, Object?>> mapList, api.Transaction? tx, bool isLogicDelete) async {
    List<T> modelList = [];
    await withTransaction(tx, (tx) async {
      for (var map in mapList) {
        String id = map[sampleModel.id.name] as String;
        // 在merge中，fill之前，已经将mode放入undone缓存中，这里直接取即可
        api.DataModelCacheNode<T> cacheNode = api.DataModelCache.get(id)!;
        await convertors.modelConvertor.getModelByModel(cacheNode.model, map, tx: tx, isLogicDelete: isLogicDelete);
        // 转换完成的model缓存升级
        api.DataModelCache.levelUp(id);
        // 放入数据收集中
        modelList.add(cacheNode.model);
      }
    });
    // 填充后操作
    return modelList;
  }
}
