abstract class Filter {}

class SingleFilter extends Filter {
  /// 字段名称 不可为空
  String field;

  /// 操作符 不可为空
  SingleFilterOp op;

  /// 值，可多个
  final List<Object> _value = [];

  Type? _valueType;

  SingleFilter({required this.field, this.op = SingleFilterOp.equals});

  SingleFilter.equals({required this.field, required Object value}) : op = SingleFilterOp.equals {
    appendValue(value);
  }

  SingleFilter.notEquals({required this.field, required Object value}) : op = SingleFilterOp.notEquals {
    appendValue(value);
  }

  SingleFilter.isNull({required this.field}) : op = SingleFilterOp.isNull;

  SingleFilter.notNull({required this.field}) : op = SingleFilterOp.notNull;

  SingleFilter.lessThan({required this.field, required Object value}) : op = SingleFilterOp.lessThan {
    appendValue(value);
  }

  SingleFilter.lessThanOrEquals({required this.field, required Object value}) : op = SingleFilterOp.lessThanOrEquals {
    appendValue(value);
  }

  SingleFilter.greaterThan({required this.field, required Object value}) : op = SingleFilterOp.greaterThan {
    appendValue(value);
  }

  SingleFilter.greaterThanOrEquals({required this.field, required Object value})
      : op = SingleFilterOp.greaterThanOrEquals {
    appendValue(value);
  }

  SingleFilter.inList({required this.field, required List value}) : op = SingleFilterOp.inList {
    appendValue(value);
  }

  SingleFilter.notInList({required this.field, required List value}) : op = SingleFilterOp.notInList {
    appendValue(value);
  }

  SingleFilter.matches({required this.field, required Object value}) : op = SingleFilterOp.matches {
    appendValue(value);
  }

  SingleFilter.between({required this.field, required Object start, required Object end})
      : op = SingleFilterOp.between {
    appendValue(start);
    appendValue(end);
  }

  SingleFilter.containsAll({required this.field, required List value}) : op = SingleFilterOp.containsAll {
    appendValue(value);
  }

  SingleFilter.containsOne({required this.field, required List value}) : op = SingleFilterOp.containsOne {
    appendValue(value);
  }

  Type get valueType => _valueType ?? Object;

  List<Object> get value => _value;

  void appendValue(Object value) {
    _valueType ??= value.runtimeType;
    if (value.runtimeType != _valueType) {
      return;
    }
    _value.add(value);
  }

  void appendAll(List<Object> valueList) {
    for (Object value in valueList) {
      appendValue(value);
    }
  }

  void remove(Object value) {
    _value.remove(value);
  }

  void removeAll(List<Object> valueList) {
    for (Object value in valueList) {
      remove(value);
    }
  }

  @override
  String toString() {
    return "$field${op.symbol}$_value($valueType)";
  }
}

class GroupFilter extends Filter {
  GroupFilterOp op;
  late List<Filter> children;

  GroupFilter({
    this.op = GroupFilterOp.and,
    this.children = const [],
  });

  GroupFilter.and(this.children) : op = GroupFilterOp.and;

  GroupFilter.or(this.children) : op = GroupFilterOp.or;

  /// TODO test
  @override
  String toString() {
    if (children.isEmpty) {
      return "${op.title}:[]";
    }
    StringBuffer sb = StringBuffer();
    sb.writeln("${op.title}:[");
    for (var child in children) {
      sb.writeln("  ${child.toString()},");
    }
    sb.write("]");
    return sb.toString();
  }
}

abstract class FilterOp {
  final String title;
  final String symbol;

  const FilterOp._(this.title, this.symbol);
}

/// 添加操作符步骤
/// 1. OP类操作
///   1.1 添加符号
///   1.2 添加常量
///   1.3 添加到list和map中
/// 2. Filter类中添加命名构造函数
/// 3. 不同数据库的convert类中，添加操作符转换
class SingleFilterOp extends FilterOp {
  const SingleFilterOp._(String title, String symbol) : super._(title, symbol);

  static const equalsSymbol = "=";
  static const notEqualsSymbol = "!=";
  static const isNullSymbol = "isNull";
  static const notNullSymbol = "notNull";
  static const lessThanSymbol = "<";
  static const lessThanOrEqualsSymbol = "<=";
  static const greaterThanSymbol = ">";
  static const greaterThanOrEqualsSymbol = ">=";
  static const inListSymbol = "in";
  static const notInListSymbol = "notin";
  static const matchesSymbol = "matches";
  static const betweenSymbol = "between";
  static const containsAllSymbol = "containsAll";
  static const containsOneSymbol = "containsOne";

  static const SingleFilterOp equals = SingleFilterOp._("等于", equalsSymbol);
  static const SingleFilterOp notEquals = SingleFilterOp._("不等于", notEqualsSymbol);
  static const SingleFilterOp isNull = SingleFilterOp._("为空", isNullSymbol);
  static const SingleFilterOp notNull = SingleFilterOp._("非空", notNullSymbol);
  static const SingleFilterOp lessThan = SingleFilterOp._("小于", lessThanSymbol);
  static const SingleFilterOp lessThanOrEquals = SingleFilterOp._("小于等于", lessThanOrEqualsSymbol);
  static const SingleFilterOp greaterThan = SingleFilterOp._("大于", greaterThanSymbol);
  static const SingleFilterOp greaterThanOrEquals = SingleFilterOp._("大于等于", greaterThanOrEqualsSymbol);
  static const SingleFilterOp inList = SingleFilterOp._("在范围内", inListSymbol);
  static const SingleFilterOp notInList = SingleFilterOp._("不在范围内", inListSymbol);
  static const SingleFilterOp matches = SingleFilterOp._("匹配", matchesSymbol);
  static const SingleFilterOp between = SingleFilterOp._("在区间内", betweenSymbol);
  static const SingleFilterOp containsAll = SingleFilterOp._("包含全部", containsAllSymbol);
  static const SingleFilterOp containsOne = SingleFilterOp._("至少包含一个", containsOneSymbol);

  static const List<SingleFilterOp> list = [
    equals,
    notEquals,
    isNull,
    notNull,
    lessThan,
    lessThanOrEquals,
    greaterThan,
    greaterThanOrEquals,
    inList,
    notInList,
    matches,
    between,
    containsAll,
    containsOne,
  ];

  static const Map<String, SingleFilterOp> map = {
    equalsSymbol: equals,
    notEqualsSymbol: notEquals,
    isNullSymbol: isNull,
    notNullSymbol: notNull,
    lessThanSymbol: lessThan,
    lessThanOrEqualsSymbol: lessThanOrEquals,
    greaterThanSymbol: greaterThan,
    greaterThanOrEqualsSymbol: greaterThanOrEquals,
    inListSymbol: inList,
    notInListSymbol: notInList,
    matchesSymbol: matches,
    betweenSymbol: between,
    containsAllSymbol: containsAll,
    containsOneSymbol: containsOne,
  };
}

class GroupFilterOp extends FilterOp {
  const GroupFilterOp._(String title, String symbol) : super._(title, symbol);

  static const _andSymbol = "and";
  static const _orSymbol = "or";

  static const GroupFilterOp and = GroupFilterOp._("并且", _andSymbol);
  static const GroupFilterOp or = GroupFilterOp._("或者", _orSymbol);

  static const List<GroupFilterOp> list = [and, or];

  static const Map<String, GroupFilterOp> map = {_andSymbol: and, _orSymbol: or};
}
