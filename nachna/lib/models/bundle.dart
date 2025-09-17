import 'package:json_annotation/json_annotation.dart';

part 'bundle.g.dart';

/// Bundle template model for available bundle packages
@JsonSerializable()
class BundleTemplate {
  @JsonKey(name: 'template_id')
  final String templateId;

  final String name;
  final String description;

  @JsonKey(name: 'bundle_price')
  final int bundlePrice;

  @JsonKey(name: 'individual_total_price')
  final int individualTotalPrice;

  @JsonKey(name: 'savings_amount')
  final int savingsAmount;

  @JsonKey(name: 'savings_percentage')
  final double savingsPercentage;

  @JsonKey(name: 'workshop_count')
  final int workshopCount;

  @JsonKey(name: 'included_workshops')
  final List<BundleWorkshop> includedWorkshops;

  @JsonKey(name: 'is_active')
  final bool isActive;

  BundleTemplate({
    required this.templateId,
    required this.name,
    required this.description,
    required this.bundlePrice,
    required this.individualTotalPrice,
    required this.savingsAmount,
    required this.savingsPercentage,
    required this.workshopCount,
    required this.includedWorkshops,
    this.isActive = true,
  });

  factory BundleTemplate.fromJson(Map<String, dynamic> json) => _$BundleTemplateFromJson(json);
  Map<String, dynamic> toJson() => _$BundleTemplateToJson(this);

  // Helper getters for UI
  String get formattedBundlePrice => '₹${bundlePrice.toString()}';
  String get formattedIndividualTotalPrice => '₹${individualTotalPrice.toString()}';
  String get formattedSavingsAmount => '₹${savingsAmount.toString()}';
  String get formattedSavingsPercentage => '${savingsPercentage.toStringAsFixed(1)}%';
}

/// Workshop included in a bundle
@JsonSerializable()
class BundleWorkshop {
  @JsonKey(name: 'workshop_uuid')
  final String workshopUuid;

  final String title;

  @JsonKey(name: 'artist_names')
  final List<String> artistNames;

  @JsonKey(name: 'studio_name')
  final String studioName;

  final String date;
  final String time;

  @JsonKey(name: 'individual_price')
  final int individualPrice;

  BundleWorkshop({
    required this.workshopUuid,
    required this.title,
    required this.artistNames,
    required this.studioName,
    required this.date,
    required this.time,
    required this.individualPrice,
  });

  factory BundleWorkshop.fromJson(Map<String, dynamic> json) => _$BundleWorkshopFromJson(json);
  Map<String, dynamic> toJson() => _$BundleWorkshopToJson(this);

  String get formattedIndividualPrice => '₹${individualPrice.toString()}';

  String get artistNamesDisplay {
    if (artistNames.isEmpty) return 'TBA';
    if (artistNames.length == 1) return artistNames.first;
    return '${artistNames.first} +${artistNames.length - 1} more';
  }
}

/// Bundle suggestion that appears during workshop purchase
@JsonSerializable()
class BundleSuggestion {
  @JsonKey(name: 'bundle_template_id')
  final String bundleTemplateId;

  @JsonKey(name: 'bundle_name')
  final String bundleName;

  final String description;

  @JsonKey(name: 'bundle_price')
  final int bundlePrice;

  @JsonKey(name: 'individual_total_price')
  final int individualTotalPrice;

  @JsonKey(name: 'savings_rupees')
  final int savingsRupees;

  @JsonKey(name: 'savings_percentage')
  final double savingsPercentage;

  @JsonKey(name: 'workshop_count')
  final int workshopCount;

  @JsonKey(name: 'purchase_url')
  final String? purchaseUrl;

  BundleSuggestion({
    required this.bundleTemplateId,
    required this.bundleName,
    required this.description,
    required this.bundlePrice,
    required this.individualTotalPrice,
    required this.savingsRupees,
    required this.savingsPercentage,
    required this.workshopCount,
    this.purchaseUrl,
  });

  factory BundleSuggestion.fromJson(Map<String, dynamic> json) => _$BundleSuggestionFromJson(json);
  Map<String, dynamic> toJson() => _$BundleSuggestionToJson(this);

  // Helper getters for UI
  String get formattedBundlePrice => '₹${bundlePrice.toString()}';
  String get formattedIndividualTotalPrice => '₹${individualTotalPrice.toString()}';
  String get formattedSavingsRupees => '₹${savingsRupees.toString()}';
  String get formattedSavingsPercentage => '${savingsPercentage.toStringAsFixed(1)}%';
}

/// Response model for bundle templates API
@JsonSerializable()
class BundleTemplatesResponse {
  final bool success;
  final List<BundleTemplate> bundles;
  final String message;

  BundleTemplatesResponse({
    required this.success,
    required this.bundles,
    required this.message,
  });

  factory BundleTemplatesResponse.fromJson(Map<String, dynamic> json) => _$BundleTemplatesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$BundleTemplatesResponseToJson(this);
}
