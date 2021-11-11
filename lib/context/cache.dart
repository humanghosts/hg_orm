import 'package:flutter/cupertino.dart';
import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/dao.dart';

class DaoCache {
  DaoCache._();

  static final Map<String, Dao> _cache = {};

  static void put<T extends Dao>(Type type, T dao) {
    String typeStr = "$type";
    String typeStrNullable = "$type?";
    _cache[typeStr] = dao;
    _cache[typeStrNullable] = dao;
  }

  static T get<T extends Dao>(Type type) {
    return getStr(type.toString());
  }

  static T getStr<T extends Dao>(String type) {
    assert(_cache.containsKey(type), "register ${type.toString()}'s dao first");
    return _cache[type] as T;
  }
}

@immutable
class DataModelCacheNode<T> {
  final DataModelCacheType cacheType;
  final T model;

  const DataModelCacheNode(this.cacheType, this.model);
}

enum DataModelCacheType {
  done,
  undone,
}

/// 完成的数据填充的DataModel
class DataModelCache {
  DataModelCache._();

  static final Map<String, DataModel> _doneCache = {};
  static final Map<String, DataModel> _undoneCache = {};

  static void put<T extends DataModel>(T model, [DataModelCacheType cacheType = DataModelCacheType.done]) {
    String id = model.id.value;
    switch (cacheType) {
      case DataModelCacheType.done:
        _doneCache[id] = model;
        break;
      case DataModelCacheType.undone:
        _undoneCache[id] = model;
        break;
    }
  }

  static DataModelCacheNode<T>? get<T extends DataModel>(String id) {
    if (_doneCache.containsKey(id)) {
      return DataModelCacheNode(DataModelCacheType.done, _doneCache[id] as T);
    }
    if (_undoneCache.containsKey(id)) {
      return DataModelCacheNode(DataModelCacheType.undone, _undoneCache[id] as T);
    }
    return null;
  }

  static void remove(String id) {
    _doneCache.remove(id);
    _undoneCache.remove(id);
  }

  static void levelUp(String id) {
    // 从高到低升级
    _doneLevelUp(id);
    _undoneLevelUp(id);
  }

  static void _undoneLevelUp(String id) {
    if (!_undoneCache.containsKey(id)) {
      return;
    }
    DataModel model = _undoneCache[id]!;
    _undoneCache.remove(id);
    _doneCache[id] = model;
  }

  static void _doneLevelUp(String id) {}
}
