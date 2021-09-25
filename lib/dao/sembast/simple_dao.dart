import 'dart:async';

import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/dao.dart';
import 'package:sembast/sembast.dart';

typedef FutureOrFunc = FutureOr<dynamic> Function(Transaction transaction);

/// 公共的规范与实现
abstract class BaseDao<T extends DataModel> implements Dao {}
