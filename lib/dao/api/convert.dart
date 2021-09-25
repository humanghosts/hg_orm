import 'package:hg_entity/hg_entity.dart';

import 'filter.dart';
import 'sort.dart';

abstract class Convert {
  /// api的通用型filter转换为仓库特性过滤
  Object filterConvert(Filter filter);

  /// api的通用型sort转换为仓库特型排序
  Object sortConvert(Sort sort);

  /// model转换为仓库的数据类型
  Object modelConvert(Model model);

  /// 仓库的数据类型转换为model类型
  Model convert2Model(Object object);

  /// attribute的数据类型转换为仓库数据类型
  Object attributeValue(Attribute attribute);

  /// 仓库的数据类型回设attribute的value
  setAttributeValue(Attribute attribute, Object? dbValue);
}
