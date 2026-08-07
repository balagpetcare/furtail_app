import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/features/common/data/repositories/animal_taxonomy_repository.dart';
import 'package:furtail_app/services/api_client.dart';

import '../../domain/entities/pet_entity.dart';
import '../../data/datasources/pet_remote_ds.dart';
import '../../data/repositories/pet_repository_impl.dart';
import '../../domain/usecases/create_pet_usecase.dart';
import '../../domain/usecases/get_animal_types_usecase.dart';
import '../../domain/usecases/get_breeds_usecase.dart';
import '../../domain/usecases/get_pets_usecase.dart';
import '../../domain/usecases/update_pet_usecase.dart';
import '../../domain/usecases/upload_pet_photo_usecase.dart';
import '../../domain/usecases/update_pet_public_profile_usecase.dart';
import '../../domain/usecases/upload_pet_cover_photo_usecase.dart';

final _petRemoteDsProvider = Provider<PetRemoteDs>(
  (ref) => PetRemoteDs(client: ref.watch(apiClientProvider)),
);

final _animalTaxonomyRepositoryProvider = Provider<AnimalTaxonomyRepository>(
  (ref) => AnimalTaxonomyRepository(ref.watch(apiClientProvider)),
);

final _petRepositoryProvider = Provider<PetRepositoryImpl>(
  (ref) => PetRepositoryImpl(
    ref.watch(_petRemoteDsProvider),
    taxonomy: ref.watch(_animalTaxonomyRepositoryProvider),
  ),
);

final getAnimalTypesUsecaseProvider = Provider<GetAnimalTypesUsecase>(
  (ref) => GetAnimalTypesUsecase(ref.watch(_petRepositoryProvider)),
);

final getBreedsUsecaseProvider = Provider<GetBreedsUsecase>(
  (ref) => GetBreedsUsecase(ref.watch(_petRepositoryProvider)),
);

final getPetsUsecaseProvider = Provider<GetPetsUsecase>(
  (ref) => GetPetsUsecase(ref.watch(_petRepositoryProvider)),
);

final createPetUsecaseProvider = Provider<CreatePetUsecase>(
  (ref) => CreatePetUsecase(ref.watch(_petRepositoryProvider)),
);

final updatePetUsecaseProvider = Provider<UpdatePetUsecase>(
  (ref) => UpdatePetUsecase(ref.watch(_petRepositoryProvider)),
);

final uploadPetPhotoUsecaseProvider = Provider<UpdatePetPhotoUsecase>(
  (ref) => UpdatePetPhotoUsecase(ref.watch(_petRepositoryProvider)),
);

final uploadPetMediaIdProvider = Provider<Future<int> Function(File)>(
  (ref) => ref.watch(_petRepositoryProvider).uploadPetPhoto,
);

final removePetPhotoUsecaseProvider = Provider<RemovePetPhotoUsecase>(
  (ref) => RemovePetPhotoUsecase(ref.watch(_petRepositoryProvider)),
);

final updatePetPublicProfileUsecaseProvider =
    Provider<UpdatePetPublicProfileUsecase>(
      (ref) => UpdatePetPublicProfileUsecase(ref.watch(_petRepositoryProvider)),
    );

final uploadPetCoverPhotoUsecaseProvider = Provider<UploadPetCoverPhotoUsecase>(
  (ref) => UploadPetCoverPhotoUsecase(ref.watch(_petRepositoryProvider)),
);

class OwnerPetListState {
  final List<PetEntity> pets;
  final bool initialLoading;
  final bool refreshing;
  final String? error;
  final bool hasLoadedOnce;

  const OwnerPetListState({
    required this.pets,
    required this.initialLoading,
    required this.refreshing,
    required this.error,
    required this.hasLoadedOnce,
  });

  const OwnerPetListState.initial()
    : pets = const [],
      initialLoading = true,
      refreshing = false,
      error = null,
      hasLoadedOnce = false;

  OwnerPetListState copyWith({
    List<PetEntity>? pets,
    bool? initialLoading,
    bool? refreshing,
    String? error,
    bool clearError = false,
    bool? hasLoadedOnce,
  }) {
    return OwnerPetListState(
      pets: pets ?? this.pets,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : error ?? this.error,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

class OwnerPetListController extends Notifier<OwnerPetListState> {
  int _requestId = 0;
  final Map<int, PetEntity> _protectedPets = <int, PetEntity>{};

  @override
  OwnerPetListState build() {
    Future.microtask(load);
    return const OwnerPetListState.initial();
  }

  Future<void> load() async {
    final isInitial = !state.hasLoadedOnce;
    state = state.copyWith(
      initialLoading: isInitial,
      refreshing: !isInitial,
      clearError: true,
    );

    final requestId = ++_requestId;
    try {
      final fetched = await ref.read(_petRepositoryProvider).getAllPets();
      if (requestId != _requestId) return;
      state = state.copyWith(
        pets: _mergeProtectedPets(fetched),
        initialLoading: false,
        refreshing: false,
        clearError: true,
        hasLoadedOnce: true,
      );
    } catch (error) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        error: error.toString(),
        hasLoadedOnce: true,
      );
    }
  }

  Future<void> refresh() => load();

  void upsert(PetEntity pet) {
    final id = pet.id;
    if (id == null) return;
    _protectedPets[id] = pet;
    state = state.copyWith(
      pets: _dedupeById(<PetEntity>[pet, ...state.pets]),
      initialLoading: false,
      refreshing: false,
      clearError: true,
      hasLoadedOnce: true,
    );
  }

  void remove(int petId) {
    _protectedPets.remove(petId);
    state = state.copyWith(
      pets: state.pets.where((pet) => pet.id != petId).toList(growable: false),
    );
  }

  List<PetEntity> _mergeProtectedPets(List<PetEntity> fetched) {
    final fetchedIds = fetched.map((pet) => pet.id).whereType<int>().toSet();
    _protectedPets.removeWhere((id, _) => fetchedIds.contains(id));
    return _dedupeById(<PetEntity>[...fetched, ..._protectedPets.values]);
  }

  List<PetEntity> _dedupeById(List<PetEntity> pets) {
    final byId = <int, PetEntity>{};
    final withoutId = <PetEntity>[];
    for (final pet in pets) {
      final id = pet.id;
      if (id == null) {
        withoutId.add(pet);
      } else if (!byId.containsKey(id)) {
        byId[id] = pet;
      }
    }
    return <PetEntity>[...byId.values, ...withoutId];
  }
}

final ownerPetListProvider =
    NotifierProvider<OwnerPetListController, OwnerPetListState>(
      OwnerPetListController.new,
    );
