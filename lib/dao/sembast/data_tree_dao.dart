import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/export.dart' as hg;
import 'package:hg_orm/dao/sembast/data_dao.dart';
import 'package:sembast/sembast.dart';

/// 树形公共的规范与实现
abstract class DataTreeDao<T extends DataTreeModel> extends DataDao<T> {
  @override
  Future<void> save(T model, [Transaction? tx]) async {
    // 子节点
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    if (null == tx) {
      await dataBase.transaction((transaction) async {
        children = await saveList(children, transaction);
        await super.save(model, transaction);
      });
    } else {
      children = await saveList(children, tx);
      await super.save(model, tx);
    }
  }

  @override
  Future<void> remove(T model, [Transaction? tx, bool isRemoveChildren = true]) async {
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    if (null == tx) {
      await dataBase.transaction((transaction) async {
        if (isRemoveChildren) await removeList(children, tx: transaction);
        await super.remove(model, transaction);
      });
    } else {
      if (isRemoveChildren) await removeList(children, tx: tx);
      await super.remove(model, tx);
    }
  }

  @override
  Future<void> recover(T model, [Transaction? tx]) async {
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataModel child in model.children.value) {
        children.add(child as T);
      }
    }
    if (null == tx) {
      await dataBase.transaction((transaction) async {
        await recoverList(children, tx: transaction);
        await super.recover(model, transaction);
      });
    } else {
      await recoverList(children, tx: tx);
      await super.recover(model, tx);
    }
  }

  /// 按树查找
  /// 先全查回来，然后组装成树
  Future<List<T>> findTree({
    hg.Filter? filter,
    List<hg.Sort>? sorts,
    int? limit,
    int? offset,
    Boundary? start,
    Boundary? end,
    bool? cache,
  }) async {
    List<T> modelList = await find(
      filter: filter,
      sorts: sorts,
      limit: limit,
      offset: offset,
      start: start,
      end: end,
      cache: cache,
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
