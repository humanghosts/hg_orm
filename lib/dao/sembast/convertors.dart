import 'package:hg_orm/dao/api/export.dart' as api;
import 'package:sembast/sembast.dart';

/// sembast转换器
class SembastConvertors extends api.Convertors {
  SembastConvertors._();

  static SembastConvertors? _instance;

  static SembastConvertors get instance {
    _instance ??= SembastConvertors._();
    return _instance!;
  }

  @override
  SembastFilterConvertors get filterConvertor => SembastFilterConvertors.instance;

  @override
  SembastSortConvertors get sortConvertor => SembastSortConvertors.instance;
}

/// sembast数据库的过滤转换器
class SembastFilterConvertors extends api.FilterConvertor<Filter> {
  SembastFilterConvertors._();

  static SembastFilterConvertors? _instance;

  static SembastFilterConvertors get instance {
    _instance ??= SembastFilterConvertors._();
    return _instance!;
  }

  @override
  Future<api.Filter?> from(Filter? value) async {
    throw UnimplementedError();
  }

  @override
  Future<Filter?> to(api.Filter? value) async {
    if (null == value) return null;
    return filterConvert(value);
  }

  Filter filterConvert(api.Filter filter) {
    if (filter is api.SingleFilter) {
      return convertSingleFilter(filter);
    } else {
      return convertGroupFilter(filter as api.GroupFilter);
    }
  }

  /// 是否匹配 带"."判断，支持map里的内容判断
  /// [nullAsTrue]标识，如果key为空算匹配还是不匹配
  bool getMatch({
    required RecordSnapshot record,
    required String field,
    bool nullAsTrue = false,
    required bool Function(Object? recordValue) isMatch,
  }) {
    Map<String, Object?> recordMap = record.value;
    return _getMapMatch(mapValue: recordMap, field: field, nullAsTrue: nullAsTrue, isMatch: isMatch);
  }

  /// map类型匹配
  bool _getMapMatch({
    required Map<String, Object?> mapValue,
    required String field,
    bool nullAsTrue = false,
    required bool Function(Object? recordValue) isMatch,
  }) {
    Map<String, Object?> map = mapValue;
    List<String> keys = field.split(".");
    // 当前key
    String key = keys[0];
    // 不存在key返回不匹配
    if (!map.containsKey(key)) return nullAsTrue;
    // 如果是最后一个key 并且存在key，判断是否匹配
    Object? value = map[key];
    if (keys.length == 1) {
      return isMatch(value);
    }
    // 不是最后一个key 继续向下寻找
    String nextKey = keys.sublist(1).join(".");
    // list类型处理
    if (value is List) {
      return _getListMatch(listValue: value, field: nextKey, nullAsTrue: nullAsTrue, isMatch: isMatch);
    }
    // map类型处理
    if (value is Map) {
      return _getMapMatch(mapValue: value as Map<String, Object?>, field: nextKey, nullAsTrue: nullAsTrue, isMatch: isMatch);
    }
    // 其它类型不匹配
    return false;
  }

  /// list类型匹配
  bool _getListMatch({
    required List listValue,
    required String field,
    bool nullAsTrue = false,
    required bool Function(Object? recordValue) isMatch,
  }) {
    bool match = false;
    for (Object? value in listValue) {
      if (null == value) continue;
      // list类型处理
      if (value is List) {
        match = match || _getListMatch(listValue: value, field: field, nullAsTrue: nullAsTrue, isMatch: isMatch);
      }
      // map类型处理
      if (value is Map) {
        match = match || _getMapMatch(mapValue: value as Map<String, Object?>, field: field, nullAsTrue: nullAsTrue, isMatch: isMatch);
      }
      if (match) {
        return match;
      }
    }
    return match;
  }

  // copy from sembast
  int? _safeCompare(Object? value1, Object? value2) {
    try {
      if (value1 is Comparable && value2 is Comparable) {
        return Comparable.compare(value1, value2);
      }
    } catch (_) {}
    return null;
  }

  // copy from sembast
  bool _lessThan(Object? value1, Object? value2) {
    var cmp = _safeCompare(value1, value2);
    return cmp != null && cmp < 0;
  }

  // copy from sembast
  bool _greaterThan(Object? value1, Object? value2) {
    var cmp = _safeCompare(value1, value2);
    return cmp != null && cmp > 0;
  }

