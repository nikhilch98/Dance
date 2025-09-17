// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bundle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BundleTemplate _$BundleTemplateFromJson(Map<String, dynamic> json) =>
    BundleTemplate(
      templateId: json['template_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      bundlePrice: (json['bundle_price'] as num).toInt(),
      individualTotalPrice: (json['individual_total_price'] as num).toInt(),
      savingsAmount: (json['savings_amount'] as num).toInt(),
      savingsPercentage: (json['savings_percentage'] as num).toDouble(),
      workshopCount: (json['workshop_count'] as num).toInt(),
      includedWorkshops: (json['included_workshops'] as List<dynamic>)
          .map((e) => BundleWorkshop.fromJson(e as Map<String, dynamic>))
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
    );

Map<String, dynamic> _$BundleTemplateToJson(BundleTemplate instance) =>
    <String, dynamic>{
      'template_id': instance.templateId,
      'name': instance.name,
      'description': instance.description,
      'bundle_price': instance.bundlePrice,
      'individual_total_price': instance.individualTotalPrice,
      'savings_amount': instance.savingsAmount,
      'savings_percentage': instance.savingsPercentage,
      'workshop_count': instance.workshopCount,
      'included_workshops': instance.includedWorkshops,
      'is_active': instance.isActive,
    };

BundleWorkshop _$BundleWorkshopFromJson(Map<String, dynamic> json) =>
    BundleWorkshop(
      workshopUuid: json['workshop_uuid'] as String,
      title: json['title'] as String,
      artistNames: (json['artist_names'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      studioName: json['studio_name'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      individualPrice: (json['individual_price'] as num).toInt(),
    );

Map<String, dynamic> _$BundleWorkshopToJson(BundleWorkshop instance) =>
    <String, dynamic>{
      'workshop_uuid': instance.workshopUuid,
      'title': instance.title,
      'artist_names': instance.artistNames,
      'studio_name': instance.studioName,
      'date': instance.date,
      'time': instance.time,
      'individual_price': instance.individualPrice,
    };

BundleSuggestion _$BundleSuggestionFromJson(Map<String, dynamic> json) =>
    BundleSuggestion(
      bundleTemplateId: json['bundle_template_id'] as String,
      bundleName: json['bundle_name'] as String,
      description: json['description'] as String,
      bundlePrice: (json['bundle_price'] as num).toInt(),
      individualTotalPrice: (json['individual_total_price'] as num).toInt(),
      savingsRupees: (json['savings_rupees'] as num).toInt(),
      savingsPercentage: (json['savings_percentage'] as num).toDouble(),
      workshopCount: (json['workshop_count'] as num).toInt(),
      purchaseUrl: json['purchase_url'] as String?,
    );

Map<String, dynamic> _$BundleSuggestionToJson(BundleSuggestion instance) =>
    <String, dynamic>{
      'bundle_template_id': instance.bundleTemplateId,
      'bundle_name': instance.bundleName,
      'description': instance.description,
      'bundle_price': instance.bundlePrice,
      'individual_total_price': instance.individualTotalPrice,
      'savings_rupees': instance.savingsRupees,
      'savings_percentage': instance.savingsPercentage,
      'workshop_count': instance.workshopCount,
      'purchase_url': instance.purchaseUrl,
    };

BundleTemplatesResponse _$BundleTemplatesResponseFromJson(
        Map<String, dynamic> json) =>
    BundleTemplatesResponse(
      success: json['success'] as bool,
      bundles: (json['bundles'] as List<dynamic>)
          .map((e) => BundleTemplate.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String,
    );

Map<String, dynamic> _$BundleTemplatesResponseToJson(
        BundleTemplatesResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'bundles': instance.bundles,
      'message': instance.message,
    };
