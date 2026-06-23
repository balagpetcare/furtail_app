import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final _petRemoteDsProvider = Provider<PetRemoteDs>((ref) => PetRemoteDs());

final _petRepositoryProvider = Provider<PetRepositoryImpl>(
  (ref) => PetRepositoryImpl(ref.watch(_petRemoteDsProvider)),
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

final updatePetPublicProfileUsecaseProvider =
    Provider<UpdatePetPublicProfileUsecase>(
  (ref) => UpdatePetPublicProfileUsecase(ref.watch(_petRepositoryProvider)),
);

final uploadPetCoverPhotoUsecaseProvider =
    Provider<UploadPetCoverPhotoUsecase>(
  (ref) => UploadPetCoverPhotoUsecase(ref.watch(_petRepositoryProvider)),
);
