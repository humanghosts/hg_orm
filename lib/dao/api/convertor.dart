import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/context/cache.dart';
import 'package:hg_orm/dao/api/dao.dart';

import 'filter.dart';
import 'sort.dart';

abstract class Convertor {
  /// api的通用型filter转换为仓库特性过滤
  Object filterConvert(Filter filter);

  /// api的通用型sort转换为仓库特型排序
  Object sortConvert(Sort sort);

  /// model转换为仓库的数据类型
  Object modelValue(Model model) {
    return getModelValue(model);
  }

  /// 仓库的数据类型转换为model类型，最好保证model是新的
  Future<Model> setModel(Model model, Object? value) async {
    return await setModelValue(model, value);
  }

  /// attribute的数据类型转换为仓库数据类型
  Object? attributeValue(Attribute attribute) {
    return getAttributeValue(attribute);
  }

  /// 仓库的数据类型回设attribute的value,最好保证attribute是新的
  Future<Attribute> setAttribute(Attribute attribute, Object? value) async {
    return await setAttributeValue(attribute, value);
  }

  static Object getModelValue(Model model) {
    Map<String, Object> map = <String, Object>{};
    for (Attribute attribute in model.attributes.list) {
      Object? value = getAttributeValue(attribute);
      if (null == value) {
        continue;
      }
      if (model is DataTreeModel && model.children == attribute) {
        continue;
      }
      map[attribute.name] = value;
    }
    return map;
  }

  static Future<Model> setModelValue(Model model, Object? value) async {
    if (null == value) {
      return model;
    }
    if (value is! Map) {
      return model;
    }
    for (Attribute attribute in model.attributes.list) {
      String attributeName = attribute.name;
      await setAttributeValue(attribute, value[attributeName]);
    }
    return model;
  }

  static Object? getAttributeValue(Attribute attribute) {
    // 属性为空
    if (attribute.isNull) return null;
    // 模型属性
    if (attribute is ModelAttribute) {
      if (attribute is DataModelAttribute) {
        return attribute.value!.id.value;
      } else if (attribute is SimpleModelAttribute) {
        return getModelValue(attribute.value!);
      } else {
        return getModelValue(attribute.value!);
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
          return attribute.value.map((e) => e.id.value).toList();
        } else if (attribute is SimpleModelListAttribute) {
          return attribute.value.map((e) => getModelValue(e)).toList();
        } else {
          return attribute.value.map((e) => getModelValue(e)).toList();
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

  static Future<Attribute> setAttributeValue(Attribute attribute, Object? value) async {
    if (null == value) {
      attribute.clear();
      return attribute;
    }
    // 模型属性
    if (attribute is ModelAttribute) {
      if (attribute is DataModelAttribute) {
        Dao<Model> dao = DaoCache.get(attribute.type);
        attribute.valueTypeless = await dao.findByID(value as String) as DataModel?;
      } else if (attribute is SimpleModelAttribute) {
        attribute.valueTypeless = await setModelValue(ConstructorCache.get(attribute.type), value) as SimpleModel;
      } else {
        attribute.valueTypeless = await setModelValue(ConstructorCache.get(attribute.type), value);
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
          Dao<Model> dao = DaoCache.get(attribute.type);
          attribute.clear();
          for (Object obj in listValue) {
            DataModel? model = await dao.findByID(obj as String) as DataModel?;
            if (null == model) {
              continue;
            }
            attribute.append(model);
          }
        }
        // 简单模型列表属性
        else if (attribute is SimpleModelListAttribute) {
          attribute.clear();
          for (var oneValue in listValue) {
            attribute.append(await setModelValue(ConstructorCache.get(attribute.type), oneValue) as SimpleModel);
          }
        } else {
          attribute.clear();
          for (var oneValue in listValue) {
            attribute.append(await setModelValue(ConstructorCache.get(attribute.type), oneValue));
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
