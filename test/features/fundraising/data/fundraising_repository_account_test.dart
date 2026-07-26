import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  group('FundraisingRepository.fetchMyAccount', () {
    test('returns null for a documented missing-account response', () async {
      final repo = FundraisingRepository(
        _FakeApiClient(
          getHandler: (url) async {
            throw ApiClientException(
              message: 'Not found',
              statusCode: 404,
              code: 'FUNDRAISING_ACCOUNT_NOT_FOUND',
              method: 'GET',
              url: url,
            );
          },
        ),
      );

      final account = await repo.fetchMyAccount();

      expect(account, isNull);
    });

    test('returns null for wrapped data null', () async {
      final repo = FundraisingRepository(
        _FakeApiClient(
          getHandler: (url) async => <String, dynamic>{
            'success': true,
            'data': null,
          },
        ),
      );

      final account = await repo.fetchMyAccount();

      expect(account, isNull);
    });

    test('returns null for a direct null response', () async {
      final repo = FundraisingRepository(
        _FakeApiClient(getHandler: (url) async => null),
      );

      final account = await repo.fetchMyAccount();

      expect(account, isNull);
    });

    test('parses a wrapped account object with campaigns ignored', () async {
      final repo = FundraisingRepository(
        _FakeApiClient(
          getHandler: (url) async {
            return <String, dynamic>{
              'success': true,
              'data': _accountPayload(
                status: 'VERIFIED',
                accountType: null,
                includeCampaigns: true,
                documents: <Map<String, dynamic>>[
                  _documentPayload(
                    id: '9',
                    accountId: 17,
                    mediaId: '11',
                    title: null,
                    createdAt: '2026-01-01T00:00:00.000Z',
                  ),
                ],
              ),
            };
          },
        ),
      );

      final account = await repo.fetchMyAccount();

      expect(account, isNotNull);
      expect(account!.status, 'VERIFIED');
      expect(account.accountType, isNull);
      expect(account.documents, hasLength(1));
      expect(account.documents.first.accountId, 17);
      expect(account.documents.first.mediaId, 11);
      expect(account.documents.first.title, 'Verification document');
    });

    test('parses a direct account object', () async {
      final repo = FundraisingRepository(
        _FakeApiClient(
          getHandler: (url) async => _accountPayload(
            status: 'PENDING',
            documents: <Map<String, dynamic>>[
              _documentPayload(
                id: 7,
                accountId: 17,
                mediaId: 8,
                title: 'National ID',
                mediaUrl: 'https://cdn.example.com/doc.pdf',
              ),
            ],
          ),
        ),
      );

      final account = await repo.fetchMyAccount();

      expect(account, isNotNull);
      expect(account!.status, 'PENDING');
      expect(account.readiness.isPendingReview, isTrue);
    });

    test('throws a typed parse exception for malformed payloads', () async {
      final repo = FundraisingRepository(
        _FakeApiClient(
          getHandler: (url) async {
            return <dynamic>[
              <String, dynamic>{'id': 1},
            ];
          },
        ),
      );

      await expectLater(
        repo.fetchMyAccount(),
        throwsA(isA<FundraisingAccountParseException>()),
      );
    });

    test('throws a typed parse exception for string payloads', () async {
      final repo = FundraisingRepository(
        _FakeApiClient(getHandler: (url) async => '<html>nope</html>'),
      );

      await expectLater(
        repo.fetchMyAccount(),
        throwsA(isA<FundraisingAccountParseException>()),
      );
    });

    test(
      'keeps genuine network failures separate from empty setup state',
      () async {
        final repo = FundraisingRepository(
          _FakeApiClient(
            getHandler: (url) async {
              throw ApiClientException(
                message: 'Connection refused',
                dioExceptionType: 'connectionError',
                method: 'GET',
                url: url,
              );
            },
          ),
        );

        await expectLater(
          repo.fetchMyAccount(),
          throwsA(isA<ApiClientException>()),
        );
      },
    );
  });

  group('FundraisingRepository.updateMyAccount', () {
    test('accepts PATCH responses without documents or campaigns', () async {
      final repo = FundraisingRepository(
        _FakeApiClient(
          patchHandler: (url, body) async {
            return <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'id': 22,
                'status': 'DRAFT',
                'accountType': null,
                'presentAddress': 'Dhaka',
                'permanentAddress': 'Dhaka',
                'occupation': 'Volunteer',
                'dateOfBirth': '1995-01-01T00:00:00.000Z',
              },
            };
          },
        ),
      );

      final account = await repo.updateMyAccount(<String, dynamic>{
        'presentAddress': 'Dhaka',
      });

      expect(account.id, 22);
      expect(account.accountType, isNull);
      expect(account.documents, isEmpty);
    });
  });

  group('FundraisingAccount.fromJson', () {
    test('accepts nullable accountType and ignores campaigns', () {
      final account = FundraisingAccount.fromJson(<String, dynamic>{
        'success': true,
        'data': _accountPayload(
          status: 'VERIFIED',
          accountType: null,
          includeCampaigns: true,
          documents: <Map<String, dynamic>>[
            _documentPayload(
              id: 1,
              accountId: 17,
              mediaId: 2,
              title: 'Verification document',
              mediaUrl: 'https://cdn.example.com/doc.pdf',
            ),
          ],
        ),
      });

      expect(account.status, 'VERIFIED');
      expect(account.accountType, isNull);
      expect(account.documents, hasLength(1));
    });

    test(
      'skips one malformed optional document and keeps the account readable',
      () {
        final account = FundraisingAccount.fromJson(<String, dynamic>{
          'id': 17,
          'status': 'DRAFT',
          'accountType': null,
          'presentAddress': 'Dhaka',
          'permanentAddress': 'Dhaka',
          'occupation': 'Volunteer',
          'dateOfBirth': '1995-01-01T00:00:00.000Z',
          'documents': <dynamic>[
            _documentPayload(
              id: 1,
              accountId: 17,
              mediaId: 2,
              title: 'Verification document',
              mediaUrl: 'https://cdn.example.com/doc.pdf',
            ),
            <String, dynamic>{
              'id': 'bad-id',
              'accountId': 17,
              'mediaId': 'bad-media-id',
              'title': 'Broken document',
              'media': const <String, dynamic>{'type': 'DOCUMENT'},
            },
          ],
        });

        expect(account.documents, hasLength(1));
        expect(account.documents.first.id, 1);
      },
    );

    test(
      'normalizes unknown status to PENDING and handles missing optional fields',
      () {
        final account = FundraisingAccount.fromJson(<String, dynamic>{
          'id': 1,
          'status': 'ARCHIVED',
          'accountType': 'INDIVIDUAL',
        });

        expect(account.status, 'PENDING');
        expect(account.documents, isEmpty);
        expect(account.dateOfBirth, isNull);
      },
    );
  });

  group('FundraisingAccountDocument.fromJson', () {
    test('parses numeric string identifiers and nullable media safely', () {
      final document = FundraisingAccountDocument.fromJson(<String, dynamic>{
        'id': '9',
        'accountId': '17',
        'mediaId': '11',
        'title': null,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'media': null,
      });

      expect(document.id, 9);
      expect(document.accountId, 17);
      expect(document.mediaId, 11);
      expect(document.title, 'Verification document');
      expect(document.mediaUrl, isNull);
      expect(document.createdAt, isNotNull);
    });

    test('accepts a document with missing media URL', () {
      final document = FundraisingAccountDocument.fromJson(<String, dynamic>{
        'id': 9,
        'accountId': 17,
        'mediaId': 11,
        'title': 'National ID',
        'media': <String, dynamic>{'id': 11, 'url': null, 'type': 'DOCUMENT'},
      });

      expect(document.mediaUrl, isNull);
      expect(document.mediaType, 'DOCUMENT');
    });
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.getHandler, this.patchHandler}) : super(dio: Dio());

  final Future<dynamic> Function(String url)? getHandler;
  final Future<dynamic> Function(String url, Map<String, dynamic> body)?
  patchHandler;

  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? headers,
  }) {
    return getHandler?.call(url) ?? Future<dynamic>.value(null);
  }

  @override
  Future<dynamic> patch(
    String url,
    Map<String, dynamic> data, {
    bool auth = true,
    Map<String, String>? headers,
  }) {
    return patchHandler?.call(url, data) ?? Future<dynamic>.value(null);
  }
}

