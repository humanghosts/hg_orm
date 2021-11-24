import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/export.dart';

import 'dao.dart';
import 'filter.dart';
import 'sort.dart';
import 'transaction.dart';

/// 负责将hg_orm和hg_entity转换为对应的数据库的数据
abstract class Convertor {
  const Convertor();

  /// filter转换为仓库特性过滤
  Object filterConvert(HgFilter filter);

  /// sort转换为仓库特型排序
  Object sortConvert(HgSort sort);

  /// model转换为仓库的数据类型
  Object modelConvert(Model model, HgTransaction? tx, bool isLogicDelete, bool isCache) {
    return getModelValue(model, tx, isLogicDelete, isCache);
  }

  /// 仓库的数据类型转换为model类型，最好保证model是新的
  Future<Model> convertToModel(Model model, Object? value, HgTransaction? tx, bool isLogicDelete, bool isCache) async {
    return await setModelValue(model, value, tx, isLogicDelete, isCache);
  }

  /// attribute的数据类型转换为仓库数据类型
  Object? attributeConvert(Attribute attribute, HgTransaction? tx, bool isLogicDelete, bool isCache) {
    return getAttributeValue(attribute, tx, isLogicDelete, isCache);
  }

  /// 仓库的数据类型回设attribute的value,最好保证attribute是新的
  Future<Attribute> convertToAttribute(Attribute attribute, Object? value, HgTransaction? tx, bool isLogicDelete, bool isCache) async {
    return await setAttributeValue(attribute, value, tx, isLogicDelete, isCache);
  }

  /// 供其它类使用的方法
  static Object getModelValue(Model model, HgTransaction? tx, bool isLogicDelete, bool isCache) {
    Map<String, Object> map = <String, Object>{};
    for (Attribute attribute in model.attributes.list) {
      Object? value = getAttributeValue(attribute, tx, isLogicDelete, isCache);
      if (null == value) {
        continue;
      }
      map[attribute.name] = value;
    }
    return map;
  }

  /// 供其它类使用的方法
  static Future<Model> setModelValue(Model model, Object? value, HgTransaction? tx, bool isLogicDelete, bool isCache) async {
    if (null == value) {
      return model;
    }
    if (value is! Map) {
      return model;
    }
    for (Attribute attribute in model.attributes.list) {
      String attributeName = attribute.name;
      await setAttributeValue(attribute, value[attributeName], tx, isLogicDelete, isCache);
    }
    return model;
  }

  /// 供其它类使用的方法
  static Object? getAttributeValue(Attribute attribute, HgTransaction? tx, bool isLogicDelete, bool isCache) {
    // 属性为空
    if (attribute.isNull) return null;
    // 模型属性
    if (attribute is ModelAttribute) {
      if (attribute is DataModelAttribute) {
        // 处理数据模型的逻辑删除
        if (attribute.value!.isDelete.value == true && isLogicDelete) {
          return null;
        }
        return attribute.value!.id.value;
      } else if (attribute is SimpleModelAttribute) {
        return getModelValue(attribute.value!, tx, isLogicDelete, isCache);
      } else {
        return getModelValue(attribute.value!, tx, isLogicDelete, isCache);
      }
    }
    // 自定义属性
    else if (attribute is CustomAttribute) {
      return attribute.value!.toMap();
    }
    // 列表属性
    else if (attribute is ListAttribute) {
      if (attribute is ModelListAttribute) {
        if (attribute is DataModelListAttribute) {
          List<String> idList = [];
          // 处理数据模型的逻辑删除
          for (DataModel item in attribute.value) {
            if (item.isDelete.value == true && isLogicDelete) {
              continue;
            }
            idList.add(item.id.value);
          }
          return idList;
        } else if (attribute is SimpleModelListAttribute) {
          return attribute.value.map((e) => getModelValue(e, tx, isLogicDelete, isCache)).toList();
        } else {
          return attribute.value.map((e) => getModelValue(e, tx, isLogicDelete, isCache)).toList();
        }
      } else if (attribute is CustomListAttribute) {
        return attribute.value.map((e) => e.toMap()).toList();
      } else if (attribute is DateTimeListAttribute) {
        return attribute.value.map((e) => e.millisecondsSinceEpoch).toList();
      } else {
        return attribute.value;
      }
    }
    // 一般属性
    else {
      Type type = attribute.type;
      if (type == DateTime || type.toString() == "DateTime?") {
        return (attribute.value as DateTime).millisecondsSinceEpoch;
      } else {
        return attribute.value;
      }
    }
  }

  /// 供其它类使用的方法
  static Future<Attribute> setAttributeValue(Attribute attribute, Object? value, HgTransaction? tx, bool isLogicDelete, bool isCache) async {
    if (null == value) {
      attribute.clear();
      return attribute;
    }
    // 模型属性
    if (attribute is ModelAttribute) {
      if (attribute is DataModelAttribute) {
        // 数据库查询
        DataDao<DataModel> dao = DaoCache.getByType(attribute.type) as DataDao<DataModel>;
        attribute.valueTypeless = await dao.findByID(value as String, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      } else if (attribute is SimpleModelAttribute) {
        attribute.valueTypeless = await setModelValue(ConstructorCache.get(attribute.type), value, tx, isLogicDelete, isCache) as SimpleModel;
      } else {
        attribute.valueTypeless = await setModelValue(ConstructorCache.get(attribute.type), value, tx, isLogicDelete, isCache);
      }
    }
    // 自定义属性
    else if (attribute is CustomAttribute) {
      if (attribute.isNull) {
        attribute.valueTypeless = ConstructorCache.get(attribute.type);
      }
      await attribute.value!.fromMap(value);
    }
    // 列表属性
    else if (attribute is ListAttribute) {
      List listValue = value as List;
      // 实体列表属性
      if (attribute is ModelListAttribute) {
        // 数据模型列表属性
        if (attribute is DataModelListAttribute) {
          // 数据库查询
          DataDao<DataModel> dao = DaoCache.getByType(attribute.type) as DataDao<DataModel>;
          attribute.clear();
          attribute.appendAll(await dao.findByIDList(listValue.map((e) => e as String).toList(), tx: tx, isLogicDelete: isLogicDelete, isCache: isCache));
        }
        // 简单模型列表属性
        else if (attribute is SimpleModelListAttribute) {
          attribute.clear();
          for (var oneValue in listValue) {
            attribute.append(await setModelValue(ConstructorCache.get(attribute.type), oneValue, tx, isLogicDelete, isCache) as SimpleModel);
          }
        } else {
          attribute.clear();
          for (var oneValue in listValue) {
            attribute.append(await setModelValue(ConstructorCache.get(attribute.type), oneValue, tx, isLogicDelete, isCache));
          }
        }
      }
      // 自定义值列表属性
      else if (attribute is CustomListAttribute) {
        attribute.clear();
        for (Object e in listValue) {
          CustomValue cv = ConstructorCache.get(attribute.type);
          cv.fromMap(e);
          attribute.append(cv);
        }
      }
      // 时间列表属性
      else if (attribute is DateTimeListAttribute) {
        attribute.valueTypeless = listValue.map((e) => DateTime.fromMillisecondsSinceEpoch(e as int)).toList();
      }
      // 其它列表属性
      else {
        attribute.valueTypeless = listValue;
      }
    }

    // 一般属性
    else {
      Type type = attribute.type;
      if (type == DateTime || type.toString() == "DateTime?") {
        attribute.valueTypeless = DateTime.fromMillisecondsSinceEpoch(value as int);
      } else {
        attribute.valueTypeless = value;
      }
    }
    return attribute;
  }
}
