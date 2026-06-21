import 'api_client.dart';
import '../core/network/api_endpoints.dart';

class ProfileService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> fetchMyProfile() async {
    final res = await _client.get(ApiEndpoints.myProfile(), auth: true);

    // expected: { success:true, data:{ user:{...} } }
    final user = (res["data"]?["user"] as Map?)?.cast<String, dynamic>();
    if (user == null) {
      throw Exception("Profile response invalid: user missing");
    }
    return user;
  }
}
