/// 数据库处理类
abstract class DatabaseHelper {
  /// db专属，打开数据库
  Future<void> open(String path);
}
