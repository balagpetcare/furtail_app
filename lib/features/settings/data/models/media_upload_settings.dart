enum UploadQuality { dataSaver, standard, high }

enum AutoPlaySetting { always, wifiOnly, never }

class MediaUploadSettings {
  final UploadQuality uploadQuality;
  final AutoPlaySetting autoPlayVideos;
  final bool saveUploadedMedia;
  final bool compressImages;
  final bool compressVideos;

  const MediaUploadSettings({
    this.uploadQuality = UploadQuality.standard,
    this.autoPlayVideos = AutoPlaySetting.wifiOnly,
    this.saveUploadedMedia = false,
    this.compressImages = true,
    this.compressVideos = true,
  });

  MediaUploadSettings copyWith({
    UploadQuality? uploadQuality,
    AutoPlaySetting? autoPlayVideos,
    bool? saveUploadedMedia,
    bool? compressImages,
    bool? compressVideos,
  }) {
    return MediaUploadSettings(
      uploadQuality: uploadQuality ?? this.uploadQuality,
      autoPlayVideos: autoPlayVideos ?? this.autoPlayVideos,
      saveUploadedMedia: saveUploadedMedia ?? this.saveUploadedMedia,
      compressImages: compressImages ?? this.compressImages,
      compressVideos: compressVideos ?? this.compressVideos,
    );
  }

  Map<String, dynamic> toJson() => {
        'uploadQuality': uploadQuality.name,
        'autoPlayVideos': autoPlayVideos.name,
        'saveUploadedMedia': saveUploadedMedia,
        'compressImages': compressImages,
        'compressVideos': compressVideos,
      };

  factory MediaUploadSettings.fromJson(Map<String, dynamic> json) {
    return MediaUploadSettings(
      uploadQuality: UploadQuality.values.firstWhere(
        (e) => e.name == json['uploadQuality'],
        orElse: () => UploadQuality.standard,
      ),
      autoPlayVideos: AutoPlaySetting.values.firstWhere(
        (e) => e.name == json['autoPlayVideos'],
        orElse: () => AutoPlaySetting.wifiOnly,
      ),
      saveUploadedMedia: json['saveUploadedMedia'] == true,
      compressImages: json['compressImages'] != false,
      compressVideos: json['compressVideos'] != false,
    );
  }
}
