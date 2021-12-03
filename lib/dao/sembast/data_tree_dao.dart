import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/export.dart';
import 'package:hg_orm/dao/api/export.dart';
import 'package:sembast/sembast.dart';

import 'data_dao.dart';

/// 树形公共的规范与实现
class SembastDataTreeDao<T extends DataTreeModel> extends SembastDataDao<T> implements DataTreeDao<T> {
  SembastDataTreeDao({bool? isLogicDelete, bool? isCache}) : super(isLogicDelete: isLogicDelete, isCache: isCache);

  @override
  Future<void> save(T model, {HgTransaction? tx, bool? isLogicDelete, bool? isCache}) async {
    // 子节点
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    await withTransaction(tx, (tx) async {
      await saveList(children, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      await super.save(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    });
  }

  @override
  Future<void> remove(T model, {HgTransaction? tx, bool? isLogicDelete, bool? isCache, bool isRemoveChildren = true}) async {
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    await withTransaction(tx, (tx) async {
      if (isRemoveChildren) await removeList(children, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      await super.remove(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    });
  }

  /// 删除的时候同时删除他们的下级
  /// 上级保存的下级惰性删除即可
  @override
  @override
  Future<void> removeWhere(HgFilter filter, {HgTransaction? tx, bool? isLogicDelete, bool? isCache}) async {
    List removeIdList = [];
    await withTransaction(tx, (tx) async {
      List idList = await _getTreeIdList(filter, tx, isLogicDelete: isLogicDelete, isCache: isCache);
      if (idList.isEmpty) {
        return;
      }
      // 换成id的过滤条件，简化一下
      Finder finder = Finder(filter: Filter.inList(sampleModel.id.name, idList));
      bool logicDelete = isLogicDelete ?? this.isLogicDelete;
      if (logicDelete) {
        // 逻辑删除
        await store.update(
            tx.getTx(),
            {
              sampleModel.isDelete.name: true,
              sampleModel.deleteTime.name: convertor.dateTimeConvert(DateTime.now()),
              sampleModel.timestamp.name: convertor.dateTimeConvert(DateTime.now()),
            },
            finder: finder);
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

  Future<List> _getTreeIdList(HgFilter filter, HgTransaction tx, {bool? isLogicDelete, bool? isCache}) async {
    // 查询要删除的模型,这理不需要翻译，不用使用find方法
    List<RecordSnapshot> recordList = await store.find(tx.getTx(), finder: Finder(filter: convertor.filterConvert(filter)));
    // 没有要删除的返回空
    if (recordList.isEmpty) {
      return [];
    }
    List idList = [];
    List<Filter> filters = [];
    for (RecordSnapshot record in recordList) {
      Map<String, Object?> map = record.value as Map<String, Object?>;
      idList.add(map[sampleModel.id.name]);
      // 全路径 肯定存在，不存在就算了
      Object? fullPathValue = map[sampleModel.fullPath.name];
      if (null == fullPathValue) {
        continue;
      }
      String fullPath = fullPathValue as String;
      // 下级过滤条件
      filters.add(Filter.matches(sampleModel.fullPath.name, "^(${fullPath.replaceAll("|", "\\|")}\\|)[0-9a-zA-Z|]+\$"));
    }
    filters.insert(0, Filter.inList(sampleModel.id.name, idList));
    return await store.findKeys(tx.getTx(), finder: Finder(filter: Filter.or(filters)));
  }

  @override
  Future<void> recover(T model, {HgTransaction? tx, bool? isCache}) async {
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    await withTransaction(tx, (tx) async {
      await recoverList(children, tx: tx, isCache: isCache);
      await super.recover(model, tx: tx, isCache: isCache);
    });
  }

  /// 恢复的时候同时恢复下级
  @override
  Future<void> recoverWhere(HgFilter filter, {HgTransaction? tx, bool? isLogicDelete, bool? isCache}) async {
    List recoverIdList = [];
    await withTransaction(tx, (tx) async {
      List idList = await _getTreeIdList(filter, tx, isLogicDelete: isLogicDelete, isCache: isCache);
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
            sampleModel.timestamp.name: convertor.dateTimeConvert(DateTime.now()),
          },
          finder: finder);
      recoverIdList = idList;
    });
    // 按照同样的条件查询一下id，防止缓存和数据库不一致
    for (var id in recoverIdList) {
      DataModelCache.remove(id as String);
    }
  }

  /// 按树查找
  /// 先全查回来，然后组装成树
  @override
  Future<List<T>> findTree({
    HgTransaction? tx,
    HgFilter? filter,
    List<HgSort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? isCache,
    bool? isLogicDelete,
  }) async {
    List<T> modelList = await find(
      filter: filter,
      sorts: sorts,
      limit: limit,
      offset: offset,
      start: start,
      end: end,
      tx: tx,
      isCache: isCache,
      isLogicDelete: isLogicDelete,
    );
    return listToTree(modelList);
  }

  @override
  List<T> listToTree(List<T> modelList) {
    if (modelList.isEmpty) return modelList;
    // fullPath:Model
    Map<String, T> modelMap = {};
    List<String> fullPathList = [];
    for (T model in modelList) {
      modelMap[model.fullPath.value] = model;
      fullPathList.add(model.fullPath.value);
    }
    // 按照长度排序
    fullPathList.sort((a, b) => a.length.compareTo(b.length));
    // 如果某个节点的上级在，这个节点不应该存在，无论是否为直接上级
    modelMap.removeWhere((key, value) {
      for (String fullPath in fullPathList) {
        if (key.length <= fullPath.length) {
          break;
        }
        if (key.contains(fullPath + "|")) {
          fullPathList.remove(key);
          return true;
        }
      }
      return false;
    });
    // 填返回根节点
    return modelMap.values.toList();
  }
}
