class CustomItem {
  final String id;
  final String organizationId;
  final int slotIndex; // 1 to 8
  final String code; // Short code, e.g. F1, F2, T1, T2, I5..
  final String name; // Display name
  final double unitPrice;
  final bool isActive;

  const CustomItem({
    required this.id,
    required this.organizationId,
    required this.slotIndex,
    required this.code,
    required this.name,
    required this.unitPrice,
    this.isActive = true,
  });

  CustomItem copyWith({
    String? id,
    String? organizationId,
    int? slotIndex,
    String? code,
    String? name,
    double? unitPrice,
    bool? isActive,
  }) {
    return CustomItem(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      slotIndex: slotIndex ?? this.slotIndex,
      code: code ?? this.code,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'organization_id': organizationId,
    'slot_index': slotIndex,
    'code': code,
    'name': name,
    'unit_price': unitPrice,
    'is_active': isActive,
  };

  factory CustomItem.fromMap(Map<String, dynamic> map) {
    return CustomItem(
      id: map['id']?.toString() ?? '',
      organizationId: map['organization_id']?.toString() ?? '',
      slotIndex: (map['slot_index'] as num?)?.toInt() ?? 1,
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      isActive: map['is_active'] == null ? true : (map['is_active'] as bool),
    );
  }
}
