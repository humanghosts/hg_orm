import 'package:hg_orm/dao/api/filter.dart';

import 'convertor.dart';

/// 过滤器转换器
abstract class FilterConvertor<T> extends Convertor<Filter, T> {}
