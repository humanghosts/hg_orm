import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/hg_orm.dart';

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
  Future<Object?> toMap({Map<String, Object?>? args}) async {
    Sort? sort = this.sort;
    if (null == sort) return null;
    return {
      "field": sort.field,
      "op": sort.op.symbol,
    };
  }

  @override
  Future<SortValue> fromMap(Object? value, {Map<String, Object?>? args}) async {
    if (value is Map) {
      sort = Sort(
        field: value["field"],
        op: SortOp.map[value["op"]]!,
      );
    }
    return this;
  }

  @override
  SortValue clone() => SortValue(sort: sort?.clone());

  @override
  String toString() => sort.toString();
}
