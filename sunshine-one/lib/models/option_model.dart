class Option {
  final int optionId;
  final String optionName;

  Option({
    required this.optionId,
    required this.optionName,
  });

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      optionId: json['option_id'] ?? 0,
      optionName: json['option_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'option_name': optionName,
    };
  }

  @override
  String toString() {
    return optionName;
  }
}

class MasterType {
  final int typeId;
  final String typeName;
  final List<Option> options;

  MasterType({
    required this.typeId,
    required this.typeName,
    required this.options,
  });

  factory MasterType.fromJson(Map<String, dynamic> json) {
    return MasterType(
      typeId: json['type_id'] ?? 0,
      typeName: json['type_name'] ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((option) => Option.fromJson(option))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type_id': typeId,
      'type_name': typeName,
      'options': options.map((option) => option.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return typeName;
  }
}

class OptionsData {
  final List<MasterType> types;

  OptionsData({
    required this.types,
  });

  factory OptionsData.fromJson(List<dynamic> json) {
    return OptionsData(
      types: json.map((type) => MasterType.fromJson(type)).toList(),
    );
  }

  List<dynamic> toJson() {
    return types.map((type) => type.toJson()).toList();
  }

  // Helper methods for easy access
  MasterType? getTypeById(int typeId) {
    try {
      return types.firstWhere((type) => type.typeId == typeId);
    } catch (e) {
      return null;
    }
  }

  MasterType? getTypeByName(String typeName) {
    try {
      return types.firstWhere((type) => type.typeName == typeName);
    } catch (e) {
      return null;
    }
  }

  List<Option> getOptionsByTypeId(int typeId) {
    final type = getTypeById(typeId);
    return type?.options ?? [];
  }

  List<Option> getOptionsByTypeName(String typeName) {
    final type = getTypeByName(typeName);
    return type?.options ?? [];
  }

  Option? getOptionById(int optionId) {
    for (var type in types) {
      try {
        return type.options.firstWhere((option) => option.optionId == optionId);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  String? getOptionNameById(int optionId) {
    final option = getOptionById(optionId);
    return option?.optionName;
  }

  int? getOptionIdByName(String optionName) {
    for (var type in types) {
      try {
        final option = type.options.firstWhere((option) => option.optionName == optionName);
        return option.optionId;
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  // Get all options as a flat list
  List<Option> getAllOptions() {
    List<Option> allOptions = [];
    for (var type in types) {
      allOptions.addAll(type.options);
    }
    return allOptions;
  }

  // Get dropdown items for a specific type
  List<String> getDropdownItemsByTypeId(int typeId) {
    final options = getOptionsByTypeId(typeId);
    return options.map((option) => option.optionName).toList();
  }

  List<String> getDropdownItemsByTypeName(String typeName) {
    final options = getOptionsByTypeName(typeName);
    return options.map((option) => option.optionName).toList();
  }

  // Get dropdown items with ID - Name format
  List<String> getDropdownItemsWithIdByTypeId(int typeId) {
    final options = getOptionsByTypeId(typeId);
    return options.map((option) => '${option.optionId} - ${option.optionName}').toList();
  }

  List<String> getDropdownItemsWithIdByTypeName(String typeName) {
    final options = getOptionsByTypeName(typeName);
    return options.map((option) => '${option.optionId} - ${option.optionName}').toList();
  }
} 