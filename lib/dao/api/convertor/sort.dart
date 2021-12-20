import 'package:hg_orm/dao/api/convertor/convertor.dart';
import 'package:hg_orm/dao/api/sort.dart';

/// 排序转换器
abstract class SortConvertor<T> extends Convertor<Sort, T> {}
