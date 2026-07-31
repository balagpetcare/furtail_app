// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:furtail_app/features/fundraising/data/models/fundraising_draft_models.dart';
import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_deadline_options.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_payout_methods_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_campaign_preview_card.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_create_wizard_widgets.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_media_needs_attention_panel.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_status_views.dart'
    hide FundraisingStatusChip;
import 'package:furtail_app/features/location/presentation/widgets/location_selector_widget.dart';
import 'package:furtail_app/features/media/composer/media_composer_controller.dart';
import 'package:furtail_app/features/media/composer/media_composer_policy.dart';
import 'package:furtail_app/features/media/composer/media_composer_widgets.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:furtail_app/features/media/composer/media_preparation_service.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:furtail_app/features/pets/domain/entities/pet_entity.dart';
import 'package:furtail_app/features/pets/presentation/providers/pet_providers.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/fundraising/data/fundraising_error_mapper.dart';
import 'package:furtail_app/core/permissions/permission_service.dart';
import 'package:furtail_app/l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';

class FundraisingCreateScreen extends ConsumerStatefulWidget {
  const FundraisingCreateScreen({
    super.key,
    this.controller,
    this.mediaController,
    this.repository,
    this.recoveryService,
    this.postsRemoteDs,
    this.mediaPreparationService,
  });

  final FundraisingCreateWizardController? controller;
  final MediaComposerController? mediaController;
  final FundraisingRepository? repository;
  final FundraisingDraftRecoveryService? recoveryService;
  final PostsRemoteDs? postsRemoteDs;
  final MediaPreparationService? mediaPreparationService;

  @override
  ConsumerState<FundraisingCreateScreen> createState() =>
      _FundraisingCreateScreenState();
}

