import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/dao.dart';

class DaoCache {
  DaoCache._();

  static final Map<String, Dao> _cache = {};

  static void put<T extends Dao>(Type type, T dao) {
    _cache["$type"] = dao;
  }

  static T get<T extends Dao>(Type type) {
    return getStr(type.toString());
  }

  static T getStr<T extends Dao>(String type) {
    assert(_cache.containsKey(type), "register ${type.toString()}'s dao first");
    return _cache[type] as T;
  }
}

class DataModelCache {
  DataModelCache._();

  static final Map<String, DataModel> _cache = {};

  static void put<T extends DataModel>(String id, T model) {
    _cache[id] = model;
  }

  static T? get<T extends DataModel>(String id) {
    return _cache[id] as T?;
  }

  static void remove(String id) {
    _cache.remove(id);
  }
}
