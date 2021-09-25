import 'dart:developer';

import 'package:hg_orm/dao/api/export.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

class SembastDatabaseHelper implements DatabaseHelper {
  /// 数据库
  static Database? _database;

  /// 获取数据库
  static Database get database {
    if (_database == null) {
      throw Exception("database is not init,please check");
    } else {
      return _database!;
    }
  }

  final String path;
  final DatabaseListener? listener;

  SembastDatabaseHelper({required this.path, this.listener});

  /// 初始化数据库
  @override
  Future<void> initial() async {
    // 获取app的路径 path_provider包下
    final appDocumentDir = await getApplicationDocumentsDirectory();
    // 获取全量数据库路径
    final fullPath = join(appDocumentDir.path, path);
    // 通过绝对路径打开数据库
    _database = await databaseFactoryIo.openDatabase(fullPath);
    log("database open success!");
    // 预制数据 嵌套写的原因是listener后面万一有多个监听方法呢
    if (listener != null) {
      if (listener!.afterOpenDatabase != null) {
        await listener!.afterOpenDatabase!.call();
      }
    }
  }
}

class DatabaseListener {
  Future<void> Function()? afterOpenDatabase;

  DatabaseListener({this.afterOpenDatabase});
}
