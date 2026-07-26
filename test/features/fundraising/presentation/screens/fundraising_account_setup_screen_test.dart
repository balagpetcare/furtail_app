import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/features/common/data/models/bd_location_models.dart';
import 'package:furtail_app/features/common/data/repositories/bd_locations_repository.dart';
import 'package:furtail_app/features/common/presentation/providers/bd_location_providers.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_verification_recovery_service.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_account_setup_screen.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:furtail_app/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FundraisingAccountSetupScreen', () {
    testWidgets('treats a missing account as first-time setup', (tester) async {
      await _pump(tester, accountProvider: () async => null);

      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Account & Location'), findsOneWidget);
      expect(
        find.text('Fundraising verification needs attention'),
        findsNothing,
      );
      expect(find.text('Something went wrong'), findsNothing);
      expect(find.text('Verification unavailable'), findsNothing);
    });

    testWidgets('renders a refreshed account with nullable accountType', (
      tester,
    ) async {
      await _pump(
        tester,
        accountProvider: () async => _completedAccount(
          status: 'DRAFT',
          accountType: null,
          documents: <FundraisingAccountDocument>[
            FundraisingAccountDocument(
              id: 9,
              accountId: 1,
              mediaId: 11,
              title: 'Verification document',
              mediaUrl: 'https://cdn.example.com/doc.pdf',
            ),
          ],
        ),
      );

      expect(find.text('Fundraising verification'), findsOneWidget);
      expect(find.text('Verification pending'), findsOneWidget);
      expect(find.text("We couldn't read the server response"), findsNothing);
    });

    testWidgets('shows a safe parse-failure title and one retry button', (
      tester,
    ) async {
      await _pump(
        tester,
        accountProvider: () async {
          throw const FundraisingAccountParseException('bad payload');
        },
      );

      expect(find.text("We couldn't read the server response"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(find.textContaining('bad payload'), findsNothing);
    });

    testWidgets('disables repeated retries while the request is in flight', (
      tester,
    ) async {
      final repo = _RetryingAccountSource();

      await _pump(tester, accountProvider: repo.load);

      expect(find.text('Unable to connect'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(repo.calls, 1);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(repo.calls, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.completeRetry(
        _completedAccount(
          status: 'VERIFIED',
          documents: <FundraisingAccountDocument>[
            FundraisingAccountDocument(
              id: 9,
              title: 'Verification document',
              mediaUrl: 'https://cdn.example.com/doc.pdf',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fundraising verification'), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Account & Location'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Verification pending'), findsNothing);
    });

    testWidgets('optional verification documents never show Required badges', (
      tester,
    ) async {
      await _pump(
        tester,
        accountProvider: () async => _completedAccount(status: 'DRAFT'),
        recoveryData: <String, dynamic>{'step': 2},
      );

      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Primary verification document'), findsOneWidget);
      expect(find.text('Selfie / profile photo'), findsOneWidget);
      expect(find.text('School / college ID'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Optional'), findsNWidgets(2));
    });

    testWidgets(
      'pending review can continue when verification readiness is satisfied',
      (tester) async {
        await _pump(
          tester,
          accountProvider: () async => _completedAccount(
            status: 'PENDING',
            documents: <FundraisingAccountDocument>[
              const FundraisingAccountDocument(
                id: 9,
                title: 'NID',
                mediaUrl: 'https://cdn.example.com/nid.pdf',
              ),
            ],
          ),
          recoveryData: <String, dynamic>{'step': 4},
        );

        expect(find.text('Step 5 of 5'), findsOneWidget);
        expect(find.text('Verification pending'), findsOneWidget);
        final continueButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Continue to fundraiser'),
        );
        expect(continueButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'clears district, upazila, and union selections when the division changes',
      (tester) async {
        await _pump(
          tester,
          accountProvider: () async => null,
          divisions: const <BdDivision>[
            BdDivision(id: 30, code: 'DIV-30', nameEn: 'Dhaka'),
            BdDivision(id: 40, code: 'DIV-40', nameEn: 'Chattogram'),
          ],
          districts: const <BdDistrict>[
            BdDistrict(
              id: 3026,
              code: 'DIS-3026',
              nameEn: 'Dhaka City',
              divisionId: 30,
            ),
            BdDistrict(
              id: 3027,
              code: 'DIS-3027',
              nameEn: 'Cumilla',
              divisionId: 40,
            ),
          ],
          upazilas: const <BdUpazila>[
            BdUpazila(
              id: 302601,
              code: 'UPZ-302601',
              nameEn: 'Dhanmondi',
              districtId: 3026,
            ),
            BdUpazila(
              id: 302701,
              code: 'UPZ-302701',
              nameEn: 'Gazipur Sadar',
              districtId: 3027,
            ),
          ],
          unions: const <BdUnion>[
            BdUnion(
              id: 5001,
              code: 'UNI-5001',
              nameEn: 'Dhanmondi Union',
              upazilaId: 302601,
            ),
            BdUnion(
              id: 5002,
              code: 'UNI-5002',
              nameEn: 'Gazipur Sadar Union',
              upazilaId: 302701,
            ),
          ],
        );

        await _fillStepOne(tester);
        await _selectChoice(tester, 1, 'Dhaka');
        await _selectChoice(tester, 2, 'Dhaka City');
        await _selectChoice(tester, 3, 'Dhanmondi');
        await _selectChoice(tester, 4, 'Dhanmondi Union');

        expect(find.text('Dhanmondi Union'), findsOneWidget);

        await _selectChoice(tester, 1, 'Chattogram');
        await tester.pumpAndSettle();

        expect(find.text('Dhanmondi Union'), findsNothing);
        expect(find.text('Dhanmondi'), findsNothing);
      },
    );

    testWidgets(
      'clears upazila and union selections when the district changes',
      (tester) async {
        await _pump(
          tester,
          accountProvider: () async => null,
          districts: const <BdDistrict>[
            BdDistrict(
              id: 3026,
              code: 'DIS-3026',
              nameEn: 'Dhaka City',
              divisionId: 30,
            ),
            BdDistrict(
              id: 3027,
              code: 'DIS-3027',
              nameEn: 'Gazipur',
              divisionId: 30,
            ),
          ],
          upazilas: const <BdUpazila>[
            BdUpazila(
              id: 302601,
              code: 'UPZ-302601',
              nameEn: 'Dhanmondi',
              districtId: 3026,
            ),
            BdUpazila(
              id: 302701,
              code: 'UPZ-302701',
              nameEn: 'Gazipur Sadar',
              districtId: 3027,
            ),
          ],
          unions: const <BdUnion>[
            BdUnion(
              id: 5001,
              code: 'UNI-5001',
              nameEn: 'Dhanmondi Union',
              upazilaId: 302601,
            ),
          ],
        );

        await _fillStepOne(tester);
        await _selectChoice(tester, 1, 'Dhaka');
        await _selectChoice(tester, 2, 'Dhaka City');
        await _selectChoice(tester, 3, 'Dhanmondi');
        await _selectChoice(tester, 4, 'Dhanmondi Union');

        expect(find.text('Dhanmondi Union'), findsOneWidget);

        await _selectChoice(tester, 2, 'Gazipur');
        await tester.pumpAndSettle();

        expect(find.text('Dhanmondi Union'), findsNothing);
        expect(find.text('Dhanmondi'), findsNothing);
      },
    );

    testWidgets(
      'shows an empty state when no union or ward options are available',
      (tester) async {
        await _pump(
          tester,
          accountProvider: () async => null,
          unions: const <BdUnion>[],
          areas: const <BdArea>[],
        );

        await _fillStepOne(tester);
        await _selectChoice(tester, 1, 'Dhaka');
        await _selectChoice(tester, 2, 'Dhaka');
        await _selectChoice(tester, 3, 'Dhanmondi');

        await _tapSelector(tester, 4);

        expect(
          find.text('No union options are available for this upazila.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'clears impossible restored location combinations before saving',
      (tester) async {
        final repo = _SetupScreenRepository(loadAccount: () async => null);
        await _pump(
          tester,
          accountProvider: () async => null,
          repository: repo,
          recoveryData: <String, dynamic>{
            'step': 0,
            'accountType': 'INDIVIDUAL',
            'presentAddress': 'Dhaka',
            'permanentAddress': 'Dhaka',
            'divisionId': 30,
            'districtId': 9999,
            'upazilaId': 8888,
            'unionId': 7777,
            'divisionName': 'Dhaka',
            'districtName': 'Bad District',
            'upazilaName': 'Bad Upazila',
            'unionName': 'Bad Union',
            'sameAsPresentAddress': true,
          },
        );

        expect(find.text('Bad District'), findsNothing);
        expect(find.text('Bad Upazila'), findsNothing);
        expect(find.text('Bad Union'), findsNothing);
      },
    );

    testWidgets(
      'saves the first-time setup payload without a duplicate draft',
      (tester) async {
        final repo = _SetupScreenRepository(loadAccount: () async => null);
        await _pump(
          tester,
          accountProvider: () async => null,
          repository: repo,
        );

        await _fillStepOne(tester);
        await _selectChoice(tester, 1, 'Dhaka');
        await _selectChoice(tester, 2, 'Dhaka');
        await _selectChoice(tester, 3, 'Dhanmondi');
        await _selectChoice(tester, 4, 'Dhanmondi Union');

        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();

        expect(repo.updateCalls, 1);
        expect(repo.submitCalls, 0);
        expect(repo.lastUpdatePayload?['divisionId'], 30);
        expect(repo.lastUpdatePayload?['districtId'], 3026);
        expect(repo.lastUpdatePayload?['upazilaId'], 302601);
        expect(repo.lastUpdatePayload?['unionId'], 5001);
      },
    );

    testWidgets(
      'allows urban ward selections to save without a fake union and continue',
      (tester) async {
        final repo = _SetupScreenRepository(loadAccount: () async => null);
        await _pump(
          tester,
          accountProvider: () async => null,
          repository: repo,
          unions: const <BdUnion>[],
          areas: const <BdArea>[
            BdArea(
              id: 7001,
              code: 'WARD-RAMPURA-1',
              nameEn: 'Rampura',
              type: 'AREA',
              upazilaId: 302601,
              districtId: 3026,
            ),
            BdArea(
              id: 7002,
              code: 'WARD-BANASREE-1',
              nameEn: 'Banasree',
              type: 'AREA',
              upazilaId: 302601,
              districtId: 3026,
            ),
          ],
        );

        await _fillStepOne(tester);
        await _selectChoice(tester, 1, 'Dhaka');
        await _selectChoice(tester, 2, 'Dhaka');
        await _selectChoice(tester, 3, 'Dhanmondi');

        expect(find.text('Union / Ward *'), findsOneWidget);

        await _selectChoice(tester, 4, 'Rampura');

        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();

        expect(repo.updateCalls, 1);
        expect(repo.lastUpdatePayload?['unionId'], isNull);
        expect(repo.lastUpdatePayload?['areaId'], 7001);
        expect(repo.lastUpdatePayload?['area'], 'Rampura');

        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Step 2 of 5'), findsOneWidget);
        expect(find.text('Identity Details'), findsOneWidget);
      },
    );

    testWidgets('requires a real union for rural locations', (tester) async {
      final repo = _SetupScreenRepository(loadAccount: () async => null);
      await _pump(tester, accountProvider: () async => null, repository: repo);

      await _fillStepOne(tester);
      await _selectChoice(tester, 1, 'Dhaka');
      await _selectChoice(tester, 2, 'Dhaka');
      await _selectChoice(tester, 3, 'Dhanmondi');

      expect(find.text('Union *'), findsOneWidget);
      await _selectChoice(tester, 4, 'Dhanmondi Union');

      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(repo.updateCalls, 1);
      expect(repo.lastUpdatePayload?['unionId'], 5001);
      expect(repo.lastUpdatePayload?['areaId'], isNull);
      expect(repo.lastUpdatePayload?['area'], 'Dhanmondi Union');

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text('Identity Details'), findsOneWidget);
    });

    testWidgets(
      'keeps the form visible with a scoped retry when only the location '
      'catalog validation fails (account request itself succeeded)',
      (tester) async {
        final locations = _FailingThenOkBdLocationsRepository();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              fundraisingRepositoryProvider.overrideWithValue(
                _SetupScreenRepository(
                  loadAccount: () async => _completedAccount(status: 'DRAFT'),
                ),
              ),
              bdLocationsRepositoryProvider.overrideWithValue(locations),
              fundraisingVerificationRecoveryServiceProvider.overrideWithValue(
                _MemoryRecoveryService(
                  initialValue: <String, dynamic>{
                    'divisionId': 30,
                    'districtId': 3026,
                    'upazilaId': 302601,
                    'unionId': 5001,
                  },
                ),
              ),
              bdDivisionsProvider.overrideWith(
                (ref) async => const <BdDivision>[
                  BdDivision(id: 30, code: 'DIV-30', nameEn: 'Dhaka'),
                ],
              ),
              bdDistrictsProvider(30).overrideWith(
                (ref) async => const <BdDistrict>[
                  BdDistrict(
                    id: 3026,
                    code: 'DIS-3026',
                    nameEn: 'Dhaka',
                    divisionId: 30,
                  ),
                ],
              ),
              bdUpazilasProvider(3026).overrideWith(
                (ref) async => const <BdUpazila>[
                  BdUpazila(
                    id: 302601,
                    code: 'UPZ-302601',
                    nameEn: 'Dhanmondi',
                    districtId: 3026,
                  ),
                ],
              ),
              bdUnionsProvider(302601).overrideWith(
                (ref) async => const <BdUnion>[
                  BdUnion(
                    id: 5001,
                    code: 'UNI-5001',
                    nameEn: 'Dhanmondi Union',
                    upazilaId: 302601,
                  ),
                ],
              ),
              bdAreasProvider(302601).overrideWith((ref) async => const []),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const FundraisingAccountSetupScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The account fetch succeeded, so the full wizard form must still
        // render — never the full-page "Verification unavailable" state.
        expect(find.text('Fundraising verification'), findsOneWidget);
        expect(find.text('Step 1 of 5'), findsOneWidget);
        expect(find.text('Account & Location'), findsOneWidget);
        expect(find.text('Verification unavailable'), findsNothing);

        // A scoped retry banner appears only around the location section.
        expect(
          find.text(
            'Unable to connect. Check your internet connection and make sure the service is available, then try again.',
          ),
          findsOneWidget,
        );
        expect(locations.calls, 1);

        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Successful retry clears the stale error.
        expect(locations.calls, 2);
        expect(
          find.text(
            'Unable to connect. Check your internet connection and make sure the service is available, then try again.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'treats a definitive session-expiry error as a redirect state, not '
      '"Verification unavailable"',
      (tester) async {
        // Deliberately uses tester.pump() (not pumpAndSettle): this state
        // keeps a CircularProgressIndicator spinning forever while
        // AuthController/AuthGate perform the real redirect to login, so
        // pumpAndSettle would never settle.
        final repo = _SetupScreenRepository(
          loadAccount: () async {
            throw ApiClientException(
              message: 'Unauthorized',
              dioExceptionType: 'badResponse',
              statusCode: 401,
              method: 'GET',
              url: '/api/v1/fundraising/account/me',
            );
          },
        );
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              fundraisingRepositoryProvider.overrideWithValue(repo),
              bdLocationsRepositoryProvider.overrideWithValue(
                _TestBdLocationsRepository(),
              ),
              fundraisingVerificationRecoveryServiceProvider.overrideWithValue(
                _MemoryRecoveryService(),
              ),
              bdDivisionsProvider.overrideWith(
                (ref) async => const <BdDivision>[
                  BdDivision(id: 30, code: 'DIV-30', nameEn: 'Dhaka'),
                ],
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const FundraisingAccountSetupScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Verification unavailable'), findsNothing);
        expect(find.text('Session expired'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'keeps the Continue label on one line at 320dp width and large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await _pump(tester, accountProvider: () async => null);

        expect(find.text('Back'), findsNothing);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Continu e'), findsNothing);
      },
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<FundraisingAccount?> Function() accountProvider,
  _SetupScreenRepository? repository,
  List<BdDivision> divisions = const <BdDivision>[],
  List<BdDistrict> districts = const <BdDistrict>[],
  List<BdUpazila> upazilas = const <BdUpazila>[],
  List<BdUnion>? unions,
  List<BdArea>? areas,
  Map<String, dynamic>? recoveryData,
}) async {
  final repo =
      repository ?? _SetupScreenRepository(loadAccount: accountProvider);
  final unionData = unions;
  final areaData = areas;
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        fundraisingRepositoryProvider.overrideWithValue(repo),
        bdLocationsRepositoryProvider.overrideWithValue(
          _TestBdLocationsRepository(),
        ),
        fundraisingVerificationRecoveryServiceProvider.overrideWithValue(
          _MemoryRecoveryService(initialValue: recoveryData),
        ),
        bdDivisionsProvider.overrideWith(
          (ref) async => divisions.isNotEmpty
              ? divisions
              : const <BdDivision>[
                  BdDivision(id: 30, code: 'DIV-30', nameEn: 'Dhaka'),
                ],
        ),
        if (divisions.any((division) => division.id == 30) || divisions.isEmpty)
          bdDistrictsProvider(30).overrideWith(
            (ref) async =>
                districts
                    .where((district) => district.divisionId == 30)
                    .toList()
                    .isNotEmpty
                ? districts
                      .where((district) => district.divisionId == 30)
                      .toList()
                : const <BdDistrict>[
                    BdDistrict(
                      id: 3026,
                      code: 'DIS-3026',
                      nameEn: 'Dhaka',
                      divisionId: 30,
                    ),
                  ],
          ),
        if (divisions.any((division) => division.id == 40))
          bdDistrictsProvider(40).overrideWith(
            (ref) async => districts
                .where((district) => district.divisionId == 40)
                .toList(),
          ),
        if (districts.any((district) => district.id == 3026) ||
            districts.isEmpty)
          bdUpazilasProvider(3026).overrideWith(
            (ref) async =>
                upazilas
                    .where((upazila) => upazila.districtId == 3026)
                    .toList()
                    .isNotEmpty
                ? upazilas
                      .where((upazila) => upazila.districtId == 3026)
                      .toList()
                : const <BdUpazila>[
                    BdUpazila(
                      id: 302601,
                      code: 'UPZ-302601',
                      nameEn: 'Dhanmondi',
                      districtId: 3026,
                    ),
                  ],
          ),
        if (districts.any((district) => district.id == 3027))
          bdUpazilasProvider(3027).overrideWith(
            (ref) async => upazilas
                .where((upazila) => upazila.districtId == 3027)
                .toList(),
          ),
        if (upazilas.any((upazila) => upazila.id == 302601) || upazilas.isEmpty)
          bdUnionsProvider(302601).overrideWith(
            (ref) async => unionData != null
                ? unionData.where((union) => union.upazilaId == 302601).toList()
                : const <BdUnion>[
                    BdUnion(
                      id: 5001,
                      code: 'UNI-5001',
                      nameEn: 'Dhanmondi Union',
                      upazilaId: 302601,
                    ),
                  ],
          ),
        if (upazilas.any((upazila) => upazila.id == 302601) || upazilas.isEmpty)
          bdAreasProvider(302601).overrideWith(
            (ref) async => areaData != null
                ? areaData.where((area) => area.upazilaId == 302601).toList()
                : const <BdArea>[],
          ),
        if (upazilas.any((upazila) => upazila.id == 302602))
          bdUnionsProvider(302602).overrideWith(
            (ref) async => unionData != null
                ? unionData.where((union) => union.upazilaId == 302602).toList()
                : const <BdUnion>[],
          ),
        if (upazilas.any((upazila) => upazila.id == 302602))
          bdAreasProvider(302602).overrideWith(
            (ref) async => areaData != null
                ? areaData.where((area) => area.upazilaId == 302602).toList()
                : const <BdArea>[],
          ),
        if (upazilas.any((upazila) => upazila.id == 402601))
          bdUnionsProvider(402601).overrideWith(
            (ref) async => unionData != null
                ? unionData.where((union) => union.upazilaId == 402601).toList()
                : const <BdUnion>[],
          ),
        if (upazilas.any((upazila) => upazila.id == 402601))
          bdAreasProvider(402601).overrideWith(
            (ref) async => areaData != null
                ? areaData.where((area) => area.upazilaId == 402601).toList()
                : const <BdArea>[],
          ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FundraisingAccountSetupScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillStepOne(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'House 12, Road 1');
  await tester.enterText(find.byType(TextFormField).at(1), 'House 12, Road 1');
  await tester.pump();
}

Future<void> _selectChoice(
  WidgetTester tester,
  int selectorIndex,
  String choice,
) async {
  final labelCandidates = <int, List<String>>{
    1: <String>['Division *'],
    2: <String>['District *'],
    3: <String>['Upazila / Thana *'],
    4: <String>['Union *', 'Union / Ward *'],
  };
  final candidates = labelCandidates[selectorIndex];
  if (candidates == null) {
    throw ArgumentError.value(selectorIndex, 'selectorIndex');
  }

  final selector = candidates
      .map(
        (label) =>
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      )
      .firstWhere((finder) => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final choiceFinder = find.text(choice).last;
  await tester.tap(choiceFinder);
  await tester.pumpAndSettle();
}

Future<void> _tapSelector(WidgetTester tester, int selectorIndex) async {
  final labelCandidates = <int, List<String>>{
    1: <String>['Division *'],
    2: <String>['District *'],
    3: <String>['Upazila / Thana *'],
    4: <String>['Union *', 'Union / Ward *'],
  };
  final candidates = labelCandidates[selectorIndex];
  if (candidates == null) {
    throw ArgumentError.value(selectorIndex, 'selectorIndex');
  }

  final selector = candidates
      .map(
        (label) =>
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      )
      .firstWhere((finder) => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
}

class _RetryingAccountSource {
  int calls = 0;
  Completer<FundraisingAccount?>? retryCompleter;

  Future<FundraisingAccount?> load() async {
    calls += 1;
    if (calls == 1) {
      throw ApiClientException(
        message: 'Connection refused',
        dioExceptionType: 'connectionError',
        method: 'GET',
        url: 'http://192.168.10.111:7200/api/v1/fundraising/account/me',
      );
    }
    retryCompleter ??= Completer<FundraisingAccount?>();
    return retryCompleter!.future;
  }

  void completeRetry(FundraisingAccount? account) {
    retryCompleter?.complete(account);
  }
}

class _SetupScreenRepository extends FundraisingRepository {
  _SetupScreenRepository({
    required Future<FundraisingAccount?> Function() loadAccount,
  }) : _loadAccount = loadAccount,
       super(_FakeApiClient());

  final Future<FundraisingAccount?> Function() _loadAccount;
  Map<String, dynamic>? lastUpdatePayload;
  int updateCalls = 0;
  int submitCalls = 0;

  @override
  Future<FundraisingAccount?> fetchMyAccount() => _loadAccount();

  @override
  Future<FundraisingAccount> updateMyAccount(
    Map<String, dynamic> payload,
  ) async {
    updateCalls += 1;
    lastUpdatePayload = Map<String, dynamic>.from(payload);
    return _completedAccountFromPayload(payload);
  }

  @override
  Future<void> submitMyAccount() async {
    submitCalls += 1;
  }
}

FundraisingAccount _completedAccount({
  required String status,
  String? accountType = 'INDIVIDUAL',
  List<FundraisingAccountDocument> documents =
      const <FundraisingAccountDocument>[],
}) {
  return FundraisingAccount(
    id: 1,
    status: status,
    accountType: accountType,
    presentAddress: 'Dhaka',
    permanentAddress: 'Dhaka',
    occupation: 'Volunteer',
    divisionId: 30,
    districtId: 3026,
    upazilaId: 302601,
    unionId: 5001,
    areaId: 5001,
    dateOfBirth: DateTime.utc(1995, 1, 1),
    nationalIdNumber: '1234567890',
    birthRegNumber: null,
    studentIdNumber: null,
    area: 'Dhanmondi',
    rescueSinceYear: null,
    orgName: null,
    orgDescription: null,
    orgWorkType: null,
    submittedAt: DateTime.utc(2026, 1, 1),
    documents: documents,
    countryCode: 'BD',
    countryName: null,
    stateName: null,
    cityName: null,
    addressLine: null,
    latitude: null,
    longitude: null,
    formattedAddress: 'Dhaka, Bangladesh',
  );
}

FundraisingAccount _completedAccountFromPayload(Map<String, dynamic> payload) {
  return FundraisingAccount(
    id: 1,
    status: 'DRAFT',
    accountType: payload['accountType']?.toString(),
    presentAddress: payload['presentAddress']?.toString(),
    permanentAddress: payload['permanentAddress']?.toString(),
    occupation: payload['occupation']?.toString(),
    divisionId: (payload['divisionId'] as num?)?.toInt(),
    districtId: (payload['districtId'] as num?)?.toInt(),
    upazilaId: (payload['upazilaId'] as num?)?.toInt(),
    unionId: (payload['unionId'] as num?)?.toInt(),
    areaId: (payload['areaId'] as num?)?.toInt(),
    dateOfBirth: payload['dateOfBirth'] == null
        ? null
        : DateTime.tryParse(payload['dateOfBirth'].toString()),
    nationalIdNumber: payload['nationalIdNumber']?.toString(),
    birthRegNumber: payload['birthRegNumber']?.toString(),
    studentIdNumber: payload['studentIdNumber']?.toString(),
    passportNumber: payload['passportNumber']?.toString(),
    verificationDraftJson: payload['verificationDraftJson'] is Map
        ? Map<String, dynamic>.from(payload['verificationDraftJson'] as Map)
        : null,
    area: payload['area']?.toString(),
    rescueSinceYear: null,
    orgName: payload['orgName']?.toString(),
    orgDescription: payload['orgDescription']?.toString(),
    orgWorkType: payload['orgWorkType']?.toString(),
    submittedAt: null,
    documents: const <FundraisingAccountDocument>[],
    countryCode: payload['countryCode']?.toString(),
    countryName: payload['countryName']?.toString(),
    stateName: payload['stateName']?.toString(),
    cityName: payload['cityName']?.toString(),
    addressLine: payload['addressLine']?.toString(),
    latitude: (payload['latitude'] as num?)?.toDouble(),
    longitude: (payload['longitude'] as num?)?.toDouble(),
    formattedAddress: payload['formattedAddress']?.toString(),
  );
}

class _MemoryRecoveryService extends FundraisingVerificationRecoveryService {
  _MemoryRecoveryService({Map<String, dynamic>? initialValue})
    : _value = initialValue;

  Map<String, dynamic>? _value;

  @override
  Future<Map<String, dynamic>?> load() async => _value;

  @override
  Future<void> save(Map<String, dynamic> data) async {
    _value = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(dio: Dio());

  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? headers,
  }) {
    return Future<dynamic>.value(null);
  }

  @override
  Future<dynamic> patch(
    String url,
    Map<String, dynamic> data, {
    bool auth = true,
    Map<String, String>? headers,
  }) {
    return Future<dynamic>.value(null);
  }
}

class _FailingThenOkBdLocationsRepository extends BdLocationsRepository {
  _FailingThenOkBdLocationsRepository() : super(_FakeApiClient());

  int calls = 0;

  @override
  Future<Map<String, dynamic>> validateSelection({
    int? divisionId,
    int? districtId,
    int? upazilaId,
    int? unionId,
    int? areaId,
  }) async {
    calls += 1;
    if (calls == 1) {
      throw ApiClientException(
        message: 'Connection refused',
        dioExceptionType: 'connectionError',
        method: 'POST',
        url: '/api/v1/location-master/validate-selection',
      );
    }
    return <String, dynamic>{
      'ok': true,
      'data': <String, dynamic>{
        'divisionId': divisionId,
        'districtId': districtId,
        'upazilaId': upazilaId,
        'unionId': unionId,
        'areaId': areaId,
      },
    };
  }
}

class _TestBdLocationsRepository extends BdLocationsRepository {
  _TestBdLocationsRepository() : super(_FakeApiClient());

  @override
  Future<Map<String, dynamic>> validateSelection({
    int? divisionId,
    int? districtId,
    int? upazilaId,
    int? unionId,
    int? areaId,
  }) async {
    if (divisionId == 30 && districtId != null && districtId != 3026) {
      throw ApiClientException(
        message: 'District does not belong to the selected division.',
        dioExceptionType: 'badResponse',
        statusCode: 400,
        code: 'DISTRICT_DIVISION_MISMATCH',
        method: 'POST',
        url: '/api/v1/location-master/validate-selection',
      );
    }
    if (districtId == 3026 && upazilaId != null && upazilaId != 302601) {
      throw ApiClientException(
        message: 'Upazila does not belong to the selected district.',
        dioExceptionType: 'badResponse',
        statusCode: 400,
        code: 'UPAZILA_DISTRICT_MISMATCH',
        method: 'POST',
        url: '/api/v1/location-master/validate-selection',
      );
    }
    return <String, dynamic>{
      'ok': true,
      'data': <String, dynamic>{
        'divisionId': divisionId,
        'districtId': districtId,
        'upazilaId': upazilaId,
        'unionId': unionId,
        'areaId': areaId,
      },
    };
  }
}