Map<String, dynamic> _accountPayload({
  required String status,
  String? accountType = 'INDIVIDUAL',
  List<Map<String, dynamic>> documents = const <Map<String, dynamic>>[],
  bool includeCampaigns = false,
}) {
  return <String, dynamic>{
    'id': 17,
    'status': status,
    if (accountType != null) 'accountType': accountType,
    'presentAddress': 'Dhaka',
    'permanentAddress': 'Dhaka',
    'occupation': 'Volunteer',
    'divisionId': 30,
    'districtId': 3026,
    'upazilaId': 302601,
    'unionId': 5001,
    'areaId': 5001,
    'dateOfBirth': '1995-01-01T00:00:00.000Z',
    'nationalIdNumber': '1234567890',
    'documents': documents,
    if (includeCampaigns)
      'campaigns': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 101,
          'title': 'Existing campaign',
          'status': 'DRAFT',
        },
      ],
  };
}

Map<String, dynamic> _documentPayload({
  required Object id,
  required Object accountId,
  required Object mediaId,
  required String? title,
  String? mediaUrl,
  String? createdAt,
}) {
  return <String, dynamic>{
    'id': id,
    'accountId': accountId,
    'mediaId': mediaId,
    if (title != null) 'title': title,
    if (createdAt != null) 'createdAt': createdAt,
    'media': <String, dynamic>{
      'id': mediaId,
      'url': mediaUrl,
      'type': 'DOCUMENT',
    },
  };
}
