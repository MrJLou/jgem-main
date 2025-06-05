class ClinicService {
  final String id;
  final String serviceName;
  final String? description;
  final String? category;
  final double? defaultPrice;
  final int selectionCount;

  ClinicService({
    required this.id,
    required this.serviceName,
    this.description,
    this.category,
    this.defaultPrice,
    this.selectionCount = 0,
  });

  factory ClinicService.fromJson(Map<String, dynamic> json) {
    return ClinicService(
      id: json['id'] as String,
      serviceName: json['serviceName'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      defaultPrice: (json['defaultPrice'] as num?)?.toDouble(),
      selectionCount: json['selectionCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceName': serviceName,
      'description': description,
      'category': category,
      'defaultPrice': defaultPrice,
      'selectionCount': selectionCount,
    };
  }

  ClinicService copyWith({
    String? id,
    String? serviceName,
    String? description,
    String? category,
    double? defaultPrice,
    int? selectionCount,
  }) {
    return ClinicService(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      description: description ?? this.description,
      category: category ?? this.category,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      selectionCount: selectionCount ?? this.selectionCount,
    );
  }
}
