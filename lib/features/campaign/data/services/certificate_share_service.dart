import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/campaign_models.dart';
import '../repositories/campaign_repository.dart';

/// Shares vaccination certificates via system sheet (PDF or text link).
class CertificateShareService {
  final CampaignRepository _repo;

  CertificateShareService(this._repo);

  Future<void> shareCertificateLink(CertificateData cert) async {
    final text = [
      'Furtail Vaccination Certificate',
      'Pet: ${cert.petName}',
      'Vaccine: ${cert.vaccineType}',
      'Token: ${cert.certificateToken}',
      'Verify at your Furtail app or campaign verify page.',
    ].join('\n');
    await Share.share(text, subject: 'Vaccination certificate — ${cert.petName}');
  }

  Future<bool> shareCertificatePdf(String token) async {
    final pdf = await _repo.fetchCertificatePdf(token);
    if (pdf == null || pdf.pdfBase64.isEmpty) return false;

    final bytes = base64Decode(pdf.pdfBase64);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${pdf.filename}');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Furtail vaccination certificate',
      subject: pdf.filename,
    );
    return true;
  }
}
