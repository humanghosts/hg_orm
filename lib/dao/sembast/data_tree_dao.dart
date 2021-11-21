import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/export.dart';
import 'package:hg_orm/dao/export.dart';
import 'package:sembast/sembast.dart';

import 'data_dao.dart';

/// 树形公共的规范与实现
class SembastDataTreeDao<T extends DataTreeModel> extends SembastDataDao<T> implements DataTreeDao<T> {
  SembastDataTreeDao({bool? isLogicDelete, bool? isCache}) : super(isLogicDelete: isLogicDelete, isCache: isCache);

  @override
  Future<void> save(T model, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    // 子节点
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    if (null == tx) {
      await dataBase.transaction((transaction) async {
        await saveList(children, tx: transaction, isLogicDelete: isLogicDelete, isCache: isCache);
        await super.save(model, tx: transaction, isLogicDelete: isLogicDelete, isCache: isCache);
      });
    } else {
      await saveList(children, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      await super.save(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    }
  }

  @override
  Future<void> remove(T model, {Transaction? tx, bool? isLogicDelete, bool? isCache, bool isRemoveChildren = true}) async {
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    if (null == tx) {
      await dataBase.transaction((transaction) async {
        if (isRemoveChildren) await removeList(children, tx: transaction, isLogicDelete: isLogicDelete, isCache: isCache);
        await super.remove(model, tx: transaction, isLogicDelete: isLogicDelete, isCache: isCache);
      });
    } else {
      if (isRemoveChildren) await removeList(children, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      await super.remove(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    }
  }

  @override
  Future<void> recover(T model, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    if (null == tx) {
      await dataBase.transaction((transaction) async {
        await recoverList(children, tx: transaction, isLogicDelete: isLogicDelete, isCache: isCache);
        await super.recover(model, tx: transaction, isLogicDelete: isLogicDelete, isCache: isCache);
      });
    } else {
      await recoverList(children, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      await super.recover(model, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    }
  }

  /// 按树查找
  /// 先全查回来，然后组装成树
  @override
  Future<List<T>> findTree({
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
      isCache: isCache,
      isLogicDelete: isLogicDelete,
    );
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
