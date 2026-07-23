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
import 'package:furtail_app/features/fundraising/data/repositories/fundraising_repository.dart';
import 'package:furtail_app/features/fundraising/data/services/fundraising_draft_recovery_service.dart';
import 'package:furtail_app/features/fundraising/presentation/controllers/fundraising_create_wizard_controller.dart';
import 'package:furtail_app/features/fundraising/presentation/providers/fundraising_providers.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_account_documents_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_account_setup_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_payout_methods_screen.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_campaign_preview_card.dart';
import 'package:furtail_app/features/fundraising/presentation/widgets/fundraising_create_wizard_widgets.dart';
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
import 'package:furtail_app/l10n/app_localizations.dart';

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
  late final TextEditingController _storyCtrl;
  late final TextEditingController _goalCtrl;
  late final TextEditingController _beneficiaryCtrl;
  late final TextEditingController _treatmentProviderCtrl;
  late final TextEditingController _customLocationCtrl;

  final Map<String, TextEditingController> _expenseControllers =
      <String, TextEditingController>{};

  final ScrollController _scrollController = ScrollController();

  bool _ownsWizardController = false;
  bool _ownsMediaController = false;
  bool _syncingFields = false;
  bool _initializing = true;
  bool _pickingMedia = false;
  bool _showValidation = false;

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
    _storyCtrl = TextEditingController();
    _goalCtrl = TextEditingController();
    _beneficiaryCtrl = TextEditingController();
    _treatmentProviderCtrl = TextEditingController();
    _customLocationCtrl = TextEditingController();

    _wizardController.addListener(_handleWizardChanged);
    _mediaController.addListener(_handleMediaChanged);
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await _mediaController.restore();
    await _wizardController.initialize();
    await _loadPets();
    _buildExpenseControllers();
    _applyDraftToTextFields();
    _syncUploadedMediaIds();
    if (!mounted) return;
    setState(() => _initializing = false);
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
    _syncUploadedMediaIds();
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
      ),
    );
  }

  void _applyDraftToTextFields() {
    _syncingFields = true;
    final draft = _wizardController.draft;
    _titleCtrl.text = draft.title;
    _storyCtrl.text = draft.story;
    _goalCtrl.text = _formatMinorAsDisplay(draft.targetAmountMinor);
    _beneficiaryCtrl.text = draft.beneficiaryName;
    _treatmentProviderCtrl.text = draft.treatmentProvider;
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
    return action == 'discard';
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
        _mediaPreparation.prepareDocuments(
          paths.map((path) => File(path)).toList(),
        ),
      );
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
          _mediaPreparation.prepareReplacementDocument(
            File(path),
            existingId: item.id,
            isCover: item.isCover,
          ),
        );
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
    } catch (error) {
      _showError(_localizedMediaError(error));
    }
  }

  Future<void> _openAccountSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FundraisingAccountSetupScreen()),
    );
    await _wizardController.refreshEligibility();
  }

  Future<void> _openDocuments() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FundraisingAccountDocumentsScreen(),
      ),
    );
    await _wizardController.refreshEligibility();
  }

  Future<void> _openPayoutMethods() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FundraisingPayoutMethodsScreen()),
    );
    await _wizardController.refreshEligibility();
  }

  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final initial =
        _wizardController.draft.deadline ?? now.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: initial,
    );
    if (picked == null) return;
    await _wizardController.updateDraft(
      (current) => current.copyWith(
        deadline: DateTime(picked.year, picked.month, picked.day, 23, 59),
      ),
    );
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
    await _wizardController.persistRecovery();
    await _wizardController.saveDraftNow();
    if (!mounted) return;
    final failure = _wizardController.lastFailure;
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
        FundraisingWizardStep.values[_wizardController.draft.stepIndex.clamp(
          0,
          FundraisingWizardStep.values.length - 1,
        )];
    final validation = _validationMessagesForStep(currentStep);
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
          final failure = _wizardController.lastFailure;
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
        (current) => current.copyWith(stepIndex: step.index),
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
        return t.fundraisingErrorSaveFailed;
      case FundraisingWizardErrorType.submitFailed:
        return t.fundraisingErrorSubmitFailed;
      case FundraisingWizardErrorType.validation:
        return t.fundraisingErrorValidation;
      case FundraisingWizardErrorType.unknown:
        return t.fundraisingErrorUnknown;
    }
  }

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
      hasBlockingMedia: _mediaController.hasBlockingItems,
    );
    return codes.map((code) {
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
        case 'story_too_short':
          return t.fundraisingValidationStory;
        case 'target_amount_required':
          return t.fundraisingValidationTargetAmount;
        case 'deadline_required':
          return t.fundraisingValidationDeadline;
        case 'estimated_expense_required':
          return t.fundraisingValidationEstimatedExpense;
        case 'urgency_required':
          return t.fundraisingValidationUrgency;
        case 'location_required':
          return t.fundraisingValidationLocation;
        case 'media_required':
          return t.fundraisingValidationMedia;
        case 'media_blocking':
          return t.fundraisingValidationMediaBlocking;
        case 'add_payout_method':
          return t.fundraisingValidationPayout;
        default:
          return t.fundraisingErrorValidation;
      }
    }).toList();
  }

  Set<FundraisingWizardStep> _completedSteps() {
    final completed = <FundraisingWizardStep>{};
    for (final step in FundraisingWizardStep.values) {
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
    _storyCtrl.dispose();
    _goalCtrl.dispose();
    _beneficiaryCtrl.dispose();
    _treatmentProviderCtrl.dispose();
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
      FundraisingWizardStep.values.length - 1,
    );
    final currentStep = FundraisingWizardStep.values[currentStepIndex];
    final validationMessages = _showValidation
        ? _validationMessagesForStep(currentStep)
        : const <String>[];

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(title: Text(t.fundraisingWizardTitle)),
        body: _initializing || _wizardController.isLoading
            ? const Center(child: CircularProgressIndicator())
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
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          140 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stepTitle(t, currentStep),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _stepDescription(t, currentStep),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (validationMessages.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              FundraisingValidationBanner(
                                messages: validationMessages,
                              ),
                            ],
                            const SizedBox(height: 18),
                            _buildStepBody(context, t, currentStep),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: FundraisingWizardBottomBar(
          canGoBack: _wizardController.draft.stepIndex > 0,
          onBack: _goBackStep,
          onSaveDraft: _saveDraftManually,
          onContinue: _continueOrSubmit,
          continueLabel: currentStep == FundraisingWizardStep.preview
              ? t.fundraisingSubmitForReview
              : t.continueLabel,
          busy: _wizardController.isSaving || _wizardController.isSubmitting,
        ),
      ),
    );
  }

  String _stepTitle(AppLocalizations t, FundraisingWizardStep step) {
    switch (step) {
      case FundraisingWizardStep.eligibility:
        return t.fundraisingWizardStepEligibility;
      case FundraisingWizardStep.fundraiserType:
        return t.fundraisingWizardStepBeneficiary;
      case FundraisingWizardStep.storyAndGoal:
        return t.fundraisingWizardStepStory;
      case FundraisingWizardStep.caseDetails:
        return t.fundraisingWizardStepCase;
      case FundraisingWizardStep.location:
        return t.fundraisingWizardStepLocation;
      case FundraisingWizardStep.evidence:
        return t.fundraisingWizardStepEvidence;
      case FundraisingWizardStep.payoutReadiness:
        return t.fundraisingWizardStepPayout;
      case FundraisingWizardStep.preview:
        return t.fundraisingWizardStepPreview;
    }
  }

  String _stepDescription(AppLocalizations t, FundraisingWizardStep step) {
    switch (step) {
      case FundraisingWizardStep.eligibility:
        return t.fundraisingWizardEligibilityDescription;
      case FundraisingWizardStep.fundraiserType:
        return t.fundraisingWizardBeneficiaryDescription;
      case FundraisingWizardStep.storyAndGoal:
        return t.fundraisingWizardStoryDescription;
      case FundraisingWizardStep.caseDetails:
        return t.fundraisingWizardCaseDescription;
      case FundraisingWizardStep.location:
        return t.fundraisingWizardLocationDescription;
      case FundraisingWizardStep.evidence:
        return t.fundraisingWizardEvidenceDescription;
      case FundraisingWizardStep.payoutReadiness:
        return t.fundraisingWizardPayoutDescription;
      case FundraisingWizardStep.preview:
        return t.fundraisingWizardPreviewDescription;
    }
  }

  Widget _buildStepBody(
    BuildContext context,
    AppLocalizations t,
    FundraisingWizardStep step,
  ) {
    switch (step) {
      case FundraisingWizardStep.eligibility:
        return _buildEligibilityStep(context, t);
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

  Widget _buildEligibilityStep(BuildContext context, AppLocalizations t) {
    final account = _wizardController.account;
    final status = account?.status.toUpperCase() ?? 'DRAFT';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FundraisingInfoCard(
          title: t.fundraisingEligibilityStatusTitle,
          body: _statusDescription(t, status),
          trailing: FilledButton(
            onPressed: _openAccountSetup,
            child: Text(t.fundraisingCompleteVerification),
          ),
        ),
        const SizedBox(height: 14),
        if (_wizardController.missingVerificationActions.contains(
          'complete_profile',
        ))
          FundraisingInfoCard(
            title: t.fundraisingEligibilityProfileTitle,
            body: t.fundraisingEligibilityProfileBody,
            trailing: TextButton(
              onPressed: _openAccountSetup,
              child: Text(t.fundraisingFixNow),
            ),
          ),
        if (_wizardController.missingVerificationActions.contains(
          'upload_documents',
        )) ...[
          const SizedBox(height: 14),
          FundraisingInfoCard(
            title: t.fundraisingEligibilityDocumentsTitle,
            body: t.fundraisingEligibilityDocumentsBody,
            trailing: TextButton(
              onPressed: _openDocuments,
              child: Text(t.fundraisingOpenDocuments),
            ),
          ),
        ],
        if (_wizardController.missingVerificationActions.contains(
          'resolve_rejection',
        )) ...[
          const SizedBox(height: 14),
          FundraisingInfoCard(
            title: t.fundraisingEligibilityRejectedTitle,
            body: t.fundraisingEligibilityRejectedBody,
            trailing: TextButton(
              onPressed: _openAccountSetup,
              child: Text(t.fundraisingReviewProfile),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          t.fundraisingEligibilityChecklistTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _ChecklistTile(
          label: t.fundraisingEligibilityChecklistProfile,
          done: !(_wizardController.missingVerificationActions.contains(
            'complete_profile',
          )),
        ),
        _ChecklistTile(
          label: t.fundraisingEligibilityChecklistDocuments,
          done: !(_wizardController.missingVerificationActions.contains(
            'upload_documents',
          )),
        ),
        _ChecklistTile(
          label: t.fundraisingEligibilityChecklistStatus,
          done: !_wizardController.isVerificationRejected,
        ),
      ],
    );
  }

  Widget _buildBeneficiaryStep(BuildContext context, AppLocalizations t) {
    final draft = _wizardController.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: draft.category.trim().isEmpty ? null : draft.category,
          decoration: InputDecoration(
            labelText: t.fundraisingCategoryField,
            border: const OutlineInputBorder(),
          ),
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
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: draft.beneficiaryType,
          decoration: InputDecoration(
            labelText: t.fundraisingBeneficiaryTypeField,
            border: const OutlineInputBorder(),
          ),
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _beneficiaryCtrl,
          minLines: 1,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: t.fundraisingBeneficiaryNameField,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            unawaited(
              _wizardController.updateDraft(
                (current) => current.copyWith(beneficiaryName: value),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStoryStep(BuildContext context, AppLocalizations t) {
    final draft = _wizardController.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            labelText: t.fundraisingTitleField,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            unawaited(
              _wizardController.updateDraft(
                (current) => current.copyWith(title: value),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _storyCtrl,
          minLines: 6,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: t.fundraisingStoryField,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            unawaited(
              _wizardController.updateDraft(
                (current) => current.copyWith(story: value),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _goalCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: t.fundraisingGoalField,
            prefixText: 'BDT ',
            border: const OutlineInputBorder(),
          ),
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
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _selectDeadline,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            draft.deadline == null
                ? t.fundraisingSelectDeadline
                : DateFormat.yMMMd().format(draft.deadline!),
          ),
        ),
      ],
    );
  }

  Widget _buildCaseStep(BuildContext context, AppLocalizations t) {
    final draft = _wizardController.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pets.isNotEmpty) ...[
          DropdownButtonFormField<int>(
            value: draft.petId,
            decoration: InputDecoration(
              labelText: t.fundraisingPetField,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem<int>(
                value: null,
                child: Text(t.fundraisingNoPetSelected),
              ),
              ..._pets.map(
                (pet) =>
                    DropdownMenuItem<int>(value: pet.id, child: Text(pet.name)),
              ),
            ],
            onChanged: (value) {
              unawaited(
                _wizardController.updateDraft(
                  (current) =>
                      current.copyWith(petId: value, clearPetId: value == null),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        DropdownButtonFormField<String>(
          value: draft.urgency,
          decoration: InputDecoration(
            labelText: t.fundraisingUrgencyField,
            border: const OutlineInputBorder(),
          ),
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _treatmentProviderCtrl,
          decoration: InputDecoration(
            labelText: t.fundraisingTreatmentProviderField,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            unawaited(
              _wizardController.updateDraft(
                (current) => current.copyWith(treatmentProvider: value),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          t.fundraisingExpenseSummaryTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ..._wizardController.draft.expenses.map((expense) {
          final controller = _expenseControllers[expense.code]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: expense.label,
                prefixText: 'BDT ',
                border: const OutlineInputBorder(),
              ),
            ),
          );
        }),
        FundraisingInfoCard(
          title: t.fundraisingSuggestedGoalTitle,
          body:
              '${t.fundraisingSuggestedGoalBody} BDT ${_moneyFormat.format(_wizardController.draft.suggestedTargetMinor)}',
          trailing: TextButton(
            onPressed: _wizardController.draft.suggestedTargetMinor > 0
                ? _useSuggestedTarget
                : null,
            child: Text(t.fundraisingUseSuggestedTarget),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep(BuildContext context, AppLocalizations t) {
    final draft = _wizardController.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocationSelectorWidget(
          divisionId: draft.bdDivisionId,
          districtId: draft.bdDistrictId,
          upazilaId: draft.bdUpazilaId,
          unionId: draft.bdAreaId,
          divisionName: draft.divisionName,
          districtName: draft.districtName,
          upazilaName: draft.upazilaName,
          unionName: draft.areaName,
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
                  bdAreaId: null,
                  clearBdAreaId: true,
                  districtName: null,
                  clearDistrictName: true,
                  upazilaName: null,
                  clearUpazilaName: true,
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
                  bdAreaId: null,
                  clearBdAreaId: true,
                  upazilaName: null,
                  clearUpazilaName: true,
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
                  bdAreaId: null,
                  clearBdAreaId: true,
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
                  bdAreaId: id,
                  clearBdAreaId: id == null,
                  areaName: name,
                  clearAreaName: name == null,
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _customLocationCtrl,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: t.fundraisingLocationNoteField,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
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
        const SizedBox(height: 16),
        FundraisingInfoCard(
          title: t.fundraisingLocationPreviewTitle,
          body: draft.locationText.trim().isEmpty
              ? t.fundraisingLocationPlaceholder
              : draft.locationText.trim(),
        ),
      ],
    );
  }

  Widget _buildEvidenceStep(BuildContext context, AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _WizardActionChip(
              icon: Icons.photo_library_outlined,
              label: t.fundraisingAddPhotos,
              onTap: _pickImages,
            ),
            _WizardActionChip(
              icon: Icons.videocam_outlined,
              label: t.fundraisingAddVideo,
              onTap: _pickVideo,
            ),
            _WizardActionChip(
              icon: Icons.description_outlined,
              label: t.fundraisingAddDocuments,
              onTap: _pickDocuments,
            ),
          ],
        ),
        const SizedBox(height: 16),
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
    );
  }

  Widget _buildPayoutStep(BuildContext context, AppLocalizations t) {
    final methods = _wizardController.payoutMethods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FundraisingInfoCard(
          title: t.fundraisingPayoutStatusTitle,
          body: methods.isEmpty
              ? t.fundraisingPayoutStatusMissing
              : t.fundraisingPayoutStatusReady,
          trailing: FilledButton(
            onPressed: _openPayoutMethods,
            child: Text(t.fundraisingManagePayout),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  String _statusDescription(AppLocalizations t, String status) {
    switch (status) {
      case 'VERIFIED':
        return t.fundraisingEligibilityVerified;
      case 'PENDING':
        return t.fundraisingEligibilityPending;
      case 'REJECTED':
        return t.fundraisingEligibilityRejected;
      default:
        return t.fundraisingEligibilityDraft;
    }
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

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _WizardActionChip extends StatelessWidget {
  const _WizardActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}
