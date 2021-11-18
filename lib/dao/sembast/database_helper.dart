import 'dart:developer';

import 'package:hg_orm/dao/api/export.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

class SembastDatabaseHelper extends DatabaseHelper {
  /// 数据库
  static Database? _database;

  /// 获取数据库
  static Database get database {
    assert(_database != null);
    return _database!;
  }

  /// 初始化数据库
  @override
  Future<void> open(String path) async {
    // 获取app的路径 path_provider包下
    final appDocumentDir = await getApplicationDocumentsDirectory();
    // 获取全量数据库路径
    final fullPath = join(appDocumentDir.path, path);
    // 通过绝对路径打开数据库
    _database = await databaseFactoryIo.openDatabase(fullPath);
    log("sembast database open success!");
  }
}
