import 'package:flutter/material.dart';
import 'package:furtail_app/features/adoption/data/datasources/adoption_remote_ds.dart';
import 'package:furtail_app/features/adoption/data/repositories/adoption_repository.dart';
import 'package:furtail_app/features/adoption/presentation/screens/adoption_pet_detail_screen.dart';
import 'package:furtail_app/features/adoption/presentation/screens/application_detail_screen.dart';
import 'package:furtail_app/features/adoption/presentation/widgets/adoption_comments_sheet.dart';
import 'package:furtail_app/services/api_client.dart';

class AdoptionDetailEntryScreen extends StatefulWidget {
  final int adoptionId;

  const AdoptionDetailEntryScreen({super.key, required this.adoptionId});

  @override
  State<AdoptionDetailEntryScreen> createState() =>
      _AdoptionDetailEntryScreenState();
}

class _AdoptionDetailEntryScreenState extends State<AdoptionDetailEntryScreen> {
  late final AdoptionRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = AdoptionRepository(AdoptionRemoteDs(ApiClient()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _repository.fetchAdoptionDetail(widget.adoptionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Adoption Listing')),
            body: Center(child: Text(snapshot.error.toString())),
          );
        }
        return AdoptionPetDetailScreen(
          pet: snapshot.data!,
          repository: _repository,
        );
      },
    );
  }
}

class AdoptionCommentsEntryScreen extends StatefulWidget {
  final int adoptionId;

  const AdoptionCommentsEntryScreen({super.key, required this.adoptionId});

  @override
  State<AdoptionCommentsEntryScreen> createState() =>
      _AdoptionCommentsEntryScreenState();
}

class _AdoptionCommentsEntryScreenState
    extends State<AdoptionCommentsEntryScreen> {
  late final AdoptionRepository _repository;
  bool _openedSheet = false;

  @override
  void initState() {
    super.initState();
    _repository = AdoptionRepository(AdoptionRemoteDs(ApiClient()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _repository.fetchAdoptionDetail(widget.adoptionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Adoption Comments')),
            body: Center(child: Text(snapshot.error.toString())),
          );
        }

        final pet = snapshot.data!;
        if (!_openedSheet) {
          _openedSheet = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final navigator = Navigator.of(context);
            await showAdoptionCommentsSheet(
              context,
              pet: pet,
              repository: _repository,
            );
            if (!mounted) return;
            navigator.maybePop();
          });
        }

        return AdoptionPetDetailScreen(pet: pet, repository: _repository);
      },
    );
  }
}

class AdoptionApplicationEntryScreen extends StatelessWidget {
  final int applicationId;

  const AdoptionApplicationEntryScreen({
    super.key,
    required this.applicationId,
  });

  @override
  Widget build(BuildContext context) {
    final repository = AdoptionRepository(AdoptionRemoteDs(ApiClient()));
    return ApplicationDetailScreen(
      applicationId: applicationId,
      repository: repository,
    );
  }
}
