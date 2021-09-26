import 'package:hg_orm/dao/api/export.dart' as hg;
import 'package:sembast/sembast.dart';

class SembastConvert extends hg.Convert {
  @override
  Filter filterConvert(hg.Filter filter) {
    if (filter is hg.SingleFilter) {
      return convertSingleFilter(filter);
    } else {
      return convertGroupFilter(filter as hg.GroupFilter);
    }
  }

  Filter convertSingleFilter(hg.SingleFilter filter) {
    String field = filter.field;
    hg.FilterOp op = filter.op;
    List<Object> valueList = filter.value;
    switch (op) {
      case hg.SingleFilterOp.equals:
        return Filter.equals(field, valueList[0]);
      case hg.SingleFilterOp.notEquals:
        return Filter.notEquals(field, valueList[0]);
      case hg.SingleFilterOp.isNull:
        return Filter.isNull(field);
      case hg.SingleFilterOp.notNull:
        return Filter.notNull(field);
      case hg.SingleFilterOp.lessThan:
        return Filter.lessThan(field, valueList[0]);
      case hg.SingleFilterOp.lessThanOrEquals:
        return Filter.lessThanOrEquals(field, valueList[0]);
      case hg.SingleFilterOp.greaterThan:
        return Filter.greaterThan(field, valueList[0]);
      case hg.SingleFilterOp.greaterThanOrEquals:
        return Filter.greaterThanOrEquals(field, valueList[0]);
      case hg.SingleFilterOp.inList:
        return Filter.inList(field, valueList[0] as List);
      case hg.SingleFilterOp.matches:
        return Filter.matches(field, valueList[0].toString());
      case hg.SingleFilterOp.between:
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
      case hg.SingleFilterOp.containsAll:
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
      case hg.SingleFilterOp.containsOne:
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

  Filter convertGroupFilter(hg.GroupFilter filter) {
    List<hg.Filter> children = filter.children;
    List<Filter> filters = [];
    for (hg.Filter child in children) {
      filters.add(filterConvert(child));
    }
    if (filter.op == hg.GroupFilterOp.and) {
      return Filter.and(filters);
    } else {
      return Filter.or(filters);
    }
  }

  @override
  SortOrder sortConvert(hg.Sort sort) {
    return SortOrder(sort.field, sort.op == hg.SortOp.asc);
  }
}
