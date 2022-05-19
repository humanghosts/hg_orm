import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/hg_orm.dart';

Map<Type, Object Function([Map<String, dynamic>? args])> get ormEntitiesMap {
  return {
    SingleFilterValue: ([Map<String, dynamic>? args]) => SingleFilterValue(),
    GroupFilterValue: ([Map<String, dynamic>? args]) => GroupFilterValue(),
    SortValue: ([Map<String, dynamic>? args]) => SortValue(),
  };
}
