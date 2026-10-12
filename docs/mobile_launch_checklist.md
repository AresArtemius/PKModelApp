# PK Management: чек-лист запуска iOS (Android — после релиза на iPhone)

Обновлено: 2026-10-12. Этап 6 плана, шаги 57–66. Android (шаг 63) не начинаем до публикации в App Store.

## Что уже сделано

- Sign in with Apple (ключ `75AW7X2H27`, Services ID `management.pk.app.signin`; секрет Supabase истекает ≈ 12.04.2027 — перевыпустить заранее).
- Единый дизайн v2 на телефоне (`uiV2`), `kIsWeb` только для браузерных вещей и оплаты.
- Лента, подписки, посты с камеры/галереи, комментарии, репосты, жалобы, страница поста `/post/:id`, страницы аккаунтов `/@tag` и `/u/:id`.
- iOS подпись: Apple Individual-аккаунт Игоря (Team `8587NSJ32Z`), bundle `com.artemkukhar.modelapp`, automatic signing. Приложение «PK Management» создано в App Store Connect.
- APNs key `7PP63T3352` загружен в Firebase `pkmanagementapp` (Development + Production); тестовый пуш приходит на iPhone.
- TestFlight: внутренняя группа «Я и Рома», сборки 1.1.0 (3–7) загружены.
- Магазинные ограничения: на телефоне нет цен, тарифов, ЮKassa и ссылок на оплату (billing_page, legal_documents `webOnly`).
- Universal links подготовлены (AASA / assetlinks, entitlements, Caddy) — активируются переменной `APPLE_TEAM_ID` в GitHub и передеплоем веба.
- Store-материалы: черновик `docs/store_listing.md`.

## Как собрать и залить сборку в TestFlight

Один раз: файл `~/Documents/pk-keys/supabase.env` с двумя строками `SUPABASE_URL=…` и `SUPABASE_ANON_KEY=…` (anon-ключ, не secret).

```bash
git pull
scripts/ios_release_build.sh --ipa
open build/ios/archive/Runner.xcarchive
```

Organizer → проверить номер сборки → Distribute App → App Store Connect → Upload. Номер сборки (`version:` в `pubspec.yaml`) поднимается в репозитории перед каждой загрузкой.

## Осталось до Submit (шаги 62–65)

- [x] Полный прогон TestFlight-сборки, правки четырьмя пачками, сборка 8 (1.1.0+8) с Sign in with Apple.
- [x] SQL выполнен: `feed_post_page.sql`, `account_profile_by_id.sql`, `feed_delete_post.sql`, `smoke_batch1.sql`, `casting_extra_info.sql`, `smoke_batch4.sql`.
- [x] `APPLE_TEAM_ID` задан, AASA отдаётся с `/p/*`, `/@*`, `/u/*`, `/post/*`.
- [ ] Проверить на сборке 8: репост, вход по телефону, вход через Apple, ссылка на анкету открывает приложение.
- [ ] Скриншоты 6.9″ (iPhone 17 Pro), 6 экранов по `docs/store_listing.md` § 6 (без «Тестовый кастинг» и тестовых анкет).
- [x] Review-аккаунт `art@test.ru`; пароль только в App Store Connect.
- [ ] Заполнить App Store Connect по `docs/store_listing.md` (описание, ключевые слова, рейтинг 17+, App Privacy, Review Notes).
- [ ] Submit for Review; релиз вручную после одобрения.

## Проверка пушей и ссылок (шаги 59–60, закрыть при прогоне)

- [ ] Лайк с веба под другим аккаунтом → пуш на iPhone → тап открывает ленту.
- [ ] Ссылка на анкету из мессенджера открывает приложение (после `APPLE_TEAM_ID` и деплоя).

## После релиза (не блокирует)

- 65а: автомодерация фото/видео (Yandex Vision), правила публикаций, подсветка в модерации.
- Перевыпустить секретный ключ Supabase (`sb_secret_…` попал в чат 12.10).
- Удалить `CNAME` в корне репозитория после отключения GitHub Pages.
- Android: Play Console, keystore, `google-services.json` для проекта `pkmanagementapp`, `ANDROID_SHA256`.
- In-App Purchase (Paid Apps Agreement, StoreKit) — если понадобится продавать внутри приложения.

## Команды проверки

```bash
flutter analyze
flutter test
scripts/ios_release_build.sh --ipa
```

Секреты service role, ЮKassa, Firebase Admin и Telegram никогда не передаются в клиентские `dart-define` и не включаются в IPA.
