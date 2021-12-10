import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/database.dart';
import 'package:hg_orm/dao/api/export.dart';

import 'transaction.dart';

/// dao的基类
abstract class Dao<T extends Model> {
  /// 实体例
  late final T _sampleModel;

  /// 类型转换
  late final Convertor _convertor;

  /// 样本模型
  T get sampleModel => _sampleModel;

  /// 转换器
  Convertor get convertor => _convertor;

  Dao({required Convertor convertor}) {
    _sampleModel = ConstructorCache.get(T);
    _convertor = convertor;
  }

  Future<void> transaction(Future<void> Function(Transaction tx) action);

  Future<void> withTransaction(Transaction? tx, Future<void> Function(Transaction tx) action);

  /// 保存
  Future<void> save(T model, {Transaction? tx});

  /// 更新
  Future<void> update(String id, Map<String, Object?> value, {Transaction? tx});

  /// 删除
  Future<void> remove(T model, {Transaction? tx});

  /// 查询
  Future<List<T>> find({Transaction? tx});
}

/// 用于数据模型(通过id作为数据标识)的dao基类
abstract class DataDao<T extends DataModel> extends Dao<T> {
  /// 是否使用缓存
  late final bool _isCache;

  /// 是否开启逻辑删除
  late final bool _isLogicDelete;

  DataDao({bool? isLogicDelete, bool? isCache, required Convertor convertor})
      : super(
          convertor: convertor,
        ) {
    _isLogicDelete = isLogicDelete ?? DataBaseStarter.isLogicDelete;
    _isCache = isCache ?? DataBaseStarter.isCache;
  }

  bool get isCache => _isCache;

  bool get isLogicDelete => _isLogicDelete;

  /// 保存
  @override
  Future<void> save(T model, {Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 存储列表
  Future<void> saveList(List<T> modelList, {Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 更新
  @override
  Future<void> update(String id, Map<String, Object?> value, {Transaction? tx});

  /// 更新列表
  Future<void> updateList(List<String> idList, Map<String, Object?> value, {Transaction? tx});

  /// 条件更新
  Future<void> updateWhere(Filter filter, Map<String, Object?> value, {Transaction? tx});

  /// 删除
  @override
  Future<void> remove(T model, {Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 移除列表
  Future<void> removeList(List<T> modelList, {Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 条件删除
  Future<void> removeWhere(Filter filter, {Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 删除恢复
  Future<void> recover(T model, {Transaction? tx, bool? isCache});

  /// 恢复列表
  Future<void> recoverList(List<T> modelList, {Transaction? tx, bool? isCache});

  /// 条件恢复
  Future<void> recoverWhere(Filter filter, {Transaction? tx, bool? isCache});

  /// 查找
  @override
  Future<List<T>> find({Filter? filter, List<Sort>? sorts, Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 查找符合条件的第一个
  Future<T?> findFirst({Filter? filter, List<Sort>? sorts, Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 通过ID查询
  Future<T?> findByID(String id, {Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 通过ID查询
  Future<List<T>> findByIDList(List<String> id, {Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 计数
  Future<int> count({Filter? filter, Transaction? tx, bool? isLogicDelete, bool? isCache});
}

abstract class DataTreeDao<T extends DataTreeModel> extends DataDao<T> {
  DataTreeDao({bool? isLogicDelete, bool? isCache, required Convertor convertor})
      : super(
          isLogicDelete: isLogicDelete,
          isCache: isCache,
          convertor: convertor,
        );

  /// 按树查找
  Future<List<T>> findTree({Filter? filter, List<Sort>? sorts, Transaction? tx, bool? isLogicDelete, bool? isCache});

  /// 列表变树
  List<T> listToTree(List<T> modelList);
}

/// 用于普通模型(只有一个模型)的dao
abstract class SimpleDao<T extends SimpleModel> extends Dao<T> {
  SimpleDao({bool? isLogicDelete, bool? isCache, required Convertor convertor}) : super(convertor: convertor);
}
