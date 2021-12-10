import 'package:hg_entity/attribute/attribute_custom.dart';
import 'package:hg_orm/dao/api/sort.dart';

class SortValue implements CustomValue {
  Sort? sort;

  SortValue({this.sort});

  @override
  bool get isNull => sort == null;

  @override
  SortValue merge(CustomValue value) {
    if (value is SortValue) {
      sort = value.sort;
    }
    return this;
  }

  @override
  Object? toMap() {
    Sort? sort = this.sort;
    if (null == sort) return null;
    return {
      "field": sort.field,
      "op": sort.op.symbol,
    };
  }

  @override
  Future<SortValue> fromMap(Object value) async {
    if (value is Map) {
      sort = Sort(
        field: value["field"],
        op: SortOp.map[value["op"]]!,
      );
    }
    return this;
  }

  @override
  SortValue clone() {
    SortValue sortValue = SortValue();
    Object? map = toMap();
    if (null != map) {
      sortValue.fromMap(map);
    }
    return sortValue;
  }

  @override
  String toString() {
    return sort.toString();
  }
}
