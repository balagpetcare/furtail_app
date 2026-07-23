import 'package:furtail_app/services/api_client.dart';

class FundraisingUserSafeException implements Exception {
  final String message;

  const FundraisingUserSafeException(this.message);

  @override
  String toString() => message;
}

String mapFundraisingError(Object error) {
  if (error is FundraisingUserSafeException) {
    return error.message;
  }
  if (error is ApiClientException) {
    final code = (error.code ?? '').trim().toUpperCase();
    switch (code) {
      case 'FUNDRAISING_REAUTH_REQUIRED':
        return 'For security, please sign in again before changing payout details or submitting a withdrawal.';
      case 'FUNDRAISING_PAYOUT_DUPLICATE':
        return 'This payout method is already on file.';
      case 'FUNDRAISING_PAYOUT_DETAILS_REQUIRED':
        return 'Please complete the required payout details.';
      case 'FUNDRAISING_WITHDRAWAL_ALREADY_PENDING':
        return 'You already have a withdrawal under review for this campaign.';
      case 'FUNDRAISING_WITHDRAWAL_INSUFFICIENT_AVAILABLE':
        return 'The requested amount is higher than your available balance.';
      case 'FUNDRAISING_WITHDRAWAL_MAKER_CHECKER_REQUIRED':
        return 'This withdrawal needs a separate reviewer before it can be approved.';
      case 'FUNDRAISING_WITHDRAWAL_REASON_REQUIRED':
        return 'A decision reason is required for this withdrawal.';
      case 'CENTRAL_TOKEN_EXPIRED':
      case 'TOKEN_REVOKED':
        return 'Your session has expired. Please sign in again.';
    }
    if (error.isNetworkError) {
      return 'We could not reach the server. Please check your connection and try again.';
    }
    final message = error.message.replaceFirst('Exception: ', '').trim();
    if (message.isEmpty || message.startsWith('{') || message.startsWith('[')) {
      return 'Something went wrong. Please try again.';
    }
    return message;
  }

  final text = error.toString().replaceFirst('Exception: ', '').trim();
  if (text.isEmpty || text.startsWith('{') || text.startsWith('[')) {
    return 'Something went wrong. Please try again.';
  }
  return text;
}
