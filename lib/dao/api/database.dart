/// 数据库处理类
abstract class Database {
  /// db专属，打开数据库
  Future<void> open(String path);

  /// 关闭数据库
  Future<void> close(String path);

  /// 刷新数据库
  Future<void> refresh(String path);
}