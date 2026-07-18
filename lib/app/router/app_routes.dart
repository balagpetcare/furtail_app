class AppRoutes {
  static const splash = '/';
  static const countryPicker = '/country-picker';
  static const login = '/login';

  static const home = '/home';
  static const shop = '/shop';
  static const services = '/services';
  static const profile = '/profile';
  static const visitorProfile = '/user/profile';
  static const visitorProfileByUsername = '/user/@'; // args: {username}
  static const savedPosts = '/saved-posts';

  static const createPost = '/create-post';
  static const postDetails = '/posts/details'; // args: {post}
  static const postEdit = '/posts/edit'; // args: {post}
  static const reelsPlayer = '/reels/player'; // args: {reels, initialIndex}
  static const postMediaDetail = '/posts/media-detail'; // args: {post, initialIndex} or details
  static const mediaViewer = '/posts/media-viewer'; // args: {post, initialIndex}

  static const petCreate = '/pets/create';
  static const petList = '/pets';
  static const petProfile = '/pets/profile'; // args: {petId}
  static const petPublicProfile = '/pets/public-profile'; // args: {petId}

  static const adoption = '/adoption';
  static const donation = '/donation';
  static const wallet = '/wallet';
  static const fundraisingCreate = '/fundraising/create';
  static const fundraisingDetails = '/fundraising/details'; // args: {campaignId}
  static const vet = '/vet';
  static const campaignHub = '/campaign';
  static const campaignDetail = '/campaign/detail'; // args: {slug}
  static const campaignCertificate = '/campaign/certificate'; // args: {token}

  static const lostPetAlert = '/lost-pet-alert';

  static const notificationsList = '/notifications';
  static const settings = '/settings';
  static const accountSettings = '/settings/account';
  static const editProfile = '/profile/edit';
  static const mediaStorageSettings = '/settings/media-storage';
}
