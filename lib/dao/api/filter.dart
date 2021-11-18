/// 数据库查询的过滤条件
abstract class HgFilter {
  /// 拷贝
  HgFilter clone();
}

/// 单个过滤条件
/// 值为List类型，用于适配不同操作符的元素个数
/// 如between操作服，操作元素是两个，分别放在值的第0位和第1位，
/// inList虽然是列表类型的条件，但是整个List条件只会放在第0位
/// 无论是几个元素的操作符，都要求所有值的类型要一致，包括List中的每一个元素。
class SingleHgFilter extends HgFilter {
  /// 字段名称 不可为空
  String field;

  /// 操作符 不可为空
  SingleFilterOp op;

  /// 值，可多个，集合类型值占一个位置
  final List<Object> _value = [];

  /// 值类型，集合类型为泛型类型
  Type? _valueType;

  SingleHgFilter({required this.field, this.op = SingleFilterOp.equals});

  /// 等于
  SingleHgFilter.equals({required this.field, required Object value}) : op = SingleFilterOp.equals {
    append(value);
  }

  /// 不等于
  SingleHgFilter.notEquals({required this.field, required Object value}) : op = SingleFilterOp.notEquals {
    append(value);
  }

  /// 为空
  SingleHgFilter.isNull({required this.field}) : op = SingleFilterOp.isNull;

  /// 非空
  SingleHgFilter.notNull({required this.field}) : op = SingleFilterOp.notNull;

  /// 小于
  SingleHgFilter.lessThan({required this.field, required Object value}) : op = SingleFilterOp.lessThan {
    append(value);
  }

  /// 小于等于
  SingleHgFilter.lessThanOrEquals({required this.field, required Object value}) : op = SingleFilterOp.lessThanOrEquals {
    append(value);
  }

  /// 大于
  SingleHgFilter.greaterThan({required this.field, required Object value}) : op = SingleFilterOp.greaterThan {
    append(value);
  }

  /// 大于等于
  SingleHgFilter.greaterThanOrEquals({required this.field, required Object value}) : op = SingleFilterOp.greaterThanOrEquals {
    append(value);
  }

  /// 在列表中(数据库中存储的值为单个，查询条件为多个)
  SingleHgFilter.inList({required this.field, required List value}) : op = SingleFilterOp.inList {
    appendList(value);
  }

  /// 不在列表中(数据库中存储的值为单个，查询条件为多个)
  SingleHgFilter.notInList({required this.field, required List value}) : op = SingleFilterOp.notInList {
    appendList(value);
  }

  /// 模糊匹配
  SingleHgFilter.matches({required this.field, required Object value}) : op = SingleFilterOp.matches {
    append(value);
  }

  /// 在区间内
  SingleHgFilter.between({required this.field, required Object start, required Object end}) : op = SingleFilterOp.between {
    append(start);
    append(end);
  }

  /// 包含全部(数据库中存储的值为多个，查询条件为多个)
  SingleHgFilter.containsAll({required this.field, required List value}) : op = SingleFilterOp.containsAll {
    appendList(value);
  }

  /// 至少包含一个(数据库中存储的值为多个，查询条件为多个)
  SingleHgFilter.containsOne({required this.field, required List value}) : op = SingleFilterOp.containsOne {
    appendList(value);
  }

  /// 获取值类型
  Type get valueType => _valueType ?? Object;

  /// 获取值
  List<Object> get value => _value;

  /// 想List类型的value中追加一个值，校验或存储值类型
  /// 如果追加的值是List类型，将调用appendList
  void append(Object value) {
    if (value is List) {
      appendList(value);
      return;
    }
    _valueType ??= value.runtimeType;
    assert("${value.runtimeType}" == "$_valueType");
    _value.add(value);
  }

  /// 设置List类型的value中的某个位置的值，校验设置的值类型是否符合
  void set(int index, Object value) {
    _valueType ??= value.runtimeType;
    assert("${value.runtimeType}" == "$_valueType");
    _value[index] = value;
  }

