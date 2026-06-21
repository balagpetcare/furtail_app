import '../../data/models/campaign_public_models.dart';

class CampaignPriceBreakdown {
  final bool isFree;
  final String currency;
  final num unitPrice;
  final int quantity;
  final num subtotal;
  final num discount;
  final num total;

  const CampaignPriceBreakdown({
    required this.isFree,
    required this.currency,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    required this.discount,
    required this.total,
  });
}

CampaignPriceBreakdown computeCampaignPriceBreakdown({
  required PublicCampaign? campaign,
  required int catCount,
}) {
  final quantity = catCount < 1 ? 1 : catCount;
  final isFree = campaign?.isFree ?? true;
  final currency = campaign?.currency ?? 'BDT';
  final unit = isFree
      ? 0
      : (campaign?.pricing?.totalPrice ?? campaign?.priceAmount ?? 0);
  final unitPrice = unit is num ? unit : num.tryParse('$unit') ?? 0;
  final subtotal = unitPrice * quantity;

  return CampaignPriceBreakdown(
    isFree: isFree || unitPrice <= 0,
    currency: currency,
    unitPrice: unitPrice,
    quantity: quantity,
    subtotal: subtotal,
    discount: 0,
    total: subtotal,
  );
}

String formatCampaignMoney(num amount, String currency) {
  if (amount <= 0) return 'Free';
  if (currency == 'BDT') return '৳${amount is int ? amount : amount.round()}';
  return '$currency ${amount.toStringAsFixed(0)}';
}
