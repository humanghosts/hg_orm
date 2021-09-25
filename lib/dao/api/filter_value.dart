import 'package:hg_entity/attribute/attribute_custom.dart';
import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/dao/api/filter.dart';

class SingleFilterValue implements CustomValue {
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
  Object? toMap() => asMap(filter);

  @override
  void fromMap(Object value) {
    if (value is Map) {
      filter = asFilter(value);
    }
  }

  @override
  SingleFilterValue clone() {
    Object? map = toMap();
    SingleFilterValue newFilterValue = SingleFilterValue();
    if (null != map) {
      newFilterValue.fromMap(map as Map);
    }
    return newFilterValue;
  }

  static Object? asMap(SingleFilter? filter) {
    if (null == filter) return null;
    return {
      "field": filter.field,
      "op": filter.op.symbol,
      "value": filter.value,
      "valueType": filter.valueType,
    };
  }

  static SingleFilter asFilter(Map map) {
    String field = map["field"];
    String opSymbol = map["op"];
    SingleFilterOp op = SingleFilterOp.map[opSymbol]!;
    SingleFilter filter = SingleFilter(field: field, op: op);
    filter.appendAll(map["value"]);
    return filter;
  }
}

class GroupFilterValue implements CustomValue {
  GroupFilter? filters;

  @override
  bool get isNull {
    GroupFilter? filters = this.filters;
    return filters == null || filters.children.isEmpty;
  }

  @override
  void merge(CustomValue value) {
    if (value is GroupFilterValue) {
      filters = value.filters;
    }
  }

  @override
  Object? toMap() => asMap(filters);

  @override
  void fromMap(Object value) {
    if (value is Map) {
      filters = asFilter(value);
    }
  }

  @override
  GroupFilterValue clone() {
    Object? map = toMap();
    GroupFilterValue newFilterValue = GroupFilterValue();
    if (null != map) {
      newFilterValue.fromMap(map as Map);
    }
    return newFilterValue;
  }

  static Object? asMap(GroupFilter? filters) {
    if (null == filters) return null;
    List<Map> childrenMap = [];
    for (Filter child in filters.children) {
      String type;
      Object? value;
      if (child is SingleFilter) {
        type = "SingleFilter";
        value = SingleFilterValue.asMap(child);
      } else if (child is GroupFilter) {
        type = "GroupFilter";
        value = GroupFilterValue.asMap(child);
      } else {
        continue;
      }
      if (value == null) {
        continue;
      }
      childrenMap.add({
        "type": type,
        "value": value,
      });
    }
    return {
      "op": filters.op.symbol,
      "children": childrenMap,
    };
  }

  static GroupFilter asFilter(Map map) {
    String opSymbol = map["op"];
    List<Map> children = map["children"];
    GroupFilterOp op = GroupFilterOp.map[opSymbol]!;
    GroupFilter filters = GroupFilter(op: op);
    for (Map child in children) {
      String type = child["type"];
      Map value = child["value"] as Map;
      if (type == "SingleFilter") {
        filters.children.add(SingleFilterValue.asFilter(value));
      }
      if (type == "GroupFilter") {
        filters.children.add(GroupFilterValue.asFilter(value));
      }
    }
    return filters;
  }
}
