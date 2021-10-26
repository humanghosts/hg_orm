import 'package:hg_entity/attribute/attribute_custom.dart';
import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/filter.dart';
import 'package:hg_orm/hg_orm.dart';

abstract class FilterValue implements CustomValue {
  Filter? asFilter();
}

class SingleFilterValue implements FilterValue {
  SingleFilter? filter;

  @override
  bool get isNull => null == filter;

  @override
  void merge(CustomValue value) {
    if (value is SingleFilterValue) {
      filter = value.filter;
    }
  }

  @override
  Object? toMap() {
    SingleFilter? filter = this.filter;
    if (null == filter) return null;
    List<Object> filterValueList = filter.value;
    List<Object> value = filterValueList;
    if (ConstructorCache.containsKey(filter.valueType)) {
      Type rawType = ConstructorCache.getRawType(filter.valueType);
      value = <Object>[];
      for (Object filterValue in filterValueList) {
        if (rawType == DataModel) {
          if (filterValue is List) {
            value.add(filterValue.map((e) => (e as DataModel).id.value).toList());
          } else {
            value.add((filterValue as DataModel).id.value);
          }
        } else if (rawType == SimpleModel) {
          if (filterValue is List) {
            value.add(filterValue.map((e) => Convert.getModelValue(e as SimpleModel)).toList());
          } else {
            value.add(Convert.getModelValue(filterValue as SimpleModel));
          }
        } else if (rawType == CustomValue) {
          if (filterValue is List) {
            List customValueList = [];
            for (CustomValue customValue in filterValue) {
              Object? mapValue = customValue.toMap();
              if (null == mapValue) {
                continue;
              }
              customValueList.add(mapValue);
            }
            value.add(customValueList);
          } else {
            Object? mapValue = (filterValue as CustomValue).toMap();
            if (null == mapValue) {
              continue;
            }
            value.add(mapValue);
          }
        }
      }
    }

    return {
      "field": filter.field,
      "op": filter.op.symbol,
      "value": value,
      "valueType": filter.valueType.toString(),
    };
  }

  @override
  Future<void> fromMap(Object value) async {
    if (value is! Map) {
      return;
    }
    // 字段
    String field = value["field"];
    // 操作符
    String opSymbol = value["op"];
    SingleFilterOp op = SingleFilterOp.map[opSymbol]!;
    // 过滤器
    SingleFilter filter = SingleFilter(field: field, op: op);
    this.filter = filter;
    // 值列表
    List mapValueList = value["value"];
    if (mapValueList.isEmpty) {
      return;
    }
    // 值类型
    String valueType = value["valueType"];
    // 实体类型
    if (ConstructorCache.containsKeyStr(valueType)) {
      // 原始值类型
      Type rawType = ConstructorCache.getRawTypeStr(valueType);
      // 遍历所有值
      for (Object mapValue in mapValueList) {
        // 数据模型
        if (rawType == DataModel) {
          DataDao dao = DaoCache.getStr(valueType);
          if (mapValue is List) {
            List<String> idList = mapValue.map((e) => e.toString()).toList();
            filter.appendList(await dao.findByIDList(idList));
          } else {
            Object? result = await dao.findByID(mapValue as String);
            if (null != result) {
              // result为空，说明这个id的数据被删除了，不用管了，相当于惰性删除
              filter.append(result);
            }
          }
        }
        // 简单模型
        else if (rawType == SimpleModel) {
          if (mapValue is List) {
            List<SimpleModel> oneValueAsList = [];
            for (Object oneMapValue in mapValue) {
              oneValueAsList.add(await Convert.setModelValue(ConstructorCache.getStr(valueType), oneMapValue) as SimpleModel);
            }
            filter.appendList(oneValueAsList);
          } else {
            filter.append(await Convert.setModelValue(ConstructorCache.getStr(valueType), mapValue) as SimpleModel);
          }
        }
        // 自定义值类型
        else if (rawType == CustomValue) {
          if (mapValue is List) {
            List<CustomValue> oneValueAsList = [];
            for (Object oneMapValue in mapValue) {
              CustomValue customValue = ConstructorCache.getStr(valueType);
              await customValue.fromMap(oneMapValue);
              oneValueAsList.add(customValue);
            }
            filter.appendList(oneValueAsList);
          } else {
            CustomValue customValue = ConstructorCache.getStr(valueType);
            await customValue.fromMap(mapValue);
            filter.append(customValue);
          }
        }
        // 其它实体类型
        else {
          if (mapValue is List) {
            filter.appendList(mapValue);
          } else {
            filter.append(mapValue);
          }
        }
      }
    }
    // 其它类型
    else {
      for (Object oneValue in mapValueList) {
        if (oneValue is List) {
          filter.appendList(oneValue);
        } else {
          filter.append(oneValue);
        }
      }
    }
  }

  @override
  SingleFilterValue clone() {
    SingleFilterValue newFilterValue = SingleFilterValue();
    newFilterValue.filter = filter?.clone();
    return newFilterValue;
  }

  @override
  SingleFilter? asFilter() {
    return filter;
  }
}

class GroupFilterValue implements FilterValue {
  GroupFilterOp op = GroupFilterOp.and;
  final List<FilterValue> filters = [];

  @override
  bool get isNull => filters.isEmpty;

  @override
  void merge(CustomValue value) {
    if (value is GroupFilterValue) {
      op = value.op;
      filters.clear();
      filters.addAll(value.filters);
    }
  }

  @override
  Object? toMap() {
    if (filters.isEmpty) return null;
    List<Map> childrenMap = [];
    for (FilterValue child in filters) {
      String type = child.runtimeType.toString();
      Object? value = child.toMap();
      if (value == null) {
        continue;
      }
      childrenMap.add({
        "type": type,
        "value": value,
      });
    }
    return {
      "op": op.symbol,
      "children": childrenMap,
    };
  }

  @override
  Future<void> fromMap(Object value) async {
    if (value is! Map) {
      return;
    }
    String opSymbol = value["op"];
    op = GroupFilterOp.map[opSymbol]!;
    List children = value["children"];
    filters.clear();
    for (Map child in children) {
      String type = child["type"];
      Map value = child["value"] as Map;
      FilterValue customValue = ConstructorCache.getStr(type);
      await customValue.fromMap(value);
      filters.add(customValue);
    }
  }

  @override
  GroupFilterValue clone() {
    GroupFilterValue newFilterValue = GroupFilterValue();
    newFilterValue.op = op;
    for (FilterValue filter in filters) {
      newFilterValue.filters.add(filter.clone() as FilterValue);
    }
    return newFilterValue;
  }

  @override
  GroupFilter? asFilter() {
    GroupFilter groupFilter = GroupFilter(op: op);
    for (FilterValue child in filters) {
      Filter? filter = child.asFilter();
      if (null != filter) {
        groupFilter.children.add(filter);
      }
    }
    return groupFilter;
  }
}
