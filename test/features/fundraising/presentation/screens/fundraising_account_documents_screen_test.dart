import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_account_documents_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_document_preview_screen.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/services/api_client.dart';

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<FundraisingAccount> accountValue,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        fundraisingMyAccountProvider.overrideWith(
          (ref) => accountValue.when(
            data: (value) async => value,
            loading: () => Completer<FundraisingAccount>().future,
            error: (error, stack) =>
                Future<FundraisingAccount>.error(error, stack),
          ),
        ),
        apiClientProvider.overrideWithValue(_FakePreviewApiClient()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FundraisingAccountDocumentsScreen(),
      ),
    ),
  );
}

void main() {
  group('FundraisingAccountDocumentsScreen', () {
    testWidgets('shows a branded loading state, not a blank page', (
      tester,
    ) async {
      await _pump(tester, const AsyncValue.loading());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'shows an empty state with an upload action when there are no documents',
      (tester) async {
        await _pump(tester, AsyncValue.data(_accountWithDocuments(const [])));
        await tester.pumpAndSettle();

        expect(find.text('No verification documents yet'), findsOneWidget);
        expect(find.text('Upload document'), findsOneWidget);
      },
    );

    testWidgets('shows document cards with a safe file name and no raw URL', (
      tester,
    ) async {
      final account = _accountWithDocuments(const [
        FundraisingAccountDocument(
          id: 1,
          title: 'National ID',
          mediaUrl: 'https://cdn.internal.example.com/media/nid-scan.pdf',
        ),
      ]);
      await _pump(tester, AsyncValue.data(account));
      await tester.pumpAndSettle();

      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('nid-scan.pdf'), findsOneWidget);
      expect(
        find.textContaining('https://cdn.internal.example.com'),
        findsNothing,
      );
    });

    testWidgets('exposes replace and delete actions from the document menu', (
      tester,
    ) async {
      final account = _accountWithDocuments(const [
        FundraisingAccountDocument(
          id: 1,
          title: 'National ID',
          mediaUrl: 'https://cdn.internal.example.com/media/nid-scan.pdf',
        ),
      ]);
      await _pump(tester, AsyncValue.data(account));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();

      expect(find.text('View'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('opens a safe in-app preview instead of a black screen', (
      tester,
    ) async {
      final account = _accountWithDocuments(const [
        FundraisingAccountDocument(
          id: 1,
          title: 'National ID',
          mediaUrl: 'https://cdn.example.com/nid.png',
          mediaType: 'IMAGE',
        ),
      ]);
      await _pump(tester, AsyncValue.data(account));
      await tester.pumpAndSettle();

      await tester.tap(find.text('National ID'));
      await tester.pumpAndSettle();

      expect(find.byType(FundraisingDocumentPreviewScreen), findsOneWidget);
      expect(find.byTooltip('Open externally'), findsOneWidget);
      expect(find.textContaining('https://cdn.example.com'), findsNothing);
    });

    testWidgets('always shows a visible AppBar back action', (tester) async {
      await _pump(tester, AsyncValue.data(_accountWithDocuments(const [])));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets(
      'shows a friendly retry card on a connection failure, never raw exception text',
      (tester) async {
        await _pump(
          tester,
          AsyncValue<FundraisingAccount>.error(
            DioException(
              requestOptions: RequestOptions(path: '/fundraising/account/me'),
              type: DioExceptionType.connectionError,
              error: 'Connection refused',
            ),
            StackTrace.current,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unable to connect'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.textContaining('DioException'), findsNothing);
        expect(find.textContaining('SocketException'), findsNothing);
        expect(find.textContaining('/fundraising/account/me'), findsNothing);
      },
    );

    testWidgets('Retry triggers a new fetch of the account provider', (
      tester,
    ) async {
      var callCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            fundraisingMyAccountProvider.overrideWith((ref) async {
              callCount += 1;
              if (callCount == 1) {
                throw ApiClientException(
                  message: 'boom',
                  dioExceptionType: 'connectionError',
                );
              }
              return _accountWithDocuments(const []);
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FundraisingAccountDocumentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(find.text('Unable to connect'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(find.text('No verification documents yet'), findsOneWidget);
    });
  });
}

FundraisingAccount _accountWithDocuments(
  List<FundraisingAccountDocument> documents,
) {
  return FundraisingAccount(
    id: 1,
    status: 'DRAFT',
    accountType: 'INDIVIDUAL',
    presentAddress: 'Dhaka',
    permanentAddress: 'Dhaka',
    occupation: 'Volunteer',
    divisionId: 30,
    districtId: 3026,
    upazilaId: 302601,
    unionId: null,
    areaId: 5001,
    dateOfBirth: DateTime(1995, 1, 1),
    nationalIdNumber: null,
    birthRegNumber: null,
    studentIdNumber: null,
    area: 'Dhanmondi',
    rescueSinceYear: null,
    orgName: null,
    orgDescription: null,
    orgWorkType: null,
    submittedAt: null,
    documents: documents,
  );
}

class _FakePreviewApiClient extends ApiClient {
  _FakePreviewApiClient() : super(dio: Dio());

  static final Uint8List _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlJ/3gAAAAASUVORK5CYII=',
  );

  @override
  Future<ApiBinaryResponse> getBinary(
    String url, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    return ApiBinaryResponse(bytes: _pngBytes, contentType: 'image/png');
  }
}
