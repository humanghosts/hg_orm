import 'dart:async';
import 'dart:convert';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/export.dart';
import 'package:hg_orm/dao/api/export.dart';
import 'package:sembast/sembast.dart';

import 'convertor.dart';
import 'database_helper.dart';

class SembastDataDao<T extends DataModel> extends DataDao<T> {
  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  late Database dataBase;

  SembastDataDao({bool? isLogicDelete, bool? isCache})
      : super(
          isLogicDelete: isLogicDelete,
          isCache: isCache,
          convertor: const SembastConvertor(),
        ) {
    store = stringMapStoreFactory.store(T.toString());
    dataBase = SembastDatabaseHelper.database;
  }

  /// 保存，存在更新，不存在插入
  @override
  Future<void> save(T model, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    switch (model.state) {
      case States.insert:
        await _insert(model, tx);
        break;
      case States.update:
        await _update(model, tx);
        break;
      case States.delete:
        await _delete(model, isLogicDelete, tx);
        break;
      case States.none:
      case States.query:
        break;
    }
  }

  Future<void> _insert(T model, [Transaction? tx]) async {
    model.createTime.value = DateTime.now();
    model.timestamp.value = DateTime.now();
    await store.record(model.id.value).add(tx ?? dataBase, convertor.modelConvert(model, isLogicDelete, isCache));
    DataModelCache.put(model);
  }

  Future<void> _update(T model, [Transaction? tx]) async {
    model.timestamp.value = DateTime.now();

    /// 这里用put不用update的原因是：
    /// sembast的update是foreach map的update，如果以前有key，现在没有key，
    /// 无法清空数据，所以就直接替换了
    await store.record(model.id.value).put(tx ?? dataBase, convertor.modelConvert(model, isLogicDelete, isCache));
    DataModelCache.put(model);
  }

  Future<void> _delete(T model, bool? isLogicDelete, [Transaction? tx]) async {
    bool logicDelete = isLogicDelete ?? this.isLogicDelete;
    if (logicDelete) {
      model.isDelete.value = true;
      model.deleteTime.value = DateTime.now();
      await store.record(model.id.value).update(tx ?? dataBase, convertor.modelConvert(model, logicDelete, isCache));
      DataModelCache.remove(model.id.value);
      return;
    }
    await store.record(model.id.value).delete(tx ?? dataBase);
    DataModelCache.remove(model.id.value);
  }

  /// 保存，存在更新，不存在插入
  @override
  Future<void> saveList(List<T> modelList, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (modelList.isEmpty) {
      return;
    }
    FutureOr<dynamic> listSave(Transaction transaction) async {
      for (T model in modelList) {
        await save(model, tx: transaction, isLogicDelete: isLogicDelete, isCache: isCache);
      }
    }

    if (null != tx) {
      await listSave(tx);
    } else {
      await dataBase.transaction(listSave);
    }
  }