class _FundraisingCreateScreenState
    extends ConsumerState<FundraisingCreateScreen> {
  static const List<FundraisingWizardStep> _activeSteps =
      <FundraisingWizardStep>[
        FundraisingWizardStep.fundraiserType,
        FundraisingWizardStep.storyAndGoal,
        FundraisingWizardStep.caseDetails,
        FundraisingWizardStep.location,
        FundraisingWizardStep.evidence,
        FundraisingWizardStep.preview,
      ];

  static const List<String> _documentExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static const List<String> _categoryValues = <String>[
    'TREATMENT',
    'RESCUE',
    'SHELTER',
    'FOOD',
    'EQUIPMENT',
    'OTHER',
  ];

  static const List<String> _beneficiaryTypes = <String>[
    'PET',
    'PERSON',
    'SHELTER',
    'ORGANIZATION',
    'COMMUNITY',
    'OTHER',
  ];

  static const List<String> _urgencyValues = <String>[
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL',
  ];

  final _picker = ImagePicker();
  final _moneyFormat = NumberFormat.decimalPattern('en');

  late final PostsRemoteDs _postsDs;
  late final MediaPreparationService _mediaPreparation;
  late final FundraisingCreateWizardController _wizardController;
  late final MediaComposerController _mediaController;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _shortDescriptionCtrl;
  late final TextEditingController _whatHappenedCtrl;
  late final TextEditingController _whyUrgentCtrl;
  late final TextEditingController _fundUsageCtrl;
  late final TextEditingController _storyCtrl;
  late final TextEditingController _goalCtrl;
  late final TextEditingController _monthlyGoalCtrl;
  late final TextEditingController _beneficiaryCtrl;
  late final TextEditingController _treatmentProviderCtrl;
  late final TextEditingController _estimatedTotalCtrl;
  late final TextEditingController _expenseNotesCtrl;
  late final TextEditingController _customLocationCtrl;

  final Map<String, TextEditingController> _expenseControllers =
      <String, TextEditingController>{};

  final ScrollController _scrollController = ScrollController();
  final PermissionService _permissionService = PermissionService();

  bool _ownsWizardController = false;
  bool _ownsMediaController = false;
  // Guards `_handleMediaChanged` from syncing a just-restored media item's
  // id into the draft before `_reconcileMediaSessionWithDraft` has decided
  // whether that item actually belongs to this draft (see there for why).
  bool _mediaSessionReconciled = false;
  bool _syncingFields = false;
  bool _initializing = true;
  bool _pickingMedia = false;
  bool _showExpenseBreakdown = false;
  bool _capturingCurrentLocation = false;
  bool _showValidation = false;
  FundraisingSafeError? _preflightError;

  List<PetEntity> _pets = const <PetEntity>[];

  @override
  void initState() {
    super.initState();
    _postsDs = widget.postsRemoteDs ?? PostsRemoteDs();
    _mediaPreparation =
        widget.mediaPreparationService ?? const MediaPreparationService();
    _wizardController =
        widget.controller ??
        FundraisingCreateWizardController(
          repository:
              widget.repository ?? ref.read(fundraisingRepositoryProvider),
          recoveryService:
              widget.recoveryService ?? FundraisingDraftRecoveryService(),
        );
    _ownsWizardController = widget.controller == null;

    _mediaController =
        widget.mediaController ??
        MediaComposerController(
          policy: MediaComposerPolicy.fundraising,
          draftStorageKey: 'fundraising:wizard:v2',
          uploadMedia:
              (
                item, {
                void Function(int sentBytes, int totalBytes)? onProgress,
                CancelToken? cancelToken,
              }) {
                return _postsDs.uploadMediaDetailedWithProgress(
                  File(item.localPath!),
                  onProgress: onProgress,
                  cancelToken: cancelToken,
                  draftId: item.id,
                  uploadContext: MediaComposerPolicy.fundraising.uploadContext,
                  folder: MediaComposerPolicy.fundraising.folder,
                  trimStartMs: item.isVideo ? item.trimStartMs : null,
                  trimEndMs: item.isVideo ? item.trimEndMs : null,
                  mute: item.isVideo ? item.mute : null,
                  volume: item.isVideo ? item.volume : null,
                  coverTimestampMs: item.isVideo ? item.coverTimestampMs : null,
                  aspectRatio: item.isVideo ? item.aspectRatio : null,
                  quality: item.isVideo ? item.quality : null,
                );
              },
        );
    _ownsMediaController = widget.mediaController == null;

    _titleCtrl = TextEditingController();
    _shortDescriptionCtrl = TextEditingController();
    _whatHappenedCtrl = TextEditingController();
    _whyUrgentCtrl = TextEditingController();
    _fundUsageCtrl = TextEditingController();
    _storyCtrl = TextEditingController();
    _goalCtrl = TextEditingController();
    _monthlyGoalCtrl = TextEditingController();
    _beneficiaryCtrl = TextEditingController();
    _treatmentProviderCtrl = TextEditingController();
    _estimatedTotalCtrl = TextEditingController();
    _expenseNotesCtrl = TextEditingController();
    _customLocationCtrl = TextEditingController();

    _wizardController.addListener(_handleWizardChanged);
    _mediaController.addListener(_handleMediaChanged);
    _initializeAsync();
  }

  FundraisingWizardStep _stepForIndex(int index) {
    return _activeSteps[index.clamp(0, _activeSteps.length - 1)];
  }

  int _indexForStep(FundraisingWizardStep step) {
    final index = _activeSteps.indexOf(step);
    return index < 0 ? 0 : index;
  }

  Future<void> _initializeAsync() async {
    // Restores whatever was last persisted under the shared media-session
    // key. This is not yet known to belong to a real draft — a previous
    // session that never reached submit/discard can leave stale items
    // here — so nothing is uploaded until `_reconcileMediaSessionWithDraft`
    // confirms there is an actual draft to attach it to.
    await _mediaController.restore();
    if (!mounted) return;

    final FundraisingRepository repo =
        widget.repository ?? ref.read(fundraisingRepositoryProvider);
    FundraisingAccount? account;
    try {
      account = await repo.fetchMyAccount();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preflightError = mapFundraisingSafeError(error);
        _initializing = false;
      });
      return;
    }

    if (!mounted) return;
    // Fundraising/payout verification deliberately does NOT gate opening,
    // filling in, or submitting a fundraiser — an unverified, pending,
    // update-required or payout-rejected account runs the full wizard and
    // can submit for review. Verification is enforced only when money
    // leaves the platform (withdrawal / cash-out / payout activation), so
    // there is no verification preflight or redirect here. The account is
    // still seeded below purely so the wizard can display status context.
    _wizardController.seedAccount(account);
    await _wizardController.initialize();
    if (!mounted) return;
    await _reconcileMediaSessionWithDraft();
    await _loadPets();
    if (!mounted) return;
    _buildExpenseControllers();
    _applyDraftToTextFields();
    _syncUploadedMediaIds();
    await _restoreInitialStep();
    setState(() => _initializing = false);
  }

  /// A genuinely new fundraiser (no resumable draft — no remote draft id
  /// and no locally entered content) must start with an empty media list,
  /// even if a previous, improperly-cleared session left items in the
  /// shared media-session storage. Only after this reconciliation is it
  /// safe to start uploading whatever remains.
  Future<void> _reconcileMediaSessionWithDraft() async {
    // Freshness is judged from the recovered draft's own fields — never
    // from `mediaIds`, which the reactive `_handleMediaChanged` listener
    // (gated by `_mediaSessionReconciled` below) would otherwise let a
    // just-restored, not-yet-reconciled media item poison before this
    // check ever runs.
    final draft = _wizardController.draft;
    final hasNonMediaContent =
        draft.title.trim().isNotEmpty ||
        draft.shortDescription.trim().isNotEmpty ||
        draft.story.trim().isNotEmpty ||
        draft.whatHappened.trim().isNotEmpty ||
        draft.whyUrgent.trim().isNotEmpty ||
        draft.fundUsage.trim().isNotEmpty ||
        draft.category.trim().isNotEmpty ||
        draft.beneficiaryName.trim().isNotEmpty ||
        (draft.targetAmountMinor ?? 0) > 0 ||
        (draft.estimatedExpenseMinor ?? 0) > 0 ||
        draft.remoteDraftId != null;
    if (!hasNonMediaContent) {
      await _mediaController.reset();
    }
    _mediaSessionReconciled = true;
    if (!mounted) return;
    unawaited(_mediaController.ensureUploaded().catchError((_) => <int>[]));
  }

  Future<void> _restoreInitialStep() async {
    final targetIndex = _firstIncompleteStepIndex();
    if (_wizardController.draft.stepIndex == targetIndex) return;
    await _wizardController.updateDraft(
      (current) => current.copyWith(stepIndex: targetIndex),
      autosave: false,
    );
  }

  int _firstIncompleteStepIndex() {
    for (var index = 0; index < _activeSteps.length; index += 1) {
      final step = _stepForIndex(index);
      if (_validationMessagesForStep(step).isNotEmpty) {
        return index;
      }
    }
    return _activeSteps.length - 1;
  }

  Future<void> _loadPets() async {
    try {
      final usecase = ref.read(getPetsUsecaseProvider);
      final pets = await usecase();
      if (!mounted) return;
      _pets = pets;
    } catch (_) {
      _pets = const <PetEntity>[];
    }
  }

  void _buildExpenseControllers() {
    if (_expenseControllers.isNotEmpty) return;
    for (final expense in _wizardController.draft.expenses) {
      final controller = TextEditingController(
        text: _formatMinorAsDisplay(expense.amountMinor),
      );
      controller.addListener(() {
        if (_syncingFields) return;
        final parsed = _normalizeFormattedAmount(controller);
        _updateExpense(expense.code, parsed);
      });
      _expenseControllers[expense.code] = controller;
    }
  }

  void _handleWizardChanged() {
    if (!mounted) return;
    if (!_initializing) {
      _applyDraftToTextFields();
    }
    setState(() {});
  }

  void _handleMediaChanged() {
    if (!mounted) return;
    if (_mediaSessionReconciled) {
      _syncUploadedMediaIds();
    }
    setState(() {});
  }

  void _syncUploadedMediaIds() {
    final ids = _mediaController.items
        .where((item) => item.remoteMediaId != null)
        .map((item) => item.remoteMediaId!)
        .toList();
    if (listEquals(ids, _wizardController.draft.mediaIds)) return;
    unawaited(
      _wizardController.updateDraft(
        (current) => current.copyWith(mediaIds: ids),
        autosave: false,
      ),
    );
  }

  void _applyDraftToTextFields() {
    _syncingFields = true;
    final draft = _wizardController.draft;
    _titleCtrl.text = draft.title;
    _shortDescriptionCtrl.text = draft.shortDescription;
    _whatHappenedCtrl.text = draft.whatHappened;
    _whyUrgentCtrl.text = draft.whyUrgent;
    _fundUsageCtrl.text = draft.fundUsage;
    _storyCtrl.text = draft.story;
    _goalCtrl.text = _formatMinorAsDisplay(draft.targetAmountMinor);
    _monthlyGoalCtrl.text = _formatMinorAsDisplay(draft.monthlyGoalMinor);
    _beneficiaryCtrl.text = draft.beneficiaryName;
    _treatmentProviderCtrl.text = draft.treatmentProvider;
    _estimatedTotalCtrl.text = _formatMinorAsDisplay(
      draft.estimatedExpenseMinor,
    );
    _expenseNotesCtrl.text = draft.expenseNotes;
    _customLocationCtrl.text = draft.customLocationNote;
    for (final expense in draft.expenses) {
      final controller = _expenseControllers[expense.code];
      if (controller != null) {
        controller.text = _formatMinorAsDisplay(expense.amountMinor);
      }
    }
    _syncingFields = false;
  }

  String _formatMinorAsDisplay(int? amountMinor) {
    if (amountMinor == null || amountMinor <= 0) return '';
    return _moneyFormat.format(amountMinor);
  }

  int? _normalizeFormattedAmount(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = digits.isEmpty ? null : int.tryParse(digits);
    final formatted = parsed == null ? '' : _moneyFormat.format(parsed);
    if (controller.text != formatted) {
      final selectionIndex = formatted.length;
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: selectionIndex),
      );
    }
    return parsed;
  }

  Future<bool> _confirmExit() async {
    // The wizard form never opened, so nothing in this session is the user's
    // work to lose: preflight failed, or we are still initializing. Media
    // restored by `_initializeAsync` before the account fetch must not be
    // mistaken for an edit the user made here.
    if (_preflightError != null ||
        _initializing ||
        !_wizardController.initialized) {
      return true;
    }
    if (!_wizardController.draft.hasMeaningfulContent &&
        _mediaController.items.isEmpty) {
      return true;
    }
    final t = AppLocalizations.of(context)!;
    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t.fundraisingLeaveTitle),
          content: Text(t.fundraisingLeaveBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('stay'),
              child: Text(t.fundraisingStay),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: Text(t.fundraisingDiscard),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: Text(t.fundraisingSaveAndLeave),
            ),
          ],
        );
      },
    );

    if (action == 'save') {
      await _wizardController.persistRecovery();
      await _wizardController.saveDraftNow();
      return true;
    }
    if (action == 'discard') {
      // Discarding must clear this draft's own local session — recovery
      // state and its media — so a later "Create Fundraiser" never resumes
      // it or shows its photos. A submitted campaign's media is untouched:
      // this only clears local wizard/session storage, never remote data.
      await _wizardController.clearRecoveredDraft();
      await _mediaController.reset();
      return true;
    }
    return false;
  }

  Future<void> _pickImages() async {
    if (_pickingMedia) return;
    _pickingMedia = true;
    try {
      final files = await _picker.pickMultiImage(imageQuality: 100);
      if (files.isEmpty || !mounted) return;
      final items = await _mediaPreparation.prepareImages(
        context,
        files.map((entry) => File(entry.path)).toList(),
      );
      if (items.isEmpty) return;
      await _mediaController.addItems(items);
      unawaited(_mediaController.ensureUploaded().catchError((_) => <int>[]));
    } catch (error) {
      _showError(_localizedMediaError(error));
    } finally {
      _pickingMedia = false;
    }
  }

  Future<void> _pickVideo() async {
    if (_pickingMedia) return;
    _pickingMedia = true;
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final item = await _mediaPreparation.prepareVideo(
        context,
        File(file.path),
      );
      if (item == null) return;
      await _mediaController.addItems(<MediaDraftItem>[item]);
      unawaited(_mediaController.ensureUploaded().catchError((_) => <int>[]));
    } catch (error) {
      _showError(_localizedMediaError(error));
    } finally {
      _pickingMedia = false;
    }
  }

  Future<void> _pickDocuments() async {
    if (_pickingMedia) return;
    _pickingMedia = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _documentExtensions,
      );
      final paths =
          result?.paths.whereType<String>().toList() ?? const <String>[];
      if (paths.isEmpty) return;
      await _mediaController.addItems(
        await _mediaPreparation.prepareDocuments(
          paths.map((path) => File(path)).toList(),
        ),
      );
      unawaited(_mediaController.ensureUploaded().catchError((_) => <int>[]));
    } catch (error) {
      _showError(_localizedMediaError(error));
    } finally {
      _pickingMedia = false;
    }
  }

  Future<void> _editMediaItem(MediaDraftItem item) async {
    if (item.isUploading || item.isPreparing) return;
    try {
      if (item.isDocument) {
        final replacement = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: _documentExtensions,
        );
        final path = replacement?.files.single.path;
        if (path == null) return;
        await _mediaController.replaceItem(
          item.id,
          await _mediaPreparation.prepareReplacementDocument(
            File(path),
            existingId: item.id,
            isCover: item.isCover,
          ),
        );
        unawaited(_mediaController.ensureUploaded().catchError((_) => <int>[]));
        return;
      }

      final localPath = item.localPath;
      if (localPath == null ||
          localPath.isEmpty ||
          !File(localPath).existsSync()) {
        _showError(AppLocalizations.of(context)!.fundraisingMissingLocalFile);
        return;
      }

      if (item.isVideo) {
        final replacement = await _mediaPreparation.prepareVideo(
          context,
          File(localPath),
          existingId: item.id,
          isCover: item.isCover,
        );
        if (replacement == null) return;
        await _mediaController.replaceItem(item.id, replacement);
        unawaited(_mediaController.ensureUploaded().catchError((_) => <int>[]));
        return;
      }

      final replacement = await _mediaPreparation.prepareReplacementImage(
        context,
        File(localPath),
        existingId: item.id,
        isCover: item.isCover,
      );
      if (replacement == null) return;
      await _mediaController.replaceItem(item.id, replacement);
      unawaited(_mediaController.ensureUploaded().catchError((_) => <int>[]));
    } catch (error) {
      _showError(_localizedMediaError(error));
    }
  }

  Future<void> _openPayoutMethods() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FundraisingPayoutMethodsScreen()),
    );
    if (!mounted) return;
    await _wizardController.refreshEligibility();
  }

  Future<void> _selectDeadline() async {
    final selectedDays = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: FundraisingDeadlineOptions.allowedDurations
                .map(
                  (days) => ListTile(
                    title: Text('$days days'),
                    trailing:
                        _wizardController.draft.campaignDurationDays == days
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(days),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
    if (selectedDays == null) return;
    final deadline = FundraisingDeadlineOptions.calculateDeadline(
      now: DateTime.now(),
      durationDays: selectedDays,
    );
    await _wizardController.updateDraft(
      (current) => current.copyWith(
        campaignDurationDays: selectedDays,
        endsAt: deadline,
        deadline: deadline,
      ),
    );
  }

  Future<void> _setFundingMode(String value) async {
    final normalized = value.trim().toUpperCase();
    await _wizardController.updateDraft(
      (current) => current.copyWith(
        fundingMode: normalized.isEmpty ? 'ONE_TIME' : normalized,
        clearTargetAmountMinor: normalized == 'ONGOING',
        clearMonthlyGoalMinor: normalized != 'ONGOING',
        clearCampaignDurationDays: normalized == 'ONGOING',
        clearEndsAt: normalized == 'ONGOING',
        clearDeadline: normalized == 'ONGOING',
        clearNextReviewAt: normalized != 'ONGOING',
        startsAt: normalized == 'ONGOING'
            ? (current.startsAt ?? DateTime.now())
            : current.startsAt,
        nextReviewAt: normalized == 'ONGOING'
            ? (current.nextReviewAt ??
                  DateTime.now().add(const Duration(days: 30)))
            : current.nextReviewAt,
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_capturingCurrentLocation) return;
    _capturingCurrentLocation = true;
    try {
      final t = AppLocalizations.of(context)!;
      final permissionGranted = await _permissionService.ensure(
        AppPermission.locationWhenInUse,
      );
      if (!permissionGranted || !mounted) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      await _wizardController.updateDraft(
        (current) => current.copyWith(
          securityLatitude: position.latitude,
          securityLongitude: position.longitude,
          securityLocationAccuracy: position.accuracy.toDouble(),
          securityLocationCapturedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.fundraisingCurrentLocationCaptured)),
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        AppLocalizations.of(context)!.fundraisingLocationPermissionFailed,
      );
    } finally {
      _capturingCurrentLocation = false;
    }
  }

  Future<void> _updateExpense(String code, int? amountMinor) {
    return _wizardController.updateDraft((current) {
      final next = current.expenses
          .map(
            (expense) => expense.code == code
                ? expense.copyWith(
                    amountMinor: amountMinor,
                    clearAmountMinor: amountMinor == null,
                  )
                : expense,
          )
          .toList();
      final estimated = next.fold<int>(
        0,
        (total, expense) => total + (expense.amountMinor ?? 0),
      );
      return current.copyWith(
        expenses: next,
        estimatedExpenseMinor: estimated > 0 ? estimated : null,
      );
    });
  }

  Future<void> _saveDraftManually() async {
    await _wizardController.saveDraftNow();
    if (!mounted) return;
    final failure = _wizardController.draftFailure;
    if (failure != null) {
      _showError(_localizedFailureMessage(failure));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.fundraisingDraftSaved),
      ),
    );
  }

  Future<void> _useSuggestedTarget() async {
    final suggested = _wizardController.draft.suggestedTargetMinor;
    if (suggested <= 0) return;
    _goalCtrl.text = _formatMinorAsDisplay(suggested);
    await _wizardController.updateDraft(
      (current) => current.copyWith(targetAmountMinor: suggested),
    );
  }

  Future<void> _continueOrSubmit() async {
    final currentStep =
        _activeSteps[_wizardController.draft.stepIndex.clamp(
          0,
          _activeSteps.length - 1,
        )];
    final validation = _navigationValidationMessagesForStep(currentStep);
    if (validation.isNotEmpty) {
      setState(() => _showValidation = true);
      _scrollToTop();
      return;
    }

    if (currentStep == FundraisingWizardStep.preview) {
      try {
        final mediaIds = await _mediaController.ensureUploaded();
        await _wizardController.updateDraft(
          (current) => current.copyWith(mediaIds: mediaIds),
          autosave: false,
        );
        final result = await _wizardController.submitForReview();
        if (!mounted) return;
        if (result == null || result.status.toUpperCase() != 'PENDING_REVIEW') {
          final failure = _wizardController.submissionFailure;
          _showError(
            _localizedFailureMessage(
              failure ??
                  const FundraisingWizardFailure(
                    type: FundraisingWizardErrorType.submitFailed,
                  ),
            ),
          );
          return;
        }
        await _mediaController.clearPersistedDraft();
        ref.invalidate(fundraisingFeedProvider);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) {
            final t = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(t.fundraisingSubmittedTitle),
              content: Text(t.fundraisingSubmittedBody),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.fundraisingDone),
                ),
              ],
            );
          },
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (error) {
        _showError(_localizedMediaError(error));
      }
      return;
    }

    await _wizardController.updateDraft(
      (current) => current.copyWith(stepIndex: current.stepIndex + 1),
      autosave: false,
    );
    setState(() => _showValidation = false);
    _scrollToTop();
  }

  Future<void> _cancelWizard() async {
    final shouldPop = await _confirmExit();
    if (!shouldPop || !mounted) return;
    Navigator.of(context).pop();
  }

  void _goBackStep() {
    if (_wizardController.draft.stepIndex <= 0) return;
    unawaited(
      _wizardController.updateDraft(
        (current) => current.copyWith(stepIndex: current.stepIndex - 1),
        autosave: false,
      ),
    );
    setState(() => _showValidation = false);
    _scrollToTop();
  }

  void _jumpToStep(FundraisingWizardStep step) {
    unawaited(
      _wizardController.updateDraft(
        (current) => current.copyWith(stepIndex: _indexForStep(step)),
        autosave: false,
      ),
    );
    setState(() => _showValidation = false);
    _scrollToTop();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String _localizedFailureMessage(FundraisingWizardFailure failure) {
    final t = AppLocalizations.of(context)!;
    switch (failure.type) {
      case FundraisingWizardErrorType.sessionExpired:
        return t.fundraisingErrorSessionExpired;
      case FundraisingWizardErrorType.timeout:
        return t.fundraisingErrorTimeout;
      case FundraisingWizardErrorType.offline:
        return t.fundraisingErrorOffline;
      case FundraisingWizardErrorType.verificationRejected:
        return t.fundraisingErrorVerificationRejected;
      case FundraisingWizardErrorType.mediaFailure:
        return failure.message ?? t.fundraisingErrorMediaFailed;
      case FundraisingWizardErrorType.saveFailed:
        return failure.message ?? t.fundraisingErrorSaveFailed;
      case FundraisingWizardErrorType.submitFailed:
        return failure.message ?? t.fundraisingErrorSubmitFailed;
      case FundraisingWizardErrorType.validation:
        return failure.message ?? t.fundraisingErrorValidation;
      case FundraisingWizardErrorType.unknown:
        return failure.message ?? t.fundraisingErrorUnknown;
    }
  }

  String _preflightErrorTitle(FundraisingSafeError? error) =>
      fundraisingErrorTitle(error);

  String _preflightErrorDescription(FundraisingSafeError? error) =>
      fundraisingErrorDescription(error);

  String _localizedMediaError(Object error) {
    if (error is MediaUploadException) {
      return error.userMessage;
    }
    return AppLocalizations.of(context)!.fundraisingErrorMediaFailed;
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _validationMessagesForStep(FundraisingWizardStep step) {
    final t = AppLocalizations.of(context)!;
    final codes = _wizardController.validationCodesForStep(
      step,
      mediaValidation: _mediaController.mediaValidation,
    );
    return codes.map((code) => _messageForValidationCode(t, code)).toList();
  }

  /// Upload work continues while the user completes the remaining wizard
  /// steps. The evidence step therefore blocks navigation only when no media
  /// has been selected or an item needs explicit retry/removal. The final
  /// Preview step still uses the strict validation above and cannot submit
  /// until every required item is READY.
  List<String> _navigationValidationMessagesForStep(
    FundraisingWizardStep step,
  ) {
    if (step != FundraisingWizardStep.evidence) {
      return _validationMessagesForStep(step);
    }

    final items = _mediaController.items;
    if (items.isEmpty) {
      return <String>[AppLocalizations.of(context)!.fundraisingValidationMedia];
    }

    final failed = items.where((item) => item.hasFailed || item.isCancelled);
    if (failed.isNotEmpty) {
      return <String>[
        failed.first.errorMessage ??
            AppLocalizations.of(context)!.fundraisingValidationMediaBlocking,
      ];
    }

    return const <String>[];
  }

  String _messageForValidationCode(AppLocalizations t, String code) {
    switch (code) {
      case 'complete_profile':
        return t.fundraisingValidationCompleteProfile;
      case 'upload_documents':
        return t.fundraisingValidationUploadDocuments;
      case 'resolve_rejection':
        return t.fundraisingValidationResolveRejection;
      case 'category_required':
        return t.fundraisingValidationCategory;
      case 'beneficiary_type_required':
        return t.fundraisingValidationBeneficiaryType;
      case 'beneficiary_name_required':
        return t.fundraisingValidationBeneficiaryName;
      case 'title_too_short':
        return t.fundraisingValidationTitle;
      case 'short_description_too_short':
        return 'Enter a short description with at least 20 characters.';
      case 'story_too_short':
        return t.fundraisingValidationStory;
      case 'what_happened_too_short':
        return 'Describe what happened in a few more words.';
      case 'why_urgent_too_short':
        return 'Explain why help is urgent.';
      case 'fund_usage_too_short':
        return 'Explain how the funds will be used.';
      case 'target_amount_required':
        return 'Add a target amount for this fundraiser.';
      case 'monthly_goal_required':
        return 'Add a monthly goal for this fundraiser.';
      case 'deadline_required':
        return t.fundraisingValidationDeadline;
      case 'estimated_expense_required':
        return 'Add an estimated total expense.';
      case 'urgency_required':
        return t.fundraisingValidationUrgency;
      case 'treatment_provider_required':
        return 'Enter the treatment provider or organization name.';
      case 'location_required':
        return t.fundraisingValidationLocation;
      case 'media_required':
        return t.fundraisingValidationMedia;
      case 'media_blocking':
        final validation = _mediaController.mediaValidation;
        if (validation.hasFailedItems) {
          return _mediaController.firstFailedItem?.errorMessage ??
              t.fundraisingValidationMediaBlocking;
        }
        return t.fundraisingValidationMediaUploading;
      default:
        return t.fundraisingErrorValidation;
    }
  }

  /// The step a Needs-attention entry for [code] should jump back to.
  FundraisingWizardStep _stepForValidationCode(String code) {
    switch (code) {
      case 'category_required':
      case 'beneficiary_type_required':
      case 'beneficiary_name_required':
      case 'title_too_short':
      case 'short_description_too_short':
        return FundraisingWizardStep.fundraiserType;
      case 'story_too_short':
      case 'what_happened_too_short':
      case 'why_urgent_too_short':
      case 'fund_usage_too_short':
      case 'urgency_required':
      case 'treatment_provider_required':
        return FundraisingWizardStep.storyAndGoal;
      case 'target_amount_required':
      case 'monthly_goal_required':
      case 'deadline_required':
      case 'estimated_expense_required':
        return FundraisingWizardStep.caseDetails;
      case 'location_required':
        return FundraisingWizardStep.location;
      case 'media_required':
      case 'media_blocking':
        return FundraisingWizardStep.evidence;
      default:
        return FundraisingWizardStep.fundraiserType;
    }
  }

  /// Every real blocker currently preventing submission, each paired with
  /// the step it can be fixed on. Never includes an account-verification or
  /// payout-method entry — neither is required to submit a fundraiser, and
  /// a pending (not-yet-VERIFIED) account is not a blocker by itself.
  List<({String message, FundraisingWizardStep step})>
  _previewNeedsAttention() {
    final t = AppLocalizations.of(context)!;
    final codes = _wizardController.validationCodesForStep(
      FundraisingWizardStep.preview,
      mediaValidation: _mediaController.mediaValidation,
    );
    return codes
        .map(
          (code) => (
            message: _messageForValidationCode(t, code),
            step: _stepForValidationCode(code),
          ),
        )
        .toList();
  }

  List<String> _evidenceValidationCodes() {
    final items = _mediaController.items;
    if (items.isEmpty) {
      return <String>['media_required'];
    }

    final failed = items.where((item) => item.hasFailed || item.isCancelled);
    final failedItem = failed.isNotEmpty ? failed.first : null;
    if (failedItem != null) {
      return <String>[
        if ((failedItem.errorMessage ?? '').trim().isNotEmpty) 'media_failed',
        if ((failedItem.errorMessage ?? '').trim().isEmpty) 'media_blocking',
      ];
    }

    final pending = items.any(
      (item) =>
          item.state == MediaDraftState.local ||
          item.isPreparing ||
          item.isUploading ||
          item.state == MediaDraftState.processing,
    );
    if (pending) {
      return <String>['media_uploading'];
    }

    final ready = items.every(
      (item) =>
          item.remoteMediaId != null &&
          (item.state == MediaDraftState.ready ||
              item.state == MediaDraftState.uploaded),
    );
    if (!ready) {
      return <String>['media_uploading'];
    }

    return const <String>[];
  }

  bool _canContinueFromCurrentStep(FundraisingWizardStep step) {
    return _navigationValidationMessagesForStep(step).isEmpty;
  }

  Set<FundraisingWizardStep> _completedSteps() {
    final completed = <FundraisingWizardStep>{};
    for (final step in _activeSteps) {
      if (step == FundraisingWizardStep.preview) continue;
      if (_validationMessagesForStep(step).isEmpty) {
        completed.add(step);
      }
    }
    return completed;
  }

  String _categoryLabel(AppLocalizations t, String value) {
    switch (value) {
      case 'TREATMENT':
        return t.fundraisingCategoryTreatment;
      case 'RESCUE':
        return t.fundraisingCategoryRescue;
      case 'SHELTER':
        return t.fundraisingCategoryShelter;
      case 'FOOD':
        return t.fundraisingCategoryFood;
      case 'EQUIPMENT':
        return t.fundraisingCategoryEquipment;
      default:
        return t.fundraisingCategoryOther;
    }
  }

  String _beneficiaryLabel(AppLocalizations t, String value) {
    switch (value) {
      case 'PET':
        return t.fundraisingBeneficiaryPet;
      case 'PERSON':
        return t.fundraisingBeneficiaryPerson;
      case 'SHELTER':
        return t.fundraisingBeneficiaryShelter;
      case 'ORGANIZATION':
        return t.fundraisingBeneficiaryOrganization;
      case 'COMMUNITY':
        return t.fundraisingBeneficiaryCommunity;
      default:
        return t.fundraisingBeneficiaryOther;
    }
  }

  String _urgencyLabel(AppLocalizations t, String value) {
    switch (value) {
      case 'LOW':
        return t.fundraisingUrgencyLow;
      case 'MEDIUM':
        return t.fundraisingUrgencyMedium;
      case 'HIGH':
        return t.fundraisingUrgencyHigh;
      default:
        return t.fundraisingUrgencyCritical;
    }
  }

  @override
  void dispose() {
    _wizardController.removeListener(_handleWizardChanged);
    _mediaController.removeListener(_handleMediaChanged);
    if (_ownsWizardController) {
      _wizardController.dispose();
    }
    if (_ownsMediaController) {
      _mediaController.dispose();
    }
    _titleCtrl.dispose();
    _shortDescriptionCtrl.dispose();
    _whatHappenedCtrl.dispose();
    _whyUrgentCtrl.dispose();
    _fundUsageCtrl.dispose();
    _storyCtrl.dispose();
    _goalCtrl.dispose();
    _monthlyGoalCtrl.dispose();
    _beneficiaryCtrl.dispose();
    _treatmentProviderCtrl.dispose();
    _estimatedTotalCtrl.dispose();
    _expenseNotesCtrl.dispose();
    _customLocationCtrl.dispose();
    for (final controller in _expenseControllers.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final currentStepIndex = _wizardController.draft.stepIndex.clamp(
      0,
      _activeSteps.length - 1,
    );
    final currentStep = _stepForIndex(currentStepIndex);
    final validationMessages = _showValidation
        ? _validationMessagesForStep(currentStep)
        : const <String>[];
    final isBusy =
        _initializing ||
        (_wizardController.initialized && _wizardController.isLoading);

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          centerTitle: false,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            t.fundraisingWizardTitle,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        body: isBusy
            ? Center(
                child: FundraisingLoadingView(
                  message: 'Preparing your fundraiser...',
                ),
              )
            : _preflightError != null
            ? FundraisingErrorView(
                title: _preflightErrorTitle(_preflightError),
                message: _preflightErrorDescription(_preflightError),
                onRetry: () async {
                  setState(() {
                    _preflightError = null;
                    _initializing = true;
                  });
                  await _initializeAsync();
                },
              )
            : Column(
                children: [
                  FundraisingWizardProgressHeader(
                    currentStep: currentStep,
                    completedSteps: _completedSteps(),
                    onStepTapped: _jumpToStep,
                  ),
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          14,
                          16,
                          152 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (validationMessages.isNotEmpty) ...[
                              FundraisingValidationBanner(
                                messages: validationMessages,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildStepBody(context, t, currentStep),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: (isBusy || _preflightError != null)
            ? null
            : FundraisingWizardBottomBar(
                canGoBack: _wizardController.draft.stepIndex > 0,
                onBack: _goBackStep,
                onCancel: _cancelWizard,
                onSaveDraft: _saveDraftManually,
                onContinue: _continueOrSubmit,
                continueLabel: currentStep == FundraisingWizardStep.preview
                    ? t.fundraisingSubmitForReview
                    : t.continueLabel,
                busy:
                    _wizardController.isSaving ||
                    _wizardController.isSubmitting,
                showSaveDraft: true,
                continueEnabled:
                    !_wizardController.isSaving &&
                    !_wizardController.isSubmitting &&
                    _canContinueFromCurrentStep(currentStep),
                helperText: _showValidation && validationMessages.isNotEmpty
                    ? validationMessages.first
                    : null,
              ),
      ),
    );
  }

  Widget _buildStepBody(
    BuildContext context,
    AppLocalizations t,
    FundraisingWizardStep step,
  ) {
    switch (step) {
      case FundraisingWizardStep.fundraiserType:
        return _buildBeneficiaryStep(context, t);
      case FundraisingWizardStep.storyAndGoal:
        return _buildStoryStep(context, t);
      case FundraisingWizardStep.caseDetails:
        return _buildCaseStep(context, t);
      case FundraisingWizardStep.location:
        return _buildLocationStep(context, t);
      case FundraisingWizardStep.evidence:
        return _buildEvidenceStep(context, t);
      case FundraisingWizardStep.payoutReadiness:
        return _buildPayoutStep(context, t);
      case FundraisingWizardStep.preview:
        return _buildPreviewStep(context, t);
    }
  }

  Widget _buildBeneficiaryStep(BuildContext context, AppLocalizations t) {
    final draft = _wizardController.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FundraisingSectionCard(
          title: 'Campaign identity',
          subtitle: 'Add the public information donors will see first.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FundraisingDropdownField<String>(
                value: draft.category.trim().isEmpty ? null : draft.category,
                labelText: t.fundraisingCategoryField,
                hintText: 'Select the closest campaign category',
                items: _categoryValues
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_categoryLabel(t, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(category: value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FundraisingTextField(
                controller: _titleCtrl,
                labelText: t.fundraisingTitleField,
                hintText: 'Example: Help Milo receive emergency treatment',
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(title: value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FundraisingTextField(
                controller: _shortDescriptionCtrl,
                labelText: 'Short description',
                hintText: 'Summarize the need in one or two clear sentences.',
                helperText:
                    'Keep it brief. This summary appears in campaign lists.',
                minLines: 2,
                maxLines: 3,
                maxLength: 200,
                textInputAction: TextInputAction.newline,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(shortDescription: value),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FundraisingSectionCard(
          title: 'Beneficiary',
          subtitle: 'Tell donors who will directly receive the support.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FundraisingDropdownField<String>(
                value: draft.beneficiaryType,
                labelText: t.fundraisingBeneficiaryTypeField,
                hintText: 'Choose a beneficiary type',
                items: _beneficiaryTypes
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_beneficiaryLabel(t, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(beneficiaryType: value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FundraisingTextField(
                controller: _beneficiaryCtrl,
                labelText: t.fundraisingBeneficiaryNameField,
                hintText: 'Pet, person, shelter, or organization name',
                minLines: 1,
                maxLines: 2,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(beneficiaryName: value),
                    ),
                  );
                },
              ),
              if (_pets.isNotEmpty) ...[
                const SizedBox(height: 12),
                FundraisingDropdownField<int>(
                  value: draft.petId,
                  labelText: t.fundraisingPetField,
                  helperText: 'Optional: connect an existing pet profile.',
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text(t.fundraisingNoPetSelected),
                    ),
                    ..._pets.map(
                      (pet) => DropdownMenuItem<int>(
                        value: pet.id,
                        child: Text(pet.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    unawaited(
                      _wizardController.updateDraft(
                        (current) => current.copyWith(
                          petId: value,
                          clearPetId: value == null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoryStep(BuildContext context, AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FundraisingSectionCard(
          title: 'Story essentials',
          subtitle: 'Answer the three questions donors usually consider first.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FundraisingTextField(
                controller: _whatHappenedCtrl,
                labelText: 'What happened?',
                hintText: 'Explain the situation clearly and factually.',
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(whatHappened: value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FundraisingTextField(
                controller: _whyUrgentCtrl,
                labelText: 'Why is help needed or urgent?',
                hintText:
                    'Mention timing, risk, or what may happen without support.',
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(whyUrgent: value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FundraisingTextField(
                controller: _fundUsageCtrl,
                labelText: 'How will the funds be used?',
                hintText:
                    'Describe the planned treatment, care, food, or equipment.',
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(fundUsage: value),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FundraisingSectionCard(
          title: 'Detailed narrative',
          subtitle:
              'Add supporting context without repeating the short summary.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FundraisingTextField(
                controller: _storyCtrl,
                labelText: 'Full campaign story',
                hintText:
                    'Write a complete, trustworthy account for potential donors.',
                helperText:
                    'Use short paragraphs so the story is easy to read on mobile.',
                minLines: 5,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(story: value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FundraisingTextField(
                controller: _treatmentProviderCtrl,
                labelText: 'Treatment provider or organization',
                hintText: 'Clinic, doctor, shelter, or organization name',
                helperText:
                    'Add this when a professional provider is involved.',
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(treatmentProvider: value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FundraisingDropdownField<String>(
                value: _wizardController.draft.urgency,
                labelText: t.fundraisingUrgencyField,
                hintText: 'Select the current urgency level',
                items: _urgencyValues
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_urgencyLabel(t, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(
                        urgency: value,
                        clearUrgency: value == null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaseStep(BuildContext context, AppLocalizations t) {
    final draft = _wizardController.draft;
    final mode = draft.fundingMode.trim().toUpperCase();
    final oneTime = mode.isEmpty || mode == 'ONE_TIME';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FundraisingSectionCard(
          title: 'Funding plan',
          subtitle:
              'Set a realistic goal, deadline, and transparent expense estimate.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Funding model',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'ONE_TIME',
                      label: Text('One-time'),
                    ),
                    ButtonSegment<String>(
                      value: 'ONGOING',
                      label: Text('Ongoing'),
                    ),
                  ],
                  selected: <String>{oneTime ? 'ONE_TIME' : 'ONGOING'},
                  onSelectionChanged: (selection) {
                    final value = selection.isEmpty
                        ? 'ONE_TIME'
                        : selection.first;
                    unawaited(_setFundingMode(value));
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (oneTime) ...[
                FundraisingAmountField(
                  controller: _goalCtrl,
                  labelText: t.fundraisingGoalField,
                  hintText: 'Enter the total amount needed',
                  helperText:
                      'Use the closest realistic amount supported by estimates.',
                  onChanged: (_) {
                    if (_syncingFields) return;
                    final parsed = _normalizeFormattedAmount(_goalCtrl);
                    unawaited(
                      _wizardController.updateDraft(
                        (current) => current.copyWith(
                          targetAmountMinor: parsed,
                          clearTargetAmountMinor: parsed == null,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _selectDeadline,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      draft.deadline == null
                          ? t.fundraisingSelectDeadline
                          : DateFormat.yMMMd().format(draft.deadline!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ] else ...[
                FundraisingAmountField(
                  controller: _monthlyGoalCtrl,
                  labelText: t.fundraisingMonthlyGoalField,
                  hintText: 'Enter the expected monthly need',
                  onChanged: (_) {
                    if (_syncingFields) return;
                    final parsed = _normalizeFormattedAmount(_monthlyGoalCtrl);
                    unawaited(
                      _wizardController.updateDraft(
                        (current) => current.copyWith(
                          monthlyGoalMinor: parsed,
                          clearMonthlyGoalMinor: parsed == null,
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 14),
              FundraisingAmountField(
                controller: _estimatedTotalCtrl,
                labelText: 'Estimated total expense',
                hintText: 'Enter the current estimated cost',
                onChanged: (_) {
                  if (_syncingFields) return;
                  final parsed = _normalizeFormattedAmount(_estimatedTotalCtrl);
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(
                        estimatedExpenseMinor: parsed,
                        clearEstimatedExpenseMinor: parsed == null,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              FundraisingTextField(
                controller: _expenseNotesCtrl,
                labelText: 'Expense notes',
                hintText:
                    'Explain estimates, quotations, or costs not listed below.',
                minLines: 3,
                maxLines: 5,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(expenseNotes: value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.fundraisingExpenseSummaryTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showExpenseBreakdown = !_showExpenseBreakdown;
                      });
                    },
                    child: Text(
                      _showExpenseBreakdown
                          ? 'Hide breakdown'
                          : 'Show breakdown',
                    ),
                  ),
                ],
              ),
              if (_showExpenseBreakdown) ...[
                const SizedBox(height: 10),
                ..._wizardController.draft.expenses.map((expense) {
                  final controller = _expenseControllers[expense.code]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FundraisingAmountField(
                      controller: controller,
                      labelText: expense.label,
                      onChanged: (_) {
                        if (_syncingFields) return;
                        final parsed = _normalizeFormattedAmount(controller);
                        _updateExpense(expense.code, parsed);
                      },
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 400;
            final amount = _moneyFormat.format(
              _wizardController.draft.suggestedTargetMinor,
            );
            return FundraisingSectionCard(
              title: t.fundraisingSuggestedGoalTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BDT $amount',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.fundraisingSuggestedGoalBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: narrow ? double.infinity : null,
                    child: FilledButton.tonal(
                      onPressed:
                          _wizardController.draft.suggestedTargetMinor > 0
                          ? _useSuggestedTarget
                          : null,
                      child: Text(
                        t.fundraisingUseSuggestedTarget,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocationStep(BuildContext context, AppLocalizations t) {
    final draft = _wizardController.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FundraisingSectionCard(
          title: 'Administrative location',
          subtitle:
              'Select the official Bangladesh location for this campaign.',
          child: LocationSelectorWidget(
            divisionId: draft.bdDivisionId,
            districtId: draft.bdDistrictId,
            upazilaId: draft.bdUpazilaId,
            unionId: draft.bdUnionId,
            divisionName: draft.divisionName,
            districtName: draft.districtName,
            upazilaName: draft.upazilaName,
            unionName: draft.unionName,
            required: true,
            onDivisionChanged: (id, name) {
              unawaited(
                _wizardController.updateDraft(
                  (current) => current.copyWith(
                    bdDivisionId: id,
                    clearBdDivisionId: id == null,
                    divisionName: name,
                    clearDivisionName: name == null,
                    bdDistrictId: null,
                    clearBdDistrictId: true,
                    bdUpazilaId: null,
                    clearBdUpazilaId: true,
                    bdUnionId: null,
                    clearBdUnionId: true,
                    bdAreaId: null,
                    clearBdAreaId: true,
                    districtName: null,
                    clearDistrictName: true,
                    upazilaName: null,
                    clearUpazilaName: true,
                    unionName: null,
                    clearUnionName: true,
                    areaName: null,
                    clearAreaName: true,
                    locationText: _buildLocationText(
                      areaName: null,
                      upazilaName: null,
                      districtName: null,
                      divisionName: name,
                      customNote: current.customLocationNote,
                    ),
                  ),
                ),
              );
            },
            onDistrictChanged: (id, name) {
              unawaited(
                _wizardController.updateDraft(
                  (current) => current.copyWith(
                    bdDistrictId: id,
                    clearBdDistrictId: id == null,
                    districtName: name,
                    clearDistrictName: name == null,
                    bdUpazilaId: null,
                    clearBdUpazilaId: true,
                    bdUnionId: null,
                    clearBdUnionId: true,
                    bdAreaId: null,
                    clearBdAreaId: true,
                    upazilaName: null,
                    clearUpazilaName: true,
                    unionName: null,
                    clearUnionName: true,
                    areaName: null,
                    clearAreaName: true,
                    locationText: _buildLocationText(
                      areaName: null,
                      upazilaName: null,
                      districtName: name,
                      divisionName: current.divisionName,
                      customNote: current.customLocationNote,
                    ),
                  ),
                ),
              );
            },
            onUpazilaChanged: (id, name) {
              unawaited(
                _wizardController.updateDraft(
                  (current) => current.copyWith(
                    bdUpazilaId: id,
                    clearBdUpazilaId: id == null,
                    upazilaName: name,
                    clearUpazilaName: name == null,
                    bdUnionId: null,
                    clearBdUnionId: true,
                    bdAreaId: null,
                    clearBdAreaId: true,
                    unionName: null,
                    clearUnionName: true,
                    areaName: null,
                    clearAreaName: true,
                    locationText: _buildLocationText(
                      areaName: null,
                      upazilaName: name,
                      districtName: current.districtName,
                      divisionName: current.divisionName,
                      customNote: current.customLocationNote,
                    ),
                  ),
                ),
              );
            },
            onUnionChanged: (id, name) {
              unawaited(
                _wizardController.updateDraft(
                  (current) => current.copyWith(
                    bdUnionId: id,
                    clearBdUnionId: id == null,
                    unionName: name,
                    clearUnionName: name == null,
                    locationText: _buildLocationText(
                      areaName: name,
                      upazilaName: current.upazilaName,
                      districtName: current.districtName,
                      divisionName: current.divisionName,
                      customNote: current.customLocationNote,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        FundraisingSectionCard(
          title: 'Additional location details',
          subtitle:
              'Add a useful landmark or capture the current device location.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location_outlined, size: 19),
                  label: Text(
                    t.fundraisingUseCurrentLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FundraisingTextField(
                controller: _customLocationCtrl,
                labelText: t.fundraisingLocationNoteField,
                hintText: 'Area, landmark, building, or access instructions',
                helperText:
                    'Avoid publishing sensitive private-address details.',
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                onChanged: (value) {
                  unawaited(
                    _wizardController.updateDraft(
                      (current) => current.copyWith(
                        customLocationNote: value,
                        locationText: _buildLocationText(
                          areaName: current.areaName,
                          upazilaName: current.upazilaName,
                          districtName: current.districtName,
                          divisionName: current.divisionName,
                          customNote: value,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FundraisingInfoCard(
                title: t.fundraisingLocationPreviewTitle,
                body: draft.locationText.trim().isEmpty
                    ? t.fundraisingLocationPlaceholder
                    : draft.locationText.trim(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceStep(BuildContext context, AppLocalizations t) {
    final evidenceCodes = _evidenceValidationCodes();
    final evidenceMessages = _evidenceStepGuidance(t);
    final uploadContinuing = evidenceCodes.contains('media_uploading');
    return FundraisingSectionCard(
      title: 'Campaign media',
      subtitle:
          'Use the shared editor to add clear photos, video, and supporting documents.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (evidenceMessages.isNotEmpty) ...[
            FundraisingInlineMessage(
              variant:
                  uploadContinuing ||
                      evidenceMessages.first == t.fundraisingValidationMedia
                  ? FundraisingInlineMessageVariant.info
                  : FundraisingInlineMessageVariant.warning,
              message: evidenceMessages.first,
              icon:
                  uploadContinuing ||
                      evidenceMessages.first == t.fundraisingValidationMedia
                  ? Icons.cloud_upload_outlined
                  : Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 360
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _WizardActionButton(
                    width: itemWidth,
                    icon: Icons.photo_library_outlined,
                    label: t.fundraisingAddPhotos,
                    onTap: _pickImages,
                  ),
                  _WizardActionButton(
                    width: itemWidth,
                    icon: Icons.videocam_outlined,
                    label: t.fundraisingAddVideo,
                    onTap: _pickVideo,
                  ),
                  _WizardActionButton(
                    width: itemWidth,
                    icon: Icons.description_outlined,
                    label: t.fundraisingAddDocuments,
                    onTap: _pickDocuments,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (_mediaController.items.isNotEmpty)
            MediaComposerList(
              controller: _mediaController,
              onEditItem: _editMediaItem,
            )
          else
            FundraisingInfoCard(
              title: t.fundraisingMediaEmptyTitle,
              body: t.fundraisingMediaEmptyBody,
            ),
        ],
      ),
    );
  }

  List<String> _evidenceStepGuidance(AppLocalizations t) {
    final codes = _evidenceValidationCodes();
    if (codes.isEmpty) return const <String>[];
    return codes
        .map((code) {
          switch (code) {
            case 'media_required':
              return t.fundraisingValidationMedia;
            case 'media_failed':
              return _mediaController.firstFailedItem?.errorMessage ??
                  t.fundraisingValidationMediaBlocking;
            case 'media_uploading':
              return 'Upload is continuing in the background. You can move to the next step and return here at any time.';
            case 'media_blocking':
            default:
              return t.fundraisingValidationMediaBlocking;
          }
        })
        .toList(growable: false);
  }

  Widget _buildPayoutStep(BuildContext context, AppLocalizations t) {
    final methods = _wizardController.payoutMethods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FundraisingSectionCard(
          title: t.fundraisingPayoutStatusTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FundraisingInlineMessage(
                variant: methods.isEmpty
                    ? FundraisingInlineMessageVariant.warning
                    : FundraisingInlineMessageVariant.success,
                message: methods.isEmpty
                    ? t.fundraisingPayoutStatusMissing
                    : t.fundraisingPayoutStatusReady,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _openPayoutMethods,
                  child: Text(
                    t.fundraisingManagePayout,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (methods.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...methods.map(
            (method) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FundraisingInfoCard(
                title: method.displayName,
                body: method.summary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewStep(BuildContext context, AppLocalizations t) {
    final mediaValidation = _mediaController.mediaValidation;
    // Failed media items get their own panel with real retry/remove actions,
    // so exclude the generic 'media_blocking' entry below when it's shown —
    // otherwise the same problem would be listed twice.
    final needsAttention = _previewNeedsAttention()
        .where(
          (entry) =>
              !(mediaValidation.hasFailedItems &&
                  entry.message == t.fundraisingValidationMediaBlocking),
        )
        .toList();
    final visibleMediaItems = _visiblePreviewMediaItems(_mediaController.items);
    final documentItems = _mediaController.items
        .where((item) => item.isDocument)
        .toList(growable: false);
    final previewFundingMode = _wizardController.draft.fundingMode
        .trim()
        .toUpperCase();
    final previewOngoing =
        previewFundingMode == 'ONGOING' || previewFundingMode == 'RECURRING';

    Widget reviewCard({
      required String title,
      required FundraisingWizardStep step,
      required List<Widget> children,
    }) {
      final complete = _validationMessagesForStep(step).isEmpty;
      return FundraisingSectionCard(
        title: title,
        subtitle: complete ? 'Complete' : 'Missing information',
        trailing: TextButton(
          onPressed: () => _jumpToStep(step),
          child: const Text('Edit'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FundraisingStatusChip(
              label: complete ? 'Complete' : 'Missing information',
              variant: complete
                  ? FundraisingChipVariant.success
                  : FundraisingChipVariant.warning,
              icon: complete ? Icons.check_circle_outline : Icons.error_outline,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
    }

    Widget summaryLine(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        reviewCard(
          title: 'Campaign Basics',
          step: FundraisingWizardStep.fundraiserType,
          children: [
            summaryLine(
              'Category',
              _categoryLabel(t, _wizardController.draft.category),
            ),
            summaryLine(
              'Beneficiary type',
              _beneficiaryLabel(t, _wizardController.draft.beneficiaryType),
            ),
            summaryLine(
              'Beneficiary name',
              _wizardController.draft.beneficiaryName.trim().isEmpty
                  ? 'Missing'
                  : _wizardController.draft.beneficiaryName.trim(),
            ),
            summaryLine(
              'Title',
              _wizardController.draft.title.trim().isEmpty
                  ? 'Missing'
                  : _wizardController.draft.title.trim(),
            ),
            summaryLine(
              'Short description',
              _wizardController.draft.shortDescription.trim().isEmpty
                  ? 'Missing'
                  : _wizardController.draft.shortDescription.trim(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        reviewCard(
          title: 'Campaign Story',
          step: FundraisingWizardStep.storyAndGoal,
          children: [
            summaryLine(
              'What happened',
              _wizardController.draft.whatHappened.trim().isEmpty
                  ? 'Missing'
                  : _wizardController.draft.whatHappened.trim(),
            ),
            summaryLine(
              'Why urgent',
              _wizardController.draft.whyUrgent.trim().isEmpty
                  ? 'Missing'
                  : _wizardController.draft.whyUrgent.trim(),
            ),
            summaryLine(
              'Funds used',
              _wizardController.draft.fundUsage.trim().isEmpty
                  ? 'Missing'
                  : _wizardController.draft.fundUsage.trim(),
            ),
            summaryLine(
              'Story',
              _wizardController.draft.story.trim().isEmpty
                  ? 'Missing'
                  : _wizardController.draft.story.trim(),
            ),
            summaryLine(
              'Treatment provider',
              _wizardController.draft.treatmentProvider.trim().isEmpty
                  ? 'Not specified'
                  : _wizardController.draft.treatmentProvider.trim(),
            ),
            summaryLine(
              'Urgency',
              _wizardController.draft.urgency == null
                  ? 'Missing'
                  : _urgencyLabel(t, _wizardController.draft.urgency!),
            ),
          ],
        ),
        const SizedBox(height: 16),
        reviewCard(
          title: 'Funding Details',
          step: FundraisingWizardStep.caseDetails,
          children: [
            summaryLine(
              'Funding mode',
              previewOngoing ? 'Ongoing' : 'One-time',
            ),
            summaryLine(
              previewOngoing ? 'Monthly goal' : 'Target amount',
              previewOngoing
                  ? (_wizardController.draft.monthlyGoalMinor == null
                        ? 'Missing'
                        : 'BDT ${_moneyFormat.format(_wizardController.draft.monthlyGoalMinor)}')
                  : (_wizardController.draft.targetAmountMinor == null
                        ? 'Missing'
                        : 'BDT ${_moneyFormat.format(_wizardController.draft.targetAmountMinor)}'),
            ),
            summaryLine(
              'Deadline',
              previewOngoing
                  ? 'Not required'
                  : _wizardController.draft.deadline == null
                  ? 'Missing'
                  : DateFormat.yMMMd().format(
                      _wizardController.draft.deadline!,
                    ),
            ),
            summaryLine(
              'Estimated expense',
              _wizardController.draft.estimatedExpenseMinor == null
                  ? 'Missing'
                  : 'BDT ${_moneyFormat.format(_wizardController.draft.estimatedExpenseMinor)}',
            ),
            summaryLine(
              'Expense notes',
              _wizardController.draft.expenseNotes.trim().isEmpty
                  ? 'Not specified'
                  : _wizardController.draft.expenseNotes.trim(),
            ),
            if (_wizardController.draft.expenses.any(
              (entry) => (entry.amountMinor ?? 0) > 0,
            )) ...[
              const SizedBox(height: 6),
              Text(
                'Expense breakdown',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ..._wizardController.draft.expenses
                  .where((entry) => (entry.amountMinor ?? 0) > 0)
                  .map(
                    (entry) => summaryLine(
                      entry.label,
                      'BDT ${_moneyFormat.format(entry.amountMinor)}',
                    ),
                  ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        reviewCard(
          title: 'Location',
          step: FundraisingWizardStep.location,
          children: [
            summaryLine(
              'Selected location',
              _wizardController.draft.locationText.trim().isEmpty
                  ? 'Missing'
                  : _wizardController.draft.locationText.trim(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        reviewCard(
          title: 'Media',
          step: FundraisingWizardStep.evidence,
          children: [
            summaryLine(
              'Ready media',
              visibleMediaItems.isEmpty
                  ? 'No ready media yet'
                  : '${visibleMediaItems.length} ready item(s)',
            ),
            const SizedBox(height: 12),
            if (visibleMediaItems.isEmpty)
              FundraisingInfoCard(
                title: t.fundraisingValidationMedia,
                body: t.fundraisingValidationMediaUploading,
              )
            else
              Text(
                visibleMediaItems.map((item) => item.fileName).join(', '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
        const SizedBox(height: 16),
        reviewCard(
          title: 'Documents',
          step: FundraisingWizardStep.evidence,
          children: [
            summaryLine(
              'Files',
              documentItems.isEmpty
                  ? 'No documents added'
                  : '${documentItems.length} document(s)',
            ),
            const SizedBox(height: 12),
            if (documentItems.isEmpty)
              FundraisingInfoCard(
                title: 'No documents yet',
                body:
                    'Supporting documents are optional, but you can add them here.',
              )
            else
              ...documentItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (needsAttention.isNotEmpty) ...[
          FundraisingSectionCard(
            title: t.fundraisingMediaNeedsAttention,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in needsAttention) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FundraisingInlineMessage(
                          variant: FundraisingInlineMessageVariant.warning,
                          icon: Icons.warning_amber_rounded,
                          message: entry.message,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _jumpToStep(entry.step),
                        child: Text(t.fundraisingNeedsAttentionFix),
                      ),
                    ],
                  ),
                  if (entry != needsAttention.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (mediaValidation.hasFailedItems) ...[
          FundraisingMediaNeedsAttentionPanel(
            items: _mediaController.items,
            title: t.fundraisingMediaNeedsAttention,
            retryLabel: t.fundraisingMediaRetry,
            removeLabel: t.fundraisingMediaRemove,
            blockingFallbackMessage: t.fundraisingValidationMediaBlocking,
            onRetry: (itemId) => unawaited(_mediaController.retryItem(itemId)),
            onRemove: (itemId) =>
                unawaited(_mediaController.removeItem(itemId)),
          ),
          const SizedBox(height: 16),
        ],
        FundraisingCampaignPreviewCard(
          draft: _wizardController.draft,
          mediaItems: _mediaController.items,
        ),
        const SizedBox(height: 16),
        FundraisingInfoCard(
          title: t.fundraisingPreviewSubmitTitle,
          body: t.fundraisingPreviewSubmitBody,
        ),
      ],
    );
  }

  List<MediaDraftItem> _visiblePreviewMediaItems(List<MediaDraftItem> items) {
    return items
        .where((item) {
          if (item.hasFailed || item.isCancelled) return false;
          if (item.isDocument) return true;

          final thumbPath = item.thumbnailPath?.trim();
          if (thumbPath != null &&
              thumbPath.isNotEmpty &&
              File(thumbPath).existsSync()) {
            return true;
          }

          final localPath = item.localPath?.trim();
          if (localPath != null &&
              localPath.isNotEmpty &&
              File(localPath).existsSync()) {
            return true;
          }

          if (item.isVideo) {
            return item.remoteMediaId != null ||
                (item.previewUrl?.trim().isNotEmpty ?? false) ||
                (item.remoteThumbnailUrl?.trim().isNotEmpty ?? false);
          }

          return (item.previewUrl?.trim().isNotEmpty ?? false);
        })
        .toList(growable: false);
  }

  String _buildLocationText({
    String? areaName,
    String? upazilaName,
    String? districtName,
    String? divisionName,
    String? customNote,
  }) {
    final parts = <String>[
      if ((areaName ?? '').trim().isNotEmpty) areaName!.trim(),
      if ((upazilaName ?? '').trim().isNotEmpty) upazilaName!.trim(),
      if ((districtName ?? '').trim().isNotEmpty) districtName!.trim(),
      if ((divisionName ?? '').trim().isNotEmpty) divisionName!.trim(),
      if ((customNote ?? '').trim().isNotEmpty) customNote!.trim(),
    ];
    final deduped = <String>[];
    final seen = <String>{};
    for (final part in parts) {
      final normalized = part.toLowerCase();
      if (seen.add(normalized)) {
        deduped.add(part);
      }
    }
    return deduped.join(', ');
  }
}

class _WizardActionButton extends StatelessWidget {
  const _WizardActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.width,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 48,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