  /// 获取某个位置的值
  T get<T>(int index) {
    if (_valueType == null) {
      return _value[index] as T;
    }
    return _value[index] as T;
  }

  /// 追加一个List类型的值，会遍历值是否与当前值类型相符
  void appendList(List valueList) {
    for (Object value in valueList) {
      _valueType ??= value.runtimeType;
      assert("${value.runtimeType}" == "$_valueType");
    }
    _value.add(valueList);
  }

  /// 移除一个位置的值
  void removeAt(int index) {
    _value.removeAt(index);
  }

  /// 清空所有值，但不会清空值类型
  void removeAll(List<int> indexList) {
    for (int index in indexList) {
      removeAt(index);
    }
  }

  /// 清空所有值，并清空值类型
  void clear() {
    _value.clear();
    _valueType = null;
  }

  @override
  SingleHgFilter clone() {
    SingleHgFilter newSingleFilter = SingleHgFilter(field: field, op: op);
    // TODO 这是浅克隆
    newSingleFilter._value.addAll(value);
    newSingleFilter._valueType = _valueType;
    return newSingleFilter;
  }

  @override
  String toString() {
    return "$field${op.symbol}$_value($valueType)";
  }
}

/// 组合过滤条件
class GroupHgFilter extends HgFilter {
  /// 组合操作服
  GroupFilterOp op;

  /// 子条件
  late List<HgFilter> children;

  GroupHgFilter({
    this.op = GroupFilterOp.and,
    List<HgFilter>? children,
  }) {
    this.children = children ?? [];
  }

  /// 与
  GroupHgFilter.and(List<HgFilter>? children) : op = GroupFilterOp.and {
    this.children = children ?? [];
  }

  /// 或
  GroupHgFilter.or(List<HgFilter>? children) : op = GroupFilterOp.or {
    this.children = children ?? [];
  }

  @override
  HgFilter clone() {
    GroupHgFilter newGroupFilter = GroupHgFilter(op: op);
    for (HgFilter child in children) {
      newGroupFilter.children.add(child.clone());
    }
    return newGroupFilter;
  }

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

/// 过滤条件操作符的抽象
abstract class FilterOp {
  /// 操作服名称
  final String title;

  /// 操作服符号
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
  final int valueNumbers;

  const SingleFilterOp._(String title, String symbol, [this.valueNumbers = 1]) : super._(title, symbol);

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
  static const SingleFilterOp isNull = SingleFilterOp._("为空", isNullSymbol, 0);
  static const SingleFilterOp notNull = SingleFilterOp._("非空", notNullSymbol, 0);
  static const SingleFilterOp lessThan = SingleFilterOp._("小于", lessThanSymbol);
  static const SingleFilterOp lessThanOrEquals = SingleFilterOp._("小于等于", lessThanOrEqualsSymbol);
  static const SingleFilterOp greaterThan = SingleFilterOp._("大于", greaterThanSymbol);
  static const SingleFilterOp greaterThanOrEquals = SingleFilterOp._("大于等于", greaterThanOrEqualsSymbol);
  static const SingleFilterOp inList = SingleFilterOp._("在范围内", inListSymbol);
  static const SingleFilterOp notInList = SingleFilterOp._("不在范围内", inListSymbol);
  static const SingleFilterOp matches = SingleFilterOp._("匹配", matchesSymbol);
  static const SingleFilterOp between = SingleFilterOp._("在区间内", betweenSymbol, 2);
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

/// 条件组操作符
class GroupFilterOp extends FilterOp {
  const GroupFilterOp._(String title, String symbol) : super._(title, symbol);

  static const _andSymbol = "and";
  static const _orSymbol = "or";

  static const GroupFilterOp and = GroupFilterOp._("并且", _andSymbol);
  static const GroupFilterOp or = GroupFilterOp._("或者", _orSymbol);

  static const List<GroupFilterOp> list = [and, or];

  static const Map<String, GroupFilterOp> map = {_andSymbol: and, _orSymbol: or};
}
