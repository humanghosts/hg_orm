import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/database.dart';
import 'package:hg_orm/dao/api/export.dart';

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

  /// 保存
  Future<void> save(T model);

  /// 删除
  Future<void> remove(T model);

  /// 查询
  Future<List<T>> find();
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

  @override
  Future<List<T>> find({HgFilter? filter, List<HgSort>? sorts});

  /// 查找全部
  Future<List<T>> findAll();

  /// 查找符合条件的第一个
  Future<T?> findFirst({HgFilter? filter, List<HgSort>? sorts});

  /// 存储列表
  Future<void> saveList(List<T> modelList);

  /// 移除列表
  Future<void> removeList(List<T> modelList);

  /// 恢复列表
  Future<void> recoverList(List<T> modelList);

  /// 通过ID查询
  Future<T?> findByID(String id);

  /// 通过ID查询
  Future<List<T>> findByIDList(List<String> id);

  /// 计数
  Future<int> count({HgFilter? filter});

  /// 删除恢复
  Future<void> recover(T model);

  /// 通过id恢复删除
  Future<void> recoverById(String id);
}

abstract class DataTreeDao<T extends DataTreeModel> extends DataDao<T> {
  DataTreeDao({bool? isLogicDelete, bool? isCache, required Convertor convertor})
      : super(
          isLogicDelete: isLogicDelete,
          isCache: isCache,
          convertor: convertor,
        );

  /// 按树查找
  Future<List<T>> findTree({HgFilter? filter, List<HgSort>? sorts});
}

/// 用于普通模型(只有一个模型)的dao
abstract class SimpleDao<T extends SimpleModel> extends Dao<T> {
  SimpleDao({bool? isLogicDelete, bool? isCache, required Convertor convertor}) : super(convertor: convertor);
}
