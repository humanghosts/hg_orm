import 'package:hg_entity/hg_entity.dart';
import 'package:hg_orm/hg_orm.dart';

/// 模型转换器
class ModelConvertors {
  /// 属性转换器
  late final AttributeConvertors attributeConvertors;
  late final ModelConvertor mod;
  late final DataModelConvertor dataModel;
  late final DataTreeModelConvertor dataTreeModel;
  late final SimpleModelConvertor simpleModel;

  ModelConvertors._() {
    mod = ModelConvertor(this);
    dataModel = DataModelConvertor(this);
    dataTreeModel = DataTreeModelConvertor(this);
    simpleModel = SimpleModelConvertor(this);
  }

  static ModelConvertors? _instance;

  static ModelConvertors get instance {
    _instance ??= ModelConvertors._();
    return _instance!;
  }

  Future<Object?> getValue(
    Model? value, {
    Transaction? tx,
    bool? isLogicDelete,
    bool? isCache,
  }) async {
    if (null == value) return null;
    if (TypeUtil.isThisType(value, DataModel)) {
      if (TypeUtil.isThisType(value, DataTreeModel)) {
        return await dataTreeModel.to(value, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      }
      return await dataModel.to(value, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    }
    if (TypeUtil.isThisType(value, SimpleModel)) {
      return await simpleModel.to(value, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    }
    return await mod.to(value, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
  }

  Future<Model?> getModelByType(
    Type? modelType,
    Object? value, {
    Transaction? tx,
    bool? isLogicDelete,
    bool? isCache,
  }) async {
    if (null == modelType) return null;
    return await getModelByModel(ConstructorCache.get(modelType), value, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
  }

  Future<Model?> getModelByModel(
    Model? model,
    Object? value, {
    Transaction? tx,
    bool? isLogicDelete,
    bool? isCache,
  }) async {
    if (null == model) return null;
    if (null == value) return null;
    if (value is! Map) return null;
    Map<String, Object> mapValue = value as Map<String, Object>;
    if (TypeUtil.isThisType(value, DataModel)) {
      if (TypeUtil.isThisType(value, DataTreeModel)) {
        return await dataTreeModel.from(mapValue, modelType: model.runtimeType, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
      }
      return await dataModel.from(mapValue, modelType: model.runtimeType, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    }
    if (TypeUtil.isThisType(value, SimpleModel)) {
      return await simpleModel.from(mapValue, modelType: model.runtimeType, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
    }
    return await mod.from(mapValue, modelType: model.runtimeType, tx: tx, isLogicDelete: isLogicDelete, isCache: isCache);
  }
}

class ModelConvertor<F extends Model> extends Convertor<F, Map<String, Object>> {
  ModelConvertors parent;

  ModelConvertor(this.parent);

  @override
  Future<Map<String, Object>?> to(Model? value, {Transaction? tx, bool? isLogicDelete, bool? isCache}) async {
    if (null == value) return null;
    Map<String, Object> map = <String, Object>{};
    for (Attribute attribute in value.attributes.list) {
      Object? value = await parent.attributeConvertors.getValue(
        attribute,
        tx: tx,
        isLogicDelete: isLogicDelete,
        isCache: isCache,
      );
      if (null == value) continue;
      map[attribute.name] = value;
    }
    return map;
  }

  @override
  Future<F?> from(
    Map<String, Object>? value, {
    Type? modelType,
    Transaction? tx,
    bool? isLogicDelete,
    bool? isCache,
  }) async {
    if (null == value) return null;
    if (null == modelType) return null;
    F model = ConstructorCache.get(modelType);
    for (Attribute attribute in model.attributes.list) {
      String attributeName = attribute.name;
      Object? attributeValue = value[attributeName];
      await parent.attributeConvertors.getAttribute(
        attributeValue,
        attribute: attribute,
        tx: tx,
        isLogicDelete: isLogicDelete,
        isCache: isCache,
      );
    }
    return model;
  }
}

class DataModelConvertor<F extends DataModel> extends ModelConvertor<F> {
  DataModelConvertor(ModelConvertors parent) : super(parent);
}

class DataTreeModelConvertor extends DataModelConvertor<DataTreeModel> {
  DataTreeModelConvertor(ModelConvertors parent) : super(parent);
}

class SimpleModelConvertor extends ModelConvertor<SimpleModel> {
  SimpleModelConvertor(ModelConvertors parent) : super(parent);
}
