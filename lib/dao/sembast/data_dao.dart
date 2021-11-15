import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/cache.dart';
import 'package:hg_orm/dao/api/export.dart' as hg;
import 'package:hg_orm/dao/sembast/convertor.dart';
import 'package:hg_orm/dao/sembast/database_helper.dart';
import 'package:sembast/sembast.dart';

typedef FutureOrFunc = FutureOr<dynamic> Function(Transaction transaction);

abstract class DataDao<T extends DataModel> implements hg.Dao<T> {
  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  late Database dataBase;

  /// 实体例
  late final T _sampleModel;

  /// 逻辑删除
  late final bool _logicDelete;

  /// 类型转换
  late final SembastConvertor _convertor;

  /// 是否使用缓存
  late final bool _cache;

  DataDao({bool logicDelete = true, bool? cache}) {
    _logicDelete = logicDelete;
    _sampleModel = ConstructorCache.get(T) as T;
    store = stringMapStoreFactory.store(T.toString());
    dataBase = SembastDatabaseHelper.database;
    _convertor = SembastConvertor();
    _cache = cache ?? SembastDatabaseHelper.dataModelCache;
  }

  /// Dao处理的实体的样本，用于获取属性等字段
  T get sampleModel => _sampleModel;

  _log(T? model, String action, String message) {
    log("$action:[类型$T]${model == null ? "" : "[id:${model.id.value}]"}:$message");
  }

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
    String action = "新增";
    _log(model, action, "开始");
    model.createTime.value = DateTime.now();
    model.timestamp.value = DateTime.now();
    await store.record(model.id.value).add(tx ?? dataBase, _convertor.modelValue(model));
    _log(model, action, "存储成功");
    DataModelCache.put(model);
    _log(model, action, "缓存成功，结束");
  }

  Future<void> _update(T model, [Transaction? tx]) async {
    String action = "更新";
    _log(model, action, "开始");
    model.timestamp.value = DateTime.now();
    await store.record(model.id.value).update(tx ?? dataBase, _convertor.modelValue(model));
    _log(model, action, "存储成功");
    DataModelCache.put(model);
    _log(model, action, "缓存更新成功，结束");
  }

  Future<void> _delete(T model, [Transaction? tx]) async {
    String action;
    if (_logicDelete) {
      action = "逻辑删除";
      _log(model, action, "开始");
      model.isDelete.value = true;
      model.deleteTime.value = DateTime.now();
      await store.record(model.id.value).update(tx ?? dataBase, _convertor.modelValue(model));
      _log(model, action, "存储成功");
      DataModelCache.remove(model.id.value);
      _log(model, action, "缓存移除成功，结束");
      return;
    }
    action = "物理删除";
    await store.record(model.id.value).delete(tx ?? dataBase);
    _log(model, action, "存储成功");
    DataModelCache.remove(model.id.value);
    _log(model, action, "缓存移除成功，结束");
  }

  /// 保存，存在更新，不存在插入
  Future<List<T>> saveList(List<T> modelList, [Transaction? tx]) async {
    if (modelList.isEmpty) {
      return modelList;
    }
    FutureOr<dynamic> listSave(Transaction transaction) async {
      for (T model in modelList) {
        await save(model, transaction);
      }
    }

    if (null != tx) {
      await listSave(tx);
    } else {
      await dataBase.transaction(listSave);
    }
    return modelList;
  }

  /// 逻辑移除
  @override
  Future<void> remove(T model, [Transaction? tx]) async {
    model.state = States.delete;
    await save(model, tx);
  }

  /// 移除
  Future<void> removeList(List<T> modelList, {Transaction? tx}) async {
    if (modelList.isEmpty) {
      return;
    }
    FutureOr<dynamic> listRemove(Transaction transaction) async {
      for (T model in modelList) {
        await remove(model, tx);
      }
    }

    if (null != tx) {
      await listRemove(tx);
    } else {
      await dataBase.transaction(listRemove);
    }
  }

  @override
  Future<void> recover(T model, [Transaction? tx]) async {
    String action = "恢复";
    _log(model, action, "开始");
    if (model.isDelete.value == false) {
      _log(model, action, "未逻辑删除，无需恢复");
    }
    model.isDelete.value = false;
    model.deleteTime.value = null;
    await store.record(model.id.value).update(tx ?? dataBase, _convertor.modelValue(model));
    DataModelCache.put(model);
    _log(model, action, "缓存恢复成功，结束");
  }

  Future<void> recoverList(List<T> modelList, {Transaction? tx}) async {
    if (modelList.isEmpty) {
      return;
    }
    FutureOr<dynamic> listRecover(Transaction transaction) async {
      for (T model in modelList) {
        await recover(model, tx);
      }
    }

    if (null != tx) {
      await listRecover(tx);
    } else {
      await dataBase.transaction(listRecover);
    }
  }

  @override
  Future<void> recoverById(String id, [Transaction? tx]) async {
    String action = "恢复";
    List<RecordSnapshot> record = await store.find(dataBase,
        finder: Finder(
          filter: Filter.byKey(id),
        ));
    _log(null, action, "读取$id成功");
    List<T> modelList = await _merge(record);
    if (modelList.isEmpty) {
      _log(null, action, "未找到需要恢复的数据，结束");
      return;
    }
    _log(null, action, "翻译成功，结束");
    await recover(modelList[0]);
    return;
  }

  /// 获取逻辑删除条件
  hg.Filter? _getLogicFilter(hg.Filter? filter) {
    if (_logicDelete) {
      hg.Filter logicFindFilter;
      if (null == filter) {
        logicFindFilter = hg.SingleFilter.notEquals(field: sampleModel.isDelete.name, value: true);
      } else {
        logicFindFilter = hg.GroupFilter.and([
          hg.SingleFilter.notEquals(field: sampleModel.isDelete.name, value: true),
          filter,
        ]);
      }
      return logicFindFilter;
    } else {
      return filter;
    }
  }

  /// 查询全部
  Future<List<T>> findAll([bool? cache]) async {
    return await find(cache: cache);
  }

  /// 通过ID查询
  @override
  Future<T?> findByID(String id, [bool? cache]) async {
    List<T> newModelList = await find(filter: hg.SingleFilter.equals(field: sampleModel.id.name, value: id));
    if (newModelList.isEmpty) {
      return null;
    }
    return newModelList[0];
  }

  /// 通过ID列表查询
  Future<List<T>> findByIDList(List idList, [bool? cache]) async {
    return await find(filter: hg.SingleFilter.inList(field: sampleModel.id.name, value: idList));
  }

  /// 自定义查询
  @override
  Future<List<T>> find({
    hg.Filter? filter,
    List<hg.Sort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? cache,
  }) async {
    String action = "查询";
    _log(null, action, "开始");
    hg.Filter? logicFilter = _getLogicFilter(filter);
    Finder finder = Finder(
      filter: logicFilter == null ? null : _convertor.filterConvert(logicFilter),
      sortOrders: sorts?.map((sort) => _convertor.sortConvert(sort)).toList(),
      limit: limit,
      offset: offset,
      start: start,
      end: end,
    );
    List<RecordSnapshot> record = await store.find(dataBase, finder: finder);
    _log(null, action, "读取成功");
    List<T> modeList = await _merge(record);
    _log(null, action, "翻译成功，结束");
    return modeList;
  }

  /// 用原生的方法查询
  Future<List<T>> nativeFind({
    Filter? filter,
    List<SortOrder>? sortOrders,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? cache,
  }) async {
    String action = "查询";
    _log(null, action, "开始");
    Filter filterWithoutDelete = null == filter
        ? Filter.notEquals(sampleModel.isDelete.name, true)
        : Filter.and([
            Filter.notEquals(sampleModel.isDelete.name, true),
            filter,
          ]);
    Finder finder = Finder(filter: filterWithoutDelete, sortOrders: sortOrders, limit: limit, offset: offset, start: start, end: end);
    List<RecordSnapshot> record = await store.find(dataBase, finder: finder);
    _log(null, action, "读取成功");
    List<T> modeList = await _merge(record);
    _log(null, action, "翻译成功，结束");
    return modeList;
  }

  /// 查询首个
  Future<T?> findFirst({
    hg.Filter? filter,
    List<hg.Sort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? cache,
  }) async {
    String action = "查询首个";
    _log(null, action, "开始");
    hg.Filter? logicFilter = _getLogicFilter(filter);
    Finder finder = Finder(
      filter: logicFilter == null ? null : _convertor.filterConvert(logicFilter),
      sortOrders: sorts?.map((sort) => _convertor.sortConvert(sort)).toList(),
      limit: limit,
      offset: offset,
      start: start,
      end: end,
    );
    RecordSnapshot? record = await store.findFirst(dataBase, finder: finder);
    _log(null, action, "查询成功");
    if (null == record) {
      return null;
    }
    List<T> newModelList = await _merge([record]);
    _log(null, action, "翻译成功，结束");
    return newModelList[0];
  }

  /// 计数
  @override
  Future<int> count({hg.Filter? filter}) async {
    String action = "计数";
    _log(null, action, "开始");
    hg.Filter? logicFilter = _getLogicFilter(filter);
    int num = await store.count(dataBase, filter: logicFilter == null ? null : _convertor.filterConvert(logicFilter));
    _log(null, action, "读取成功，结束");
    return num;
  }

  /// 查询
  Future<List<T>> _merge(List<RecordSnapshot> recordList, [bool? cache]) async {
    String action = "翻译";
    // 为空 返回空数组
    if (recordList.isEmpty) return <T>[];
    bool useCache = cache ?? _cache;
    // 最终的返回结果
    List<T> resultList = [];
    // 讲recordList转换位mapList，便于对数据进行修改
    List<Map<String, Object?>> mapList = [];
    // 遍历查询出的数据，有缓存使用缓存中的数据
    for (RecordSnapshot record in recordList) {
      // 单个数据转换为map
      Map<String, Object?> map = json.decode(json.encode(record.value)) as Map<String, Object?>;
      // 不使用缓存，直接返回
      if (!useCache) {
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
        T newModel = ConstructorCache.get(T) as T;
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
      _log(cacheModel, action, "$cacheModel从${cacheNode.cacheType}缓存中读取");
    }
    if (mapList.isNotEmpty) {
      // 填充数据
      List<T> fillList = await _convert(mapList, useCache);
      _log(null, action, "填充完成");
      // 收集填充后的数据
      resultList.addAll(fillList);
      _log(null, action, "修改model状态");
    }
    for (T model in resultList) {
      model.state = States.query;
    }
    _log(null, action, "结束");
    return resultList;
  }

  /// 填充数据
  Future<List<T>> _convert(List<Map<String, Object?>> mapList, [bool? cache]) async {
    String action = "填充";
    bool useCache = cache ?? _cache;
    List<T> modelList = [];
    for (var map in mapList) {
      String id = map[sampleModel.id.name] as String;
      // 在merge中，fill之前，已经将mode放入undone缓存中，这里直接取即可
      DataModelCacheNode<T> cacheNode = DataModelCache.get(id)!;
      await _convertor.setModel(cacheNode.model, map) as T;
      // 转换完成的model缓存升级
      if (useCache) DataModelCache.levelUp(id);
      // 放入数据收集中
      modelList.add(cacheNode.model);
    }
    _log(null, action, "类型转换完成");
    // 填充后操作
    _log(null, action, "填充后操作执行完成，结束");
    return modelList;
  }
}
