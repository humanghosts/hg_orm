import 'package:hg_entity/attribute/attribute_custom.dart';
import 'package:hg_orm/dao/api/sort.dart';

class HgSortValue implements CustomValue {
  HgSort? sort;

  @override
  bool get isNull => sort == null;

  @override
  void merge(CustomValue value) {
    if (value is HgSortValue) {
      sort = value.sort;
    }
  }

  @override
  Object? toMap() {
    HgSort? sort = this.sort;
    if (null == sort) return null;
    return {
      "field": sort.field,
      "op": sort.op.symbol,
    };
  }

  @override
  Future<void> fromMap(Object value) async {
    if (value is Map) {
      sort = HgSort(
        field: value["field"],
        op: SortOp.map[value["op"]]!,
      );
    }
  }

  @override
  HgSortValue clone() {
    HgSortValue sortValue = HgSortValue();
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
