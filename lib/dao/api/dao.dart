import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/export.dart';

abstract class Dao<T extends Model> {
  Future<void> save(T model);

  Future<void> remove(T model);

  Future<List<T>> find({Filter? filter, List<Sort>? sorts});

  Future<T?> findByID(String id);

  Future<int> count({Filter? filter});
}
