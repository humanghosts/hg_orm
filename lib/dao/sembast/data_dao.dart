import 'dart:async';
import 'dart:convert';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_entity/status/status.dart';
import 'package:hg_orm/dao/api/dao.dart';
import 'package:hg_orm/dao/api/export.dart' as hg;
import 'package:hg_orm/dao/sembast/convert.dart';
import 'package:hg_orm/dao/sembast/database_helper.dart';
import 'package:sembast/sembast.dart';

typedef FutureOrFunc = FutureOr<dynamic> Function(Transaction transaction);

abstract class DataDao<T extends DataModel> implements Dao {
  /// 获取新的实例
  T get newModel;

  /// Dao处理的实体的样本，用于获取属性等字段
  T get sampleModel;

  /// 存储库名称
  String get storeName;

  /// 获取实体所在存储库的名称
  late StoreRef store;

  /// 获取数据库实例
  late Database dataBase;

  late final bool _logicDelete;

  late final SembastConvert _convert;

  DataDao({bool logicDelete = true}) {
    _logicDelete = logicDelete;
    store = stringMapStoreFactory.store(storeName);
    dataBase = SembastDatabaseHelper.database;
    _convert = SembastConvert();
  }

  /// 保存，存在更新，不存在插入
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

  /// TODO
  Map toMap(T model) {
    return {};
  }

  Future<void> _insert(T model, [Transaction? tx]) async {
    model.createTime.value = DateTime.now();
    model.timestamp.value = DateTime.now();
    await store.record(model.id.value).add(tx ?? dataBase, toMap(model));
  }

  Future<void> _update(T model, [Transaction? tx]) async {
    model.timestamp.value = DateTime.now();
    await store.record(model.id.value).update(tx ?? dataBase, toMap(model));
  }

  Future<void> _delete(T model, [Transaction? tx]) async {
    if (_logicDelete) {
      model.isDelete.value = true;
      model.deleteTime.value = DateTime.now();
      await store.record(model.id.value).update(tx ?? dataBase, toMap(model));
      return;
    }
    await store.record(model.id.value).delete(tx ?? dataBase);
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
  /// 查询入口方法之一，其他查看[findFirst]，[count]
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
    List<T> newModelList = await fill(record);
    return newModelList;
  }

  /// 查询全部
  Future<List<T>> findAll() async {
    return await find();
  }

  /// 通过ID查询
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
  /// 查询入口方法，其他查看[find]，[count]
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
    List<T> newModelList = await fill([record]);
    return newModelList[0];
  }

  /// 计数
  /// 查询入口方法，其他查看[find]，[findFirst]
  Future<int> count({hg.Filter? filter}) async {
    hg.Filter? logicFilter = getLogicFilter(filter);
    int num = await store.count(dataBase, filter: logicFilter == null ? null : _convert.filterConvert(logicFilter));
    return num;
  }

  /// 填充数据
  Future<List<T>> fill(List<RecordSnapshot> recordList) async {
    // 为空 返回空数组
    if (recordList.isEmpty) {
      return <T>[];
    }
    // 讲recordList转换位mapList，便于对数据进行修改
    List<Map<String, Object?>> mapList = recordList.map((record) {
      return json.decode(json.encode(record.value)) as Map<String, Object?>;
    }).toList();
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
    List<T> modelList = mapList.map((e) => newModel.fromMap(e) as T).toList();
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
    // 属性类型
    Type attrType = attr.type;
    // 不是BaseModel类型的不填充
    if (!ModelUtils.isModel(attrType)) {
      return;
    }
    // 收集主键集合，用于一次查询
    Set<String> attrValueSet = new Set();
    // 遍历数据，收集主键
    for (Map<String, dynamic> map in mapList) {
      if (null == map[attrName]) {
        continue;
      }
      // TODO 其他类型的属性处理 map类型、custom类型
      if (attr is ListAttribute) {
        // 集合类型的
        Iterable it = map[attrName];
        it.forEach((e) {
          attrValueSet.add(e.toString());
        });
      } else {
        // 字符串类型的
        attrValueSet.add(map[attrName]);
      }
    }
    // 主键为空不处理
    if (CollectionUtils.isEmpty(attrValueSet)) {
      return;
    }
    // 找不到对应类型的dao，不处理
    DataDao? dao = DbCtx.daos.getNew(attrType.toString());
    if (null == dao) {
      throw Exception("can find ${attrType.toString()}`s dao");
    }
    // 查询关联数据
    List<Model> refModelList = await dao.findByIDList(attrValueSet.toList());
    // 将关联数据转换为id数据映射
    Map<String, Model> idModelMap = new Map();
    if (CollectionUtils.isNotEmpty(refModelList)) {
      for (Model refModel in refModelList) {
        idModelMap[refModel.id.value!] = refModel;
      }
    }
    // 再次遍历数据，将id替换为完整数据
    for (Map<String, dynamic> map in mapList) {
      dynamic value = map[attrName];
      if (null == value) {
        continue;
      }
      // TODO 其他类型的属性处理 map类型、custom类型
      if (attr is ListAttribute) {
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
