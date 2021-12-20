import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/hg_orm.dart';

/// 数值类型
class NumberAttributeConvertor<T extends num> extends AttributeConvertor<NumberAttribute, T> {
  NumberAttributeConvertor(AttributeConvertors parent) : super(parent);

  @override
  Future<T?> to(NumberAttribute? value, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    return value?.value as T?;
  }

  @override
  Future<NumberAttribute?> from(Object? value, {NumberAttribute? attribute, Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (null == attribute) return attribute;
    if (!TypeUtil.isThisType(value, T)) return attribute;
    attribute.valueTypeless = value;
    return attribute;
  }
}

/// 整型
class IntegerAttributeConvertor extends NumberAttributeConvertor<int> {
  IntegerAttributeConvertor(AttributeConvertors parent) : super(parent);
}

/// 浮点型
class FloatAttributeConvertor extends NumberAttributeConvertor<double> {
  FloatAttributeConvertor(AttributeConvertors parent) : super(parent);
}

class NumberListAttributeConvertor<T extends num> extends AttributeConvertor<NumberListAttribute, List<T>> {
  NumberListAttributeConvertor(AttributeConvertors parent) : super(parent);

  @override
  Future<List<T>?> to(NumberListAttribute? value, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (null == value) return null;
    if (value.isNull) return null;
    return value.value.map((e) => e as T).toList();
  }

  @override
  Future<NumberListAttribute?> from(Object? value, {NumberListAttribute? attribute, Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (null == attribute) return attribute;
    attribute.clear();
    if (null == value) return attribute;
    if (value is! List) return attribute;
    for (Object? one in value) {
      if (null == one) continue;
      if (!TypeUtil.isThisType(one, T)) continue;
      attribute.append(one as T);
    }
    return attribute;
  }
}

class IntegerListAttributeConvertor extends NumberListAttributeConvertor<int> {
  IntegerListAttributeConvertor(AttributeConvertors parent) : super(parent);
}

class FloatListAttributeConvertor extends NumberListAttributeConvertor<double> {
  FloatListAttributeConvertor(AttributeConvertors parent) : super(parent);
}