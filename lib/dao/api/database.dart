import 'package:hg_orm/dao/api/export.dart';

/// 数据库处理类
abstract class Database {
  /// db专属，打开数据库
  Future<void> open(String path);

  /// 打开kv数据库
  Future<void> openKV();

  /// 获取kv数据库
  KV get kv;

  /// 关闭数据库
  Future<void> close(String path);

  /// 刷新数据库
  Future<void> refresh(String path);

  /// 新建一个事务
  Future<void> transaction(Future<void> Function(Transaction tx) action);

  /// 有事务使用当前事务，没有事务新建一个事务
  Future<void> withTransaction(Transaction? tx, Future<void> Function(Transaction tx) action);
}