  /// 转换单个过滤条件
  Filter convertSingleFilter(api.SingleFilter filter) {
    String field = filter.field;
    api.FilterOp op = filter.op;
    switch (op) {
      // 相等
      case api.SingleFilterOp.equals:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            // 如果value为null null as true
            nullAsTrue: value == null,
            isMatch: (recordValue) {
              if (value is DateTime) {
                int intValue = value.millisecondsSinceEpoch;
                return recordValue == intValue;
              } else {
                return recordValue == value;
              }
            },
          );
        });
      // 不等
      case api.SingleFilterOp.notEquals:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            // 如果value为null null as true
            nullAsTrue: value != null,
            isMatch: (recordValue) {
              if (value is DateTime) {
                int intValue = value.millisecondsSinceEpoch;
                return recordValue != intValue;
              } else {
                return recordValue != value;
              }
            },
          );
        });
      // 为空
      case api.SingleFilterOp.isNull:
        return Filter.custom((record) {
          return getMatch(
            record: record,
            field: field,
            nullAsTrue: true,
            isMatch: (recordValue) => recordValue == null,
          );
        });
      // 非空
      case api.SingleFilterOp.notNull:
        return Filter.custom((record) {
          return getMatch(
            record: record,
            field: field,
            nullAsTrue: false,
            isMatch: (recordValue) => recordValue != null,
          );
        });
      // 小于
      case api.SingleFilterOp.lessThan:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (value is DateTime) {
                return _lessThan(recordValue, value.millisecondsSinceEpoch);
              } else {
                return _lessThan(recordValue, value);
              }
            },
          );
        });
      // 小于等于
      case api.SingleFilterOp.lessThanOrEquals:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (value is DateTime) {
                int intValue = value.millisecondsSinceEpoch;
                return _lessThan(recordValue, intValue) || recordValue == intValue;
              } else {
                return _lessThan(recordValue, value) || recordValue == value;
              }
            },
          );
        });
      // 大于
      case api.SingleFilterOp.greaterThan:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (value is DateTime) {
                return _greaterThan(recordValue, value.millisecondsSinceEpoch);
              } else {
                return _greaterThan(recordValue, value);
              }
            },
          );
        });
      // 大于等于
      case api.SingleFilterOp.greaterThanOrEquals:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (value is DateTime) {
                int intValue = value.millisecondsSinceEpoch;
                return _greaterThan(recordValue, intValue) || recordValue == intValue;
              } else {
                return _greaterThan(recordValue, value) || recordValue == value;
              }
            },
          );
        });
      // 在列表中
      case api.SingleFilterOp.inList:
        return Filter.custom((record) {
          List? value = filter.get(0) as List?;
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) => value?.contains(recordValue) ?? false,
          );
        });
      // 不在列表中
      case api.SingleFilterOp.notInList:
        return Filter.custom((record) {
          List? value = filter.get(0) as List?;
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (null == value) return false;
              return !value.contains(recordValue);
            },
          );
        });
      // 匹配字符串
      case api.SingleFilterOp.matches:
        return Filter.custom((record) {
          String? value = filter.get(0) as String?;
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (null == value) return false;
              return RegExp(value).hasMatch(recordValue.toString());
            },
          );
        });
      // 字符串不匹配
      case api.SingleFilterOp.notMatches:
        return Filter.custom((record) {
          String? value = filter.get(0) as String?;
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (null == value) return true;
              return !(RegExp(value).hasMatch(recordValue.toString()));
            },
          );
        });
      // 匹配字符串开头
      case api.SingleFilterOp.matchesStart:
        return Filter.custom((record) {
          String? value = filter.get(0) as String?;
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (null == value) return false;
              return recordValue.toString().startsWith(value);
            },
          );
        });
      // 不匹配字符串开头
      case api.SingleFilterOp.notMatchesStart:
        return Filter.custom((record) {
          String? value = filter.get(0) as String?;
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (null == value) return true;
              return !recordValue.toString().startsWith(value);
            },
          );
        });
      // 时间段内
      case api.SingleFilterOp.between:
        return Filter.custom((RecordSnapshot record) {
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              int startInt = 0;
              int endInt = 0;
              if (filter.get(0) is DateTime) {
                startInt = (filter.get(0) as DateTime).millisecondsSinceEpoch;
              }
              if (filter.get(1) is DateTime) {
                endInt = (filter.get(1) as DateTime).millisecondsSinceEpoch;
              }
              if (null == recordValue) {
                return false;
              }
              if (recordValue is! int) {
                return false;
              }
              if (startInt == 0 && endInt == 0) {
                return false;
              }
              if (startInt != 0 && endInt != 0) {
                return recordValue < endInt && recordValue >= startInt;
              }
              if (startInt == 0) {
                return recordValue < endInt;
              } else {
                return recordValue > startInt;
              }
            },
          );
        });
      // 包含全部
      case api.SingleFilterOp.containsAll:
        return Filter.custom((record) {
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (null == recordValue) return false;
              List? filterValueList = filter.get(0) as List?;
              if (null == filterValueList) return false;
              List recordValueList = recordValue as List;
              for (var oneValue in filterValueList) {
                if (!recordValueList.contains(oneValue)) {
                  return false;
                }
              }
              return true;
            },
          );
        });
      case api.SingleFilterOp.containsOne:
        return Filter.custom((RecordSnapshot record) {
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) {
              if (null == recordValue) return false;
              List? filterValueList = filter.get(0) as List?;
              if (null == filterValueList) return false;
              List recordValueList = recordValue as List;
              for (var oneValue in filterValueList) {
                if (recordValueList.contains(oneValue)) {
                  return true;
                }
              }
              return false;
            },
          );
        });
      default:
        return Filter.equals(field, filter.get(0));
    }
  }

  Filter convertGroupFilter(api.GroupFilter filter) {
    List<api.Filter> children = filter.children;
    List<Filter> filters = [];
    for (api.Filter child in children) {
      filters.add(filterConvert(child));
    }
    if (filter.op == api.GroupFilterOp.and) {
      return Filter.and(filters);
    } else {
      return Filter.or(filters);
    }
  }
}

/// sembast数据库的排序转换器
class SembastSortConvertors extends api.SortConvertor<SortOrder> {
  SembastSortConvertors._();

  static SembastSortConvertors? _instance;

  static SembastSortConvertors get instance {
    _instance ??= SembastSortConvertors._();
    return _instance!;
  }

  @override
  Future<api.Sort?> from(SortOrder? value) async {
    if (null == value) return null;
    throw UnimplementedError();
  }

  @override
  Future<SortOrder?> to(api.Sort? value) async {
    if (null == value) return null;
    return SortOrder(value.field, value.op == api.SortOp.asc);
  }
}
