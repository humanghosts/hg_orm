import 'dart:developer';

import 'package:hg_orm/dao/api/export.dart' as api;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

class SembastDatabaseHelper extends api.Database {
  /// 数据库
  static Database? _database;

  /// 获取数据库
  static Database get database {
    assert(_database != null);
    return _database!;
  }

  String? path;

  /// 初始化数据库
  @override
  Future<void> open(String path) async {
    this.path = path;
    // 获取app的路径 path_provider包下
    final appDocumentDir = await getApplicationDocumentsDirectory();
    // 获取全量数据库路径
    final fullPath = join(appDocumentDir.path, path);
    // 通过绝对路径打开数据库
    _database = await databaseFactoryIo.openDatabase(fullPath);
    log("sembast database open success!");
  }

  @override
  Future<void> close(String path) async {
    await _database?.close();
  }

  @override
  Future<void> refresh(String path) async {
    await close(path);
    await open(path);
  }
}
