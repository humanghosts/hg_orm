import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/cache.dart';
import 'package:hg_orm/dao/api/export.dart' as hg;
import 'package:hg_orm/dao/sembast/convert.dart';
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
  late final SembastConvert _convert;

  DataDao({bool logicDelete = true}) {
    _logicDelete = logicDelete;
    _sampleModel = ConstructorCache.get(T) as T;
    store = stringMapStoreFactory.store(T.toString());
    dataBase = SembastDatabaseHelper.database;
    _convert = SembastConvert();
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
    await store.record(model.id.value).add(tx ?? dataBase, _convert.modelValue(model));
    _log(model, action, "存储成功");
    DataModelCache.put(model.id.value, model);
    _log(model, action, "缓存成功，结束");
  }

  Future<void> _update(T model, [Transaction? tx]) async {
    String action = "更新";
    _log(model, action, "开始");
    model.timestamp.value = DateTime.now();
    await store.record(model.id.value).update(tx ?? dataBase, _convert.modelValue(model));
    _log(model, action, "存储成功");
    DataModelCache.put(model.id.value, model);
    _log(model, action, "缓存更新成功，结束");
  }

  Future<void> _delete(T model, [Transaction? tx]) async {
    String action;
    if (_logicDelete) {
      action = "逻辑删除";
      _log(model, action, "开始");
      model.isDelete.value = true;
      model.deleteTime.value = DateTime.now();
      await store.record(model.id.value).update(tx ?? dataBase, _convert.modelValue(model));
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

  hg.Filter? getLogicFilter(hg.Filter? filter) {
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

  /// 自定义查询
  @override
  Future<List<T>> find({
    hg.Filter? filter,
    List<hg.Sort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
  }) async {
    String action = "查询";
    _log(null, action, "开始");
    hg.Filter? logicFilter = getLogicFilter(filter);
    Finder finder = Finder(
      filter: logicFilter == null ? null : _convert.filterConvert(logicFilter),
      sortOrders: sorts?.map((sort) => _convert.sortConvert(sort)).toList(),
      limit: limit,
      offset: offset,
      start: start,
      end: end,
    );
    List<RecordSnapshot> record = await store.find(dataBase, finder: finder);
    _log(null, action, "读取成功");
    List<T> modeList = await merge(record);
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
    List<T> modeList = await merge(record);
    _log(null, action, "翻译成功，结束");
    return modeList;
  }

  /// 查询全部
  Future<List<T>> findAll() async {
    return await find();
  }

  /// 通过ID查询
  @override
  Future<T?> findByID(String id) async {
    List<T> newModelList = await find(filter: hg.SingleFilter.equals(field: sampleModel.id.name, value: id));
    if (newModelList.isEmpty) {
      return null;
    }
    return newModelList[0];
  }

  /// 通过ID列表查询
  Future<List<T>> findByIDList(List<String> idList) async {
    return await find(filter: hg.SingleFilter.inList(field: sampleModel.id.name, value: idList));
  }

  /// 查询首个
  Future<T?> findFirst({
    hg.Filter? filter,
    List<hg.Sort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
  }) async {
    String action = "查询首个";
    _log(null, action, "开始");
    hg.Filter? logicFilter = getLogicFilter(filter);
    Finder finder = Finder(
      filter: logicFilter == null ? null : _convert.filterConvert(logicFilter),
      sortOrders: sorts?.map((sort) => _convert.sortConvert(sort)).toList(),
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
    List<T> newModelList = await merge([record]);
    _log(null, action, "翻译成功，结束");
    return newModelList[0];
  }

  /// 计数
  @override
  Future<int> count({hg.Filter? filter}) async {
    String action = "计数";
    _log(null, action, "开始");
    hg.Filter? logicFilter = getLogicFilter(filter);
    int num = await store.count(dataBase, filter: logicFilter == null ? null : _convert.filterConvert(logicFilter));
    _log(null, action, "读取成功，结束");
    return num;
  }

  Future<List<T>> merge(List<RecordSnapshot> recordList) async {
    String action = "翻译";
    // 为空 返回空数组
    if (recordList.isEmpty) {
      return <T>[];
    }
    // 最终的返回结果
    List<T> resultList = [];
    // 讲recordList转换位mapList，便于对数据进行修改
    List<Map<String, Object?>> mapList = [];
    for (RecordSnapshot record in recordList) {
      Map<String, Object?> map = json.decode(json.encode(record.value)) as Map<String, Object?>;
      String id = map[sampleModel.id.name] as String;
      T? cacheModel = DataModelCache.get(id);
      if (cacheModel != null) {
        cacheModel.state = States.query;
        resultList.add(cacheModel);
        _log(cacheModel, action, "从缓存中读取");
        continue;
      } else {
        mapList.add(map);
      }
    }
    if (mapList.isEmpty) {
      _log(null, action, "无需翻译，结束");
      return resultList;
    }
    List<T> fillList = await fill(mapList);
    _log(null, action, "翻译完成");
    for (T fillModel in fillList) {
      fillModel.state = States.query;
      DataModelCache.put(fillModel.id.value, fillModel);
      _log(fillModel, action, "向缓存中存储");
    }
    resultList.addAll(fillList);
    _log(null, action, "结束");
    return resultList;
  }

  /// 填充数据
  Future<List<T>> fill(List<Map<String, Object?>> mapList) async {
    String action = "填充";
    // 获取模型属性列表
    List<Attribute> attributeList = sampleModel.attributes.list;
    // 遍历属性列表
    for (var attr in attributeList) {
      // 判断属性是否需要填充
      if (fillFilter(attr)) {
        _log(null, action, "属性:${attr.title}开始");
        // 扩展扩充
        await fillExtend(attr, mapList);
        _log(null, action, "属性:${attr.title}完成");
      }
    }
    _log(null, action, "属性填充完成");
    // 返回转换后的数据
    List<T> modelList = [];
    for (var e in mapList) {
      T model = await _convert.setModel(ConstructorCache.get(T) as T, e) as T;
      modelList.add(model);
    }
    _log(null, action, "类型转换完成");
    // 填充后操作
    await afterFill(modelList);
    _log(null, action, "填充后操作执行完成，结束");
    return modelList;
  }

  /// 过滤是否填充
  bool fillFilter(Attribute attr) {
    return true;
  }

  /// 填充扩展字段
  Future<void> fillExtend(Attribute attr, List<Map<String, dynamic>> mapList) async {
    // 填充引用类型的数据
    await fillRefer(attr, mapList);
  }

  /// 填充BaseModel类型的数据
  Future<void> fillRefer(Attribute attr, List<Map<String, dynamic>> mapList) async {
    String action = "翻译";
    // 属性名称
    String attrName = attr.name;
    // 不是DataModelAttribute类型的不填充
    if (attr is! DataModelAttribute && attr is! DataModelListAttribute) {
      _log(null, action, "${attr.name}非DataModel类型属性，结束");
      return;
    }
    // 收集主键集合，用于一次查询
    Set<String> attrValueSet = {};
    // 遍历数据，收集主键
    for (Map<String, dynamic> map in mapList) {
      if (null == map[attrName]) {
        continue;
      }
      if (attr is DataModelListAttribute) {
        // 集合类型的
        List<String> idList = map[attrName] as List<String>;
        for (String id in idList) {
          attrValueSet.add(id);
        }
      } else {
        attrValueSet.add(map[attrName]);
      }
    }
    // 主键为空不处理
    if (attrValueSet.isEmpty) {
      return;
    }
    Type attrType = attr.type;
    DataDao dao = DaoCache.get(attrType);
    // 查询关联数据
    List<DataModel> refModelList = await dao.findByIDList(attrValueSet.toList());
    _log(null, action, "${attr.name}查询完成");
    // 将关联数据转换为id数据映射
    Map<String, Model> idModelMap = {};
    if (refModelList.isNotEmpty) {
      for (DataModel refModel in refModelList) {
        idModelMap[refModel.id.value] = refModel;
      }
    }
    // 再次遍历数据，将id替换为完整数据
    for (Map<String, dynamic> map in mapList) {
      dynamic value = map[attrName];
      if (null == value) {
        continue;
      }
      if (attr is DataModelListAttribute) {
        List refValueList = [];
        value.forEach((e) {
          Model? model = idModelMap[e];
          if (null == model) {
            return;
          }
          refValueList.add(model);
        });
        map[attrName] = refValueList;
      } else {
        map[attrName] = idModelMap[value];
      }
    }
    _log(null, action, "${attr.name}回写完成");
  }

  /// 填充后处理
  Future<void> afterFill(List<T> modelList) async {
    return;
  }
}
