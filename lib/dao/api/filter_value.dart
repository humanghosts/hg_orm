import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/export.dart';

import 'convertor.dart';
import 'dao.dart';
import 'filter.dart';

/// 过滤条件的custom_value类型，用于model的attribute的value
abstract class FilterValue implements CustomValue {
  Filter? asFilter();
}

/// 单个过滤条件
class SingleFilterValue implements FilterValue {
  SingleFilter? filter;

  SingleFilterValue({this.filter});

  @override
  bool get isNull => null == filter;

  @override
  SingleFilterValue merge(CustomValue value) {
    if (value is SingleFilterValue) {
      filter = value.filter;
    }
    return this;
  }

  @override
  Object? toMap() {
    SingleFilter? filter = this.filter;
    if (null == filter) return null;
    List<Object> filterValueList = filter.value;
    List<Object> value = filterValueList;
    if (ConstructorCache.containsKey(filter.valueType)) {
      Object obj = ConstructorCache.get(filter.valueType);
      value = <Object>[];
      for (Object filterValue in filterValueList) {
        if (obj is DataModel) {
          if (filterValue is List) {
            value.add(filterValue.map((e) => (e as DataModel).id.value).toList());
          } else {
            value.add((filterValue as DataModel).id.value);
          }
        } else if (obj is SimpleModel) {
          if (filterValue is List) {
            value.add(filterValue.map((e) => Convertor.getModelValue(e as SimpleModel, null, true, true)).toList());
          } else {
            value.add(Convertor.getModelValue(filterValue as SimpleModel, null, true, true));
          }
        } else if (obj is CustomValue) {
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

  /// TODO 这里的fromMap要查数据，但是没有事务，可能是个隐患
  /// 事务定义在orm里面，fromMap定义在entity里面，使用fromMap都是基于超类的定义，事务暂时加不上
  @override
  Future<SingleFilterValue> fromMap(Object value) async {
    if (value is! Map) {
      return this;
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
      return this;
    }
    // 值类型
    String valueType = value["valueType"];
    // 实体类型
    if (ConstructorCache.containsKeyStr(valueType)) {
      // 原始值类型
      Object obj = ConstructorCache.getByStr(valueType);
      // 遍历所有值
      for (Object mapValue in mapValueList) {
        // 数据模型
        if (obj is DataModel) {
          DataDao<DataModel> dao = DaoCache.getByStr(valueType) as DataDao<DataModel>;
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
        else if (obj is SimpleModel) {
          if (mapValue is List) {
            List<SimpleModel> oneValueAsList = [];
            for (Object oneMapValue in mapValue) {
              oneValueAsList.add(await Convertor.setModelValue(ConstructorCache.getByStr(valueType), oneMapValue, null, true, true) as SimpleModel);
            }
            filter.appendList(oneValueAsList);
          } else {
            filter.append(await Convertor.setModelValue(ConstructorCache.getByStr(valueType), mapValue, null, true, true) as SimpleModel);
          }
        }
        // 自定义值类型
        else if (obj is CustomValue) {
          if (mapValue is List) {
            List<CustomValue> oneValueAsList = [];
            for (Object oneMapValue in mapValue) {
              CustomValue customValue = ConstructorCache.getByStr(valueType);
              await customValue.fromMap(oneMapValue);
              oneValueAsList.add(customValue);
            }
            filter.appendList(oneValueAsList);
          } else {
            CustomValue customValue = ConstructorCache.getByStr(valueType);
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
    return this;
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

  @override
  String toString() {
    if (null == filter) {
      return "";
    }
    return filter.toString();
  }
}

/// 多个过滤条件
class GroupFilterValue implements FilterValue {
  GroupFilterOp op = GroupFilterOp.and;
  late List<FilterValue> filters;

  GroupFilterValue({this.op = GroupFilterOp.and, List<FilterValue>? filters}) {
    this.filters = filters ?? [];
  }

  @override
  bool get isNull => filters.isEmpty;

  @override
  GroupFilterValue merge(CustomValue value) {
    if (value is GroupFilterValue) {
      op = value.op;
      filters.clear();
      filters.addAll(value.filters);
    }
    return this;
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
  Future<GroupFilterValue> fromMap(Object value) async {
    if (value is! Map) {
      return this;
    }
    String opSymbol = value["op"];
    op = GroupFilterOp.map[opSymbol]!;
    List children = value["children"];
    filters.clear();
    for (Map child in children) {
      String type = child["type"];
      Map value = child["value"] as Map;
      FilterValue customValue = ConstructorCache.getByStr(type);
      await customValue.fromMap(value);
      filters.add(customValue);
    }
    return this;
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

  @override
  String toString() {
    if (filters.isEmpty) {
      return "${op.title}:[]";
    }
    StringBuffer sb = StringBuffer();
    sb.writeln("${op.title}:[");
    for (var child in filters) {
      sb.writeln("  ${child.toString()},");
    }
    sb.write("]");
    return sb.toString();
  }
}
