import 'package:flutter/cupertino.dart';
import 'package:hg_orm/dao/api/export.dart';
import 'package:sembast/sembast.dart';

@immutable
class SembastConvertor extends Convertor {
  const SembastConvertor();

  @override
  Filter filterConvert(HgFilter filter) {
    if (filter is SingleHgFilter) {
      return convertSingleFilter(filter);
    } else {
      return convertGroupFilter(filter as GroupHgFilter);
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
  Filter convertSingleFilter(SingleHgFilter filter) {
    String field = filter.field;
    FilterOp op = filter.op;
    switch (op) {
      // 相等
      case SingleFilterOp.equals:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            // 如果value为null null as true
            nullAsTrue: value == null,
            isMatch: (recordValue) => recordValue == value,
          );
        });
      // 不等
      case SingleFilterOp.notEquals:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            // 如果value为null null as true
            nullAsTrue: value != null,
            isMatch: (recordValue) => recordValue != value,
          );
        });
      // 为空
      case SingleFilterOp.isNull:
        return Filter.custom((record) {
          return getMatch(
            record: record,
            field: field,
            nullAsTrue: true,
            isMatch: (recordValue) => recordValue == null,
          );
        });
      // 非空
      case SingleFilterOp.notNull:
        return Filter.custom((record) {
          return getMatch(
            record: record,
            field: field,
            nullAsTrue: false,
            isMatch: (recordValue) => recordValue != null,
          );
        });
      // 小于
      case SingleFilterOp.lessThan:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) => _lessThan(recordValue, value),
          );
        });
      // 小于等于
      case SingleFilterOp.lessThanOrEquals:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) => _lessThan(recordValue, value) || recordValue == value,
          );
        });
      // 大于
      case SingleFilterOp.greaterThan:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) => _greaterThan(recordValue, value),
          );
        });
      // 大于等于
      case SingleFilterOp.greaterThanOrEquals:
        return Filter.custom((record) {
          Object? value = filter.get(0);
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) => _greaterThan(recordValue, value) || recordValue == value,
          );
        });
      // 在列表中
      case SingleFilterOp.inList:
        return Filter.custom((record) {
          List? value = filter.get(0) as List?;
          return getMatch(
            record: record,
            field: field,
            isMatch: (recordValue) => value?.contains(recordValue) ?? false,
          );
        });
      // 不在列表中
      case SingleFilterOp.notInList:
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
      case SingleFilterOp.matches:
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
      // 时间段内
      case SingleFilterOp.between:
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
      case SingleFilterOp.containsAll:
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
      case SingleFilterOp.containsOne:
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

  Filter convertGroupFilter(GroupHgFilter filter) {
    List<HgFilter> children = filter.children;
    List<Filter> filters = [];
    for (HgFilter child in children) {
      filters.add(filterConvert(child));
    }
    if (filter.op == GroupFilterOp.and) {
      return Filter.and(filters);
    } else {
      return Filter.or(filters);
    }
  }

  @override
  SortOrder sortConvert(HgSort sort) {
    return SortOrder(sort.field, sort.op == SortOp.asc);
  }
}
