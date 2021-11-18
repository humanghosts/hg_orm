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

  Filter convertSingleFilter(SingleHgFilter filter) {
    String field = filter.field;
    FilterOp op = filter.op;
    List<Object> valueList = filter.value;
    switch (op) {
      case SingleFilterOp.equals:
        return Filter.equals(field, valueList[0]);
      case SingleFilterOp.notEquals:
        return Filter.notEquals(field, valueList[0]);
      case SingleFilterOp.isNull:
        return Filter.isNull(field);
      case SingleFilterOp.notNull:
        return Filter.notNull(field);
      case SingleFilterOp.lessThan:
        return Filter.lessThan(field, valueList[0]);
      case SingleFilterOp.lessThanOrEquals:
        return Filter.lessThanOrEquals(field, valueList[0]);
      case SingleFilterOp.greaterThan:
        return Filter.greaterThan(field, valueList[0]);
      case SingleFilterOp.greaterThanOrEquals:
        return Filter.greaterThanOrEquals(field, valueList[0]);
      case SingleFilterOp.inList:
        return Filter.inList(field, valueList[0] as List);
      case SingleFilterOp.notInList:
        return Filter.not(Filter.inList(field, valueList[0] as List));
      case SingleFilterOp.matches:
        return Filter.matches(field, valueList[0].toString());
      case SingleFilterOp.between:
        return Filter.custom((RecordSnapshot record) {
          Map<String, Object?> map = record.value;
          if (!map.containsKey(field)) {
            return false;
          }
          DateTime start = valueList[0] as DateTime;
          DateTime end = valueList[1] as DateTime;
          Object? value = map[field];
          if (null == value) {
            return false;
          }
          if (value is! int) {
            return false;
          }
          DateTime dateTimeValue = DateTime.fromMicrosecondsSinceEpoch(value);
          if (start.isBefore(dateTimeValue) && end.isAfter(dateTimeValue)) {
            return true;
          }
          return false;
        });
      case SingleFilterOp.containsAll:
        return Filter.custom((RecordSnapshot record) {
          Map<String, Object?> map = record.value;
          if (!map.containsKey(field)) {
            return false;
          }
          List recordValueList = map[field] as List;
          List filterValueList = valueList[0] as List;
          for (var oneValue in filterValueList) {
            if (!recordValueList.contains(oneValue)) {
              return false;
            }
          }
          return true;
        });
      case SingleFilterOp.containsOne:
        return Filter.custom((RecordSnapshot record) {
          Map<String, Object?> map = record.value;
          if (!map.containsKey(field)) {
            return false;
          }
          List recordValueList = map[field] as List;
          List filterValueList = valueList[0] as List;
          for (var oneValue in filterValueList) {
            if (recordValueList.contains(oneValue)) {
              return true;
            }
          }
          return false;
        });
      default:
        return Filter.equals(field, valueList[0]);
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
