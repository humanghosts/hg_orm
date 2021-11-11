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

  /// 逻辑移除
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
    if (mapList.isEmpty) {
      _log(null, action, "无需填充，结束");
      return resultList;
    }
    // 填充数据
    List<T> fillList = await _convert(mapList, useCache);
    _log(null, action, "填充完成");
    // 收集填充后的数据
    resultList.addAll(fillList);
    _log(null, action, "修改model状态");
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

    // 由于有了_convert，并且dataModel缓存 这部分已经不需要了
    // // 获取模型属性列表
    // List<Attribute> attributeList = sampleModel.attributes.list;
    // // 遍历属性列表
    // for (var attr in attributeList) {
    //   // 判断属性是否需要填充
    //   if (!fillFilter(attr, useCache)) continue;
    //   _log(null, action, "属性:${attr.title}开始");
    //   // 扩展扩充
    //   await fillExtend(attr, mapList, useCache);
    //   _log(null, action, "属性:${attr.title}完成");
    // }
    // // 返回转换后的数据

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
    await afterFill(modelList);
    _log(null, action, "填充后操作执行完成，结束");
    return modelList;
  }

  /// 过滤是否填充 子类可覆写或调用
  bool fillFilter(Attribute attr, [bool? cache]) {
    return true;
  }

  /// 填充扩展字段 子类可覆写或调用
  Future<void> fillExtend(Attribute attr, List<Map<String, dynamic>> mapList, [bool? cache]) async {
    // 填充引用类型的数据
    await fillDataModel(attr, mapList, cache);
  }

  /// 填充BaseModel类型的数据 子类可覆写或调用
  Future<void> fillDataModel(Attribute attr, List<Map<String, dynamic>> mapList, [bool? cache]) async {
    String action = "数据模型填充";
    bool useCache = cache ?? _cache;
    // 属性名称
    String attrName = attr.name;
    // 不是DataModelAttribute类型的不填充
    if (attr is! DataModelAttribute && attr is! DataModelListAttribute) {
      _log(null, action, "${attr.name}非DataModel类型属性，结束");
      return;
    }
    // 收集主键集合，用于一次查询
    Set attrIdSet = {};
    // 遍历数据，收集主键
    for (Map<String, Object?> map in mapList) {
      // 数据为空 不处理
      if (null == map[attrName]) continue;
      // 集合类型的
      if (attr is DataModelListAttribute) {
        List idList = map[attrName] as List;
        for (String id in idList) {
          attrIdSet.add(id);
        }
      }
      // 普通类型的
      else {
        attrIdSet.add(map[attrName]);
      }
    }
    // 主键为空不处理
    if (attrIdSet.isEmpty) {
      _log(null, action, "${attr.name}无引用数据模型，结束");
      return;
    }
    // 属性类型
    Type attrType = attr.type;
    // 获取对应的dao
    DataDao dao = DaoCache.get(attrType);
    // 查询关联数据
    List<DataModel> refModelList = await dao.findByIDList(attrIdSet.toList(), useCache);
    _log(null, action, "${attr.name}查询完成");
    // 将关联数据转换为id数据映射
    Map<String, Model> idModelMap = {};
    if (refModelList.isNotEmpty) {
      for (DataModel refModel in refModelList) {
        idModelMap[refModel.id.value] = refModel;
      }
    }
    // 再次遍历数据，将id替换为完整数据
    for (Map<String, Object?> map in mapList) {
      // 原始value
      Object? oldValue = map[attrName];
      if (null == oldValue) continue;
      if (attr is DataModelListAttribute) {
        List refValueList = [];
        for (Object e in (oldValue as List)) {
          Model? model = idModelMap[e];
          // 没找到 当这个数据已经被删除了，这里惰性删除依赖
          if (null == model) continue;
          refValueList.add(model);
        }
        // 替换原始值
        map[attrName] = refValueList;
      } else {
        // 替换原始值，依赖被删除的话，这里是null，也会替换，惰性删除依赖
        map[attrName] = idModelMap[oldValue];
      }
    }
    _log(null, action, "${attr.name}回写完成");
  }

  /// 填充后处理 子类可覆写
  Future<void> afterFill(List<T> modelList, [bool? cache]) async {}
}