  /// 逻辑移除
  @override
  Future<void> remove(T model, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    model.state = States.delete;
    await save(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
  }

  /// 移除
  @override
  Future<void> removeList(List<T> modelList, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (modelList.isEmpty) {
      return;
    }
    FutureOr<dynamic> listRemove(Transaction transaction) async {
      for (T model in modelList) {
        await remove(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      }
    }

    if (null != tx) {
      await listRemove(tx);
    } else {
      await dataBase.transaction(listRemove);
    }
  }

  @override
  Future<void> recover(T model, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (model.isDelete.value == false) {
      return;
    }
    model.isDelete.value = false;
    model.deleteTime.value = null;
    await store.record(model.id.value).update(
        tx ?? dataBase,
        convertor.modelConvert(
          model,
          isLogicDelete ?? this.isLogicDelete,
          isCache ?? this.isCache,
        ));
    DataModelCache.put(model);
  }

  @override
  Future<void> recoverList(List<T> modelList, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (modelList.isEmpty) {
      return;
    }
    FutureOr<dynamic> listRecover(Transaction transaction) async {
      for (T model in modelList) {
        await recover(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      }
    }

    if (null != tx) {
      await listRecover(tx);
    } else {
      await dataBase.transaction(listRecover);
    }
  }

  @override
  Future<void> recoverById(String id, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    T? model = await findByID(id, isLogicDelete: isLogicDelete, isCache: isCache);
    if (null == model) {
      return;
    }
    await recover(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
  }

  /// 查询全部
  @override
  Future<List<T>> findAll({bool? isLogicDelete, bool? isCache}) async {
    return await find(isLogicDelete: isLogicDelete, isCache: isCache);
  }

  /// 通过ID查询
  @override
  Future<T?> findByID(String id, {bool? isLogicDelete, bool? isCache}) async {
    List<T> newModelList = await find(
      filter: SingleHgFilter.equals(field: sampleModel.id.name, value: id),
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
  Future<List<T>> findByIDList(List idList, {bool? isLogicDelete, bool? isCache}) async {
    return await find(
      filter: SingleHgFilter.inList(field: sampleModel.id.name, value: idList),
      isLogicDelete: isLogicDelete,
      isCache: isCache,
    );
  }

  /// 自定义查询
  @override
  Future<List<T>> find({
    HgFilter? filter,
    List<HgSort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? isCache,
    bool? isLogicDelete,
  }) async {
    bool logicDelete = isLogicDelete ?? this.isLogicDelete;
    HgFilter? logicFilter = _getLogicHgFilter(filter, logicDelete);
    Finder finder = Finder(
      filter: logicFilter == null ? null : (convertor as SembastConvertor).filterConvert(logicFilter),
      sortOrders: sorts?.map((sort) => (convertor as SembastConvertor).sortConvert(sort)).toList(),
      limit: limit,
      offset: offset,
      start: start,
      end: end,
    );
    List<RecordSnapshot> record = await store.find(dataBase, finder: finder);
    List<T> modeList = await _merge(record, logicDelete, isCache ?? this.isCache);
    return modeList;
  }

  /// 获取逻辑删除条件
  HgFilter? _getLogicHgFilter(HgFilter? filter, bool isLogicDelete) {
    if (!isLogicDelete) {
      return filter;
    }
    HgFilter logicFindFilter;
    if (null == filter) {
      logicFindFilter = SingleHgFilter.notEquals(field: sampleModel.isDelete.name, value: true);
    } else {
      logicFindFilter = GroupHgFilter.and([
        SingleHgFilter.notEquals(field: sampleModel.isDelete.name, value: true),
        filter,
      ]);
    }
    return logicFindFilter;
  }

  /// 用原生的方法查询
  Future<List<T>> nativeFind({
    Filter? filter,
    List<SortOrder>? sortOrders,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? isCache,
    bool? isLogicDelete,
  }) async {
    bool logicDelete = isLogicDelete ?? this.isLogicDelete;
    Filter? filterWithoutDelete = _getLogicFilter(filter, logicDelete);
    Finder finder = Finder(filter: filterWithoutDelete, sortOrders: sortOrders, limit: limit, offset: offset, start: start, end: end);
    List<RecordSnapshot> record = await store.find(dataBase, finder: finder);
    List<T> modeList = await _merge(record, logicDelete, isCache ?? this.isCache);
    return modeList;
  }

  /// 获取逻辑删除条件
  Filter? _getLogicFilter(Filter? filter, bool isLogicDelete) {
    if (!isLogicDelete) {
      return filter;
    }
    Filter logicFindFilter;
    if (null == filter) {
      logicFindFilter = Filter.notEquals(sampleModel.isDelete.name, true);
    } else {
      logicFindFilter = Filter.and([
        Filter.notEquals(sampleModel.isDelete.name, true),
        filter,
      ]);
    }
    return logicFindFilter;
  }

  /// 查询首个
  @override
  Future<T?> findFirst({
    HgFilter? filter,
    List<HgSort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? isLogicDelete,
    bool? isCache,
  }) async {
    bool logicDelete = isLogicDelete ?? this.isLogicDelete;
    HgFilter? logicFilter = _getLogicHgFilter(filter, logicDelete);
    Finder finder = Finder(
      filter: logicFilter == null ? null : (convertor as SembastConvertor).filterConvert(logicFilter),
      sortOrders: sorts?.map((sort) => (convertor as SembastConvertor).sortConvert(sort)).toList(),
      limit: limit,
      offset: offset,
      start: start,
      end: end,
    );
    RecordSnapshot? record = await store.findFirst(dataBase, finder: finder);
    if (null == record) {
      return null;
    }
    List<T> newModelList = await _merge([record], logicDelete, isCache ?? this.isCache);
    return newModelList[0];
  }

  /// 计数
  @override
  Future<int> count({HgFilter? filter, bool? isLogicDelete, bool? isCache}) async {
    HgFilter? logicFilter = _getLogicHgFilter(filter, isLogicDelete ?? this.isLogicDelete);
    int num = await store.count(dataBase, filter: logicFilter == null ? null : (convertor as SembastConvertor).filterConvert(logicFilter));
    return num;
  }

  /// 查询
  Future<List<T>> _merge(List<RecordSnapshot> recordList, bool isLogicDelete, bool isCache) async {
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
      List<T> fillList = await _convert(mapList, isLogicDelete, isCache);
      // 收集填充后的数据
      resultList.addAll(fillList);
    }
    for (T model in resultList) {
      model.state = States.query;
    }
    return resultList;
  }

  /// 填充数据
  Future<List<T>> _convert(List<Map<String, Object?>> mapList, bool isLogicDelete, bool isCache) async {
    List<T> modelList = [];
    for (var map in mapList) {
      String id = map[sampleModel.id.name] as String;
      // 在merge中，fill之前，已经将mode放入undone缓存中，这里直接取即可
      DataModelCacheNode<T> cacheNode = DataModelCache.get(id)!;
      await convertor.convertToModel(cacheNode.model, map, isLogicDelete, isCache);
      // 转换完成的model缓存升级
      if (isCache) DataModelCache.levelUp(id);
      // 放入数据收集中
      modelList.add(cacheNode.model);
    }
    // 填充后操作
    return modelList;
  }
}
