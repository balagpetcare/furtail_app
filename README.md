# BPA App

**Version:** `10.0.0+4`

## Post menu (3-dot) – Edit/Delete visibility
The **Edit** and **Delete** options inside the post **3-dot** menu are shown **only to the user who created the post**.

### Implementation notes
- Backend returns each post with `author.id`.
- On successful login (Email/Phone/Google/Facebook), the app stores these keys in `SharedPreferences`:
  - `token`
  - `userId`
  - `userName`
  - `userEmail`
- The UI checks ownership using: `post.author.id == userId`.

### Files touched
- `lib/core/storage/local_storage.dart`
- `lib/features/auth/data/repositories/auth_repository_impl.dart`
- `lib/features/auth/data/models/user_model.dart`

