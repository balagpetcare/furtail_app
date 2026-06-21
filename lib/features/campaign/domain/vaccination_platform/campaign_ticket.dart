/// Per-cat vaccination ticket (maps to backend CampaignPet.ticketToken).
class CampaignTicket {
  final int id;
  final String petName;
  final String ticketToken;
  final String ticketUrl;
  final String bookingRef;
  final String vaccinationStatus;
  final String? locationName;
  final String? bookingDate;
  final String? bookingArea;
  final String? qrImageBase64;

  const CampaignTicket({
    required this.id,
    required this.petName,
    required this.ticketToken,
    required this.ticketUrl,
    required this.bookingRef,
    required this.vaccinationStatus,
    this.locationName,
    this.bookingDate,
    this.bookingArea,
    this.qrImageBase64,
  });

  factory CampaignTicket.fromJson(Map<String, dynamic> json) {
    return CampaignTicket(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      petName: json['petName']?.toString() ?? json['name']?.toString() ?? 'Cat',
      ticketToken: json['ticketToken']?.toString() ?? '',
      ticketUrl: json['ticketUrl']?.toString() ?? '',
      bookingRef: json['bookingRef']?.toString() ?? '',
      vaccinationStatus: json['vaccinationStatus']?.toString() ?? 'PENDING',
      locationName: json['locationName']?.toString(),
      bookingDate: json['bookingDate']?.toString(),
      bookingArea: json['bookingArea']?.toString(),
      qrImageBase64: json['qrImage']?.toString(),
    );
  }
}
