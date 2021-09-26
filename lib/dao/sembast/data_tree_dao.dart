import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/export.dart' as hg;
import 'package:hg_orm/dao/sembast/data_dao.dart';
import 'package:sembast/sembast.dart';

/// 树形公共的规范与实现
abstract class DataTreeDao<T extends DataTreeModel> extends DataDao<T> {
  /// 插入
  /// TODO 效率问题
  @override
  Future<void> save(T model, [Transaction? tx]) async {
    // 子节点
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataTreeModel child in model.children.value) {
        children.add(child as T);
      }
    }
    // 保存子节点
    children = await saveList(children, tx);
    // 保存当前节点
    await super.save(model, tx);
  }

  /// 移除
  @override
  Future<void> remove(T model, [Transaction? tx, bool isRemoveChildren = true]) async {
    List<T> children = <T>[];
    if (model.children.value.isNotEmpty) {
      for (DataTreeModel child in model.children.value) {
        children.add(child as T);
      }
    }
    // 子节点
    if (isRemoveChildren) {
      // 删除子节点
      await removeList(children, tx: tx);
    }
    await super.remove(model);
  }

  @override
  bool fillFilter(Attribute attr) {
    if (sampleModel.parent.name == attr.name) {
      return false;
    }
    return true;
  }

  /// 按树查找
  /// 先全查回来，然后组装成树
  Future<List<T>> findTree({hg.Filter? filter, List<hg.Sort>? sorts, int? limit, int? offset, Boundary? start, Boundary? end}) async {
    List<T> modelList = await find(filter: filter, sorts: sorts, limit: limit, offset: offset, start: start, end: end);
    if (modelList.isEmpty) {
      return modelList;
    }
    // 组装树
    Map<String, T> modelMap = {};
    for (T model in modelList) {
      modelMap[model.id.value] = model;
    }
    List<T> rootList = [];
    for (T node in modelList) {
      DataTreeModel? parent = node.parent.value;
      // 没有上级，说明是根节点
      if (null == parent) {
        rootList.add(node);
        continue;
      }
      // 处理非根节点
      String parentId = parent.id.value;
      DataTreeModel? parentModel = modelMap[parentId];
      // 缓存没有，说明这个节点的上级没有被查回来，当前节点也应该是根节点
      if (null == parentModel) {
        rootList.add(node);
        continue;
      }
      node.parent.value = parentModel;
    }
    // 填返回根节点
    return rootList;
  }

  /// 查找下级
  Future<List<T>> findChildrenByFullPath(Set<String> fullPathSet) async {
    List<Filter> filters = fullPathSet.map((fullPath) {
      return Filter.matches(sampleModel.fullPath.name, "^(${fullPath.replaceAll("|", "\\|")}\\|)[0-9a-zA-Z|]+\$");
    }).toList();
    return await nativeFind(filter: Filter.or(filters));
  }

  /// 查找直接下级
  Future<Map<String, List<T>>> findChildrenByIdSet(Set<String> parentId) async {
    List<T> children = await nativeFind(filter: Filter.inList(sampleModel.parent.name, parentId.toList()));
    Map<String, List<T>> childrenMap = {};
    for (T child in children) {
      String parentId = (child.parent.value!.id.value);
      if (childrenMap.containsKey(parentId)) {
        childrenMap[parentId]!.add(child);
      } else {
        childrenMap[parentId] = [child];
      }
    }
    return childrenMap;
  }

  /// 填充下级
  Future<void> fillChildren(List<T> modelList) async {
    Map<String, T> idModelMap = {};
    for (T model in modelList) {
      String id = model.id.value;
      idModelMap[id] = model;
    }
    // 查询直接下级
    Map<String, List<T>> childrenMap = await findChildrenByIdSet(Set.from(idModelMap.keys));
    if (childrenMap.isEmpty) {
      return;
    }
    childrenMap.forEach((parentId, children) {
      T parent = idModelMap[parentId]!;
      parent.children.value = children;
    });
  }

  /// 查询根节点
  Future<List<T>> findRoot({bool isOrder = true}) async {
    return await nativeFind(filter: Filter.matchesRegExp(sampleModel.fullPath.name, RegExp("^[0-9A-Za-z]{4}\$")));
  }
}
