import 'package:hg_orm/hg_orm.dart';

/// 数据库处理类
abstract class Database {
  /// 是否逻辑删除
  late final bool isLogicDelete;

  Database({bool? isLogicDelete}) {
    this.isLogicDelete = isLogicDelete ?? true;
  }

  /// db专属，打开数据库
  Future<void> open();

  /// 打开kv数据库
  Future<void> openKV();

  /// 获取kv数据库
  KV get kv;

  /// 关闭数据库
  Future<void> close();

  /// 刷新数据库
  Future<void> refresh();

  /// 新建一个事务
  Future<void> transaction(Future<void> Function(Transaction tx) action);

  /// 有事务使用当前事务，没有事务新建一个事务
  Future<void> withTransaction(Transaction? tx, Future<void> Function(Transaction tx) action);
}