import 'dart:async';
import 'dart:convert';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_entity/status/status.dart';
import 'package:hg_orm/context/context.dart';
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
    _sampleModel = NewModelCache.get(T) as T;
    store = stringMapStoreFactory.store(storeName);
    dataBase = SembastDatabaseHelper.database;
    _convert = SembastConvert();
  }

  /// Dao处理的实体的样本，用于获取属性等字段
  T get sampleModel => _sampleModel;

  /// 设置存储库名称
  String get storeName;

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
    model.createTime.value = DateTime.now();
    model.timestamp.value = DateTime.now();
    await store.record(model.id.value).add(tx ?? dataBase, _convert.modelValue(model));
    DataModelCache.put(model.id.value, model);
  }

  Future<void> _update(T model, [Transaction? tx]) async {
    model.timestamp.value = DateTime.now();
    await store.record(model.id.value).update(tx ?? dataBase, _convert.modelValue(model));
    DataModelCache.put(model.id.value, model);
  }

  Future<void> _delete(T model, [Transaction? tx]) async {
    if (_logicDelete) {
      model.isDelete.value = true;
      model.deleteTime.value = DateTime.now();
      await store.record(model.id.value).update(tx ?? dataBase, _convert.modelValue(model));
      DataModelCache.remove(model.id.value);
      return;
    }
    await store.record(model.id.value).delete(tx ?? dataBase);
    DataModelCache.remove(model.id.value);
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
    model.markNeedRemove();
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
  Future<List<T>> find({hg.Filter? filter, List<hg.Sort>? sorts, int? limit, int? offset, Boundary? start, Boundary? end}) async {
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
    return await merge(record);
  }

  /// 用原生的方法查询
  Future<List<T>> nativeFind({Filter? filter, List<SortOrder>? sortOrders, int? limit, int? offset, Boundary? start, Boundary? end}) async {
    Filter filterWithoutDelete = null == filter
        ? Filter.notEquals(sampleModel.isDelete.name, true)
        : Filter.and([
            Filter.notEquals(sampleModel.isDelete.name, true),
            filter,
          ]);
    Finder finder = Finder(filter: filterWithoutDelete, sortOrders: sortOrders, limit: limit, offset: offset, start: start, end: end);
    List<RecordSnapshot> record = await store.find(dataBase, finder: finder);
    return await merge(record);
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
  Future<T?> findFirst({hg.Filter? filter, List<hg.Sort>? sorts, int? limit, int? offset, Boundary? start, Boundary? end}) async {
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
    if (null == record) {
      return null;
    }
    List<T> newModelList = await merge([record]);
    return newModelList[0];
  }

  /// 计数
  @override
  Future<int> count({hg.Filter? filter}) async {
    hg.Filter? logicFilter = getLogicFilter(filter);
    int num = await store.count(dataBase, filter: logicFilter == null ? null : _convert.filterConvert(logicFilter));
    return num;
  }

  Future<List<T>> merge(List<RecordSnapshot> recordList) async {
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
        resultList.add(cacheModel);
        continue;
      } else {
        mapList.add(map);
      }
    }
    if (mapList.isEmpty) {
      return resultList;
    }
    List<T> fillList = await fill(mapList);
    for (T fillModel in fillList) {
      DataModelCache.put(fillModel.id.value, fillModel);
    }
    resultList.addAll(fillList);
    return resultList;
  }

  /// 填充数据
  Future<List<T>> fill(List<Map<String, Object?>> mapList) async {
    // 获取模型属性列表
    List<Attribute> attributeList = sampleModel.attributes.list;
    // 遍历属性列表
    for (var attr in attributeList) {
      // 判断属性是否需要填充
      if (fillFilter(attr)) {
        // 扩展扩充
        await fillExtend(attr, mapList);
      }
    }
    // 返回转换后的数据
    List<T> modelList = mapList.map((e) => _convert.setModel(NewModelCache.get(T) as T, e) as T).toList();
    // 填充后操作
    await afterFill(modelList);
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
    // 属性名称
    String attrName = attr.name;
    // 不是DataModelAttribute类型的不填充
    if (attr is! DataModelAttribute && attr is! DataModelListAttribute) {
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
  }

  /// 填充后处理
  Future<void> afterFill(List<T> modelList) async {
    return;
  }
}
