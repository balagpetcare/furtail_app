# Furtail – Project Structure (Baseline V11.0.1.0)

এই refactor-এর লক্ষ্য হলো **ফাইল খুঁজে পাওয়া**, **কম্পোনেন্ট reuse**, এবং **নতুন feature add করা** সহজ করা — কিন্তু existing functionality না ভেঙে।

## Folder Map

### 1) App shell
- `lib/app/`
  - `app.dart` – root `MaterialApp` wrapper
  - `router/` – `AppRouter` + route names

### 2) Core (shared infrastructure)
- `lib/core/`
  - `config/` – environment, config
  - `constants/` – design system constants (colors, sizes, text styles)
  - `network/` – API config/endpoints/multipart helpers
  - `media/` – fullscreen gallery/video players
  - `services/` – share, upload manager
  - `storage/` – local storage
  - `utils/` – snackbars, date formatting, small helpers

### 3) Features (feature-based)
- `lib/features/<feature_name>/`
  - `data/` – datasources, models, repositories
  - `domain/` – entities, usecases (যেখানে আছে)
  - `presentation/` – screens, providers, widgets

**বর্তমান গুরুত্বপূর্ণ feature**
- `auth/`
- `home/`
- `posts/`
- `fundraising/`
- `pets/`
- `profile/`
- `common/` (bd location dropdown providers ইত্যাদি)

### 4) Legacy screens
- `lib/features/legacy/presentation/screens/`

`lib/screens/` থেকে সব legacy screens এখানে move করা হয়েছে, যাতে নতুন feature structure clean থাকে।

## Reuse Rules (Quick)

### UI reuse
- যেসব widget 2+ জায়গায় ব্যবহার হবে → আলাদা widget file বানান
- Widget naming: `<Feature><Component>Widget` অথবা context অনুযায়ী simple নাম
- Screen file এ **শুধু layout/assembly** রাখার চেষ্টা করুন, heavy widget আলাদা করুন

### State/logic reuse (Riverpod)
- provider ফাইল আলাদা (`presentation/providers/`)
- API/service calls repository এ (`data/repositories/`)

## Next step (recommended)
- বড় screen (700+ lines) গুলোকে `presentation/widgets/<screen_name>/` এ ভেঙে নেওয়া
  - উদাহরণ: `fundraising_details_screen.dart` → header/media/progress/comments widgets

