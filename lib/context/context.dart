import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/dao.dart';

class DaoCache {
  DaoCache._();

  static final Map<Type, Dao> _cache = {};

  static void register<T extends Dao>(Type type, T dao) {
    _cache[type] = dao;
  }

  static T get<T extends Dao>(Type type) {
    if (!_cache.containsKey(type)) {
      throw Exception("register ${type.toString()}'s dao first");
    }
    return _cache[type] as T;
  }
}

class NewModelCache {
  NewModelCache._();

  static final Map<Type, Model Function()> _cache = {};

  static void register(Type type, Model Function() constructor) {
    _cache[type] = constructor;
  }

  static T get<T extends Model>(Type type) {
    if (!_cache.containsKey(type)) {
      throw Exception("register ${type.toString()}'s constructor first");
    }
    return _cache[type]!.call() as T;
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
