import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/hg_orm.dart';

/// 字符串类型
class StringAttributeConvertor extends AttributeConvertor<StringAttribute, String> {
  StringAttributeConvertor(AttributeConvertors parent) : super(parent);

  @override
  Future<String?> to(StringAttribute? value, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    return value?.value;
  }

  @override
  Future<StringAttribute?> from(Object? value, {StringAttribute? attribute, Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (null == attribute) return attribute;
    if (!TypeUtil.isThisType(value, String)) return attribute;
    attribute.valueTypeless = value;
    return attribute;
  }
}

class StringListAttributeConvertor extends AttributeConvertor<StringListAttribute, List<String>> {
  StringListAttributeConvertor(AttributeConvertors parent) : super(parent);

  @override
  Future<List<String>?> to(StringListAttribute? value, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (null == value) return null;
    if (value.isNull) return null;
    return value.value.map((e) => e.toString()).toList();
  }

  @override
  Future<StringListAttribute?> from(Object? value, {StringListAttribute? attribute, Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (null == attribute) return attribute;
    attribute.clear();
    if (null == value) return attribute;
    if (value is! List) return attribute;
    for (Object? one in value) {
      if (null == one) continue;
      if (!TypeUtil.isThisType(one, String)) continue;
      attribute.append(one as String);
    }
    return attribute;
  }
}
