import 'package:hg_orm/dao/api/export.dart';

Map<Type, Object Function([Map<String, dynamic>? args])> get ormEntitiesMap {
  return {
    SingleHgFilterValue: ([Map<String, dynamic>? args]) => SingleHgFilterValue(),
    GroupHgFilterValue: ([Map<String, dynamic>? args]) => GroupHgFilterValue(),
    HgSortValue: ([Map<String, dynamic>? args]) => HgSortValue(),
  };
}
