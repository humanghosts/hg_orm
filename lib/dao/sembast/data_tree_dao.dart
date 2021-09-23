import 'package:sembast/sembast.dart';

/// 树形公共的规范与实现
abstract class BaseTreeDao<T extends TreeModelPlus> extends BaseDao<T> {
  /// 插入
  /// TODO 效率问题
  @override
  Future<T> save(T model, {Transaction? tx}) async {
    // 子节点
    List<T> children = <T>[];
    if (CollectionUtils.isNotEmpty(model.children.value)) {
      model.children.value.forEach((e) => children.add(e as T));
    }
    // 保存子节点
    children = await saveList(children, tx: tx);
    // 保存当前节点
    T newModel = await super.save(model, tx: tx);
    return newModel;
  }

  /// 移除
  @override
  Future<void> remove(T model, {Transaction? tx, bool isRemoveChildren = true}) async {
    if (ModelUtils.isEmpty(model)) {
      return;
    }
    List<T> children = <T>[];
    if (CollectionUtils.isNotEmpty(model.children.value)) {
      model.children.value.forEach((e) => children.add(e as T));
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
    if (sampleModel.children.name == attr.name) {
      return false;
    }
    return true;
  }

  /// 按树查找
  /// 先全查回来，然后组装成树
  Future<List<T>> findTree({Filter? filter, List<SortOrder>? sortOrders, int? limit, int? offset, Boundary? start, Boundary? end}) async {
    List<T> modelList = await find(filter: filter, sortOrders: sortOrders, limit: limit, offset: offset, start: start, end: end);
    if (CollectionUtils.isEmpty(modelList)) {
      return modelList;
    }
    // 组装树
    Map<String, T> modelMap = new Map();
    modelList.forEach((model) {
      modelMap[model.id.value!] = model;
    });
    List<T> rootList = [];
    modelList.forEach((node) {
      TreeModel? parent = node.parent.value;
      // 没有上级，说明是根节点
      if (null == parent) {
        rootList.add(node);
        return;
      }
      // 处理非根节点
      String parentId = parent.id.value!;
      TreeModel? parentModel = modelMap[parentId];
      // 缓存没有，说明这个节点的上级没有被查回来，当前节点也应该是根节点
      if (null == parentModel) {
        rootList.add(node);
        return;
      }
      node.parent.value = parentModel;
    });
    // 填返回根节点
    return rootList;
  }

  /// 查找下级
  Future<List<T>> findChildrenByFullPath(Set<String> fullPathSet) async {
    List<Filter> filters = fullPathSet.map((fullPath) {
      return Filter.matches(sampleModel.fullPath.name, "^(${fullPath.replaceAll("|", "\\|")}\\|)[0-9a-zA-Z|]+\$");
    }).toList();
    Finder finder = new Finder(filter: Filter.or(filters));
    List<RecordSnapshot> record = await store.find(dataBase, finder: finder);
    return await fill(record);
  }

  /// 查找直接下级
  Future<Map<String, List<T>>> findChildrenByIdSet(Set<String> parentId) async {
    Finder finder = new Finder(filter: Filter.inList(sampleModel.parent.name, parentId.toList()));
    List<RecordSnapshot> record = await store.find(dataBase, finder: finder);
    List<T> children = await fill(record);
    Map<String, List<T>> childrenMap = new Map();
    for (T child in children) {
      String parentId = (child.parent.value!.id.value)!;
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
    Map<String, T> idModelMap = new Map();
    for (T model in modelList) {
      String id = model.id.value!;
      idModelMap[id] = model;
    }
    // 查询直接下级
    Map<String, List<T>> childrenMap = await findChildrenByIdSet(Set.from(idModelMap.keys));
    if (CollectionUtils.isEmpty(childrenMap)) {
      return;
    }
    childrenMap.forEach((parentId, children) {
      T parent = idModelMap[parentId]!;
      parent.children.value = children;
    });
  }

  /// 查询根节点
  Future<List<T>> findRoot({bool isOrder = true}) async {
    return await find(filter: Filter.matchesRegExp(sampleModel.fullPath.name, RegExp("^[0-9A-Za-z]{4}\$")));
  }
}
