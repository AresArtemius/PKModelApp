# PK Management — материалы для App Store (шаг 64)

Обновлено: 2026-10-12 (после сборки 8). Переносим в App Store Connect на шаге 64.

## 1. Карточка приложения

| Поле | Значение | Лимит |
|---|---|---|
| Название | PK Management | 30 |
| Подзаголовок | Модели, актёры, кастинги | 30 |
| Категория | Основная: Бизнес (Business). Дополнительная: Социальные сети (Social Networking) | — |
| Возрастной рейтинг | 13+ (рассчитан новой анкетой, см. раздел 4) | — |
| Цена | Бесплатно | — |
| URL поддержки | https://app.pk.management/#/support | — |
| URL маркетинга | https://app.pk.management | — |
| Политика конфиденциальности | https://app.pk.management/#/privacy | — |
| Авторские права | © 2026 PK Management | — |

### Промо-текст (170 символов, можно менять без новой сборки)

Каталог моделей и актёров, кастинги с откликами, подборки для заказчиков и лента с новыми работами — всё в одном приложении.

### Ключевые слова (100 символов, через запятую, без пробелов)

модели,кастинг,актёры,кастинги,модельное агентство,детские модели,фотограф,съёмка,реклама,подборка

(ru-RU; для en-US: `models,casting,actors,model agency,kids models,photographer,photoshoot,talent,booking`)

## 2. Описание (ru-RU, до 4000 символов)

PK Management — рабочая платформа для модельной и рекламной индустрии: модели, актёры, фотографы, агентства и заказчики находят друг друга, проводят кастинги и собирают подборки в одном месте.

ДЛЯ МОДЕЛЕЙ И АКТЁРОВ
• Анкета с портфолио: фото, видео, параметры, опыт. Модерация проверяет каждую анкету перед публикацией.
• Детские анкеты ведёт родитель или законный представитель.
• Кастинги: смотрите актуальные проекты, откликайтесь в один тап, следите за статусом.
• Лента: публикуйте новые работы, подписывайтесь на коллег и заказчиков.
• Чаты с заказчиками, голосовые сообщения, уведомления о приглашениях.

ДЛЯ ЗАКАЗЧИКОВ, КАСТИНГ-ДИРЕКТОРОВ И АГЕНТСТВ
• Каталог с фильтрами по полу, возрасту, росту, параметрам, городу и опыту.
• Подборки: собирайте кандидатов, отправляйте клиенту ссылку или PDF, получайте обратную связь.
• Кастинги: создавайте проекты, принимайте отклики, приглашайте подходящих кандидатов напрямую.
• Композитки (compcard) в PDF одним нажатием.

БЕЗОПАСНОСТЬ
• Все анкеты проходят ручную модерацию.
• Жалобы на анкету, пост или сообщение — из любого экрана; блокировка пользователей.
• Для несовершеннолетних — отдельные правила и стандарты безопасности детей: https://app.pk.management/#/child-safety

Приложение бесплатное. Размещение анкеты в каталоге — платная услуга, оформляется на сайте app.pk.management; в приложении отображается только статус и срок размещения.

Поддержка: внутри приложения («Мой аккаунт» → «Помощь и поддержка») или artem@president-kids.ru.

## 3. Description (en-US)

PK Management is a working platform for the modelling and advertising industry: models, actors, photographers, agencies and clients find each other, run castings and build selections in one place.

FOR MODELS AND ACTORS
• A profile with a portfolio: photos, videos, measurements, experience. Every profile is reviewed by moderators before it is published.
• Profiles of minors are managed by a parent or legal guardian.
• Castings: browse current projects, apply in one tap, follow the status.
• Feed: post new work, follow colleagues and clients.
• Chats with clients, voice messages, invitation notifications.

FOR CLIENTS, CASTING DIRECTORS AND AGENCIES
• A catalogue with filters by gender, age, height, measurements, city and experience.
• Selections: shortlist candidates, share a link or a PDF with the client, collect feedback.
• Castings: create projects, receive applications, invite candidates directly.
• Comp cards as PDF in one tap.

SAFETY
• All profiles are moderated manually.
• Report a profile, a post or a message from any screen; block users.
• Separate rules and child-safety standards for minors: https://app.pk.management/#/child-safety

The app is free. Listing a profile in the catalogue is a paid service purchased on app.pk.management; the app only shows the listing status and expiry date.

Support: in the app (My account → Help & support) or artem@president-kids.ru.

## 4. Возрастной рейтинг (анкета App Store Connect)

| Вопрос | Ответ |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | Infrequent/Mild (модельные съёмки: бельё, купальники; порнография запрещена правилами и удаляется) |
| Profanity or Crude Humor | None |
| Alcohol, Tobacco, or Drug Use | None |
| Mature/Suggestive Themes | Infrequent/Mild |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Gambling / Contests | None |
| Unrestricted Web Access | No |
| User-Generated Content | **Yes** (лента, анкеты, чаты) |
| Made for Kids | **No** |

Итоговый рейтинг по новой анкете (13.10) — **13+**, переопределение не ставим (решение Артёма).

## 5. App Privacy (Data collection) — по фактическим SDK

SDK в сборке: Supabase (auth, база, storage), Firebase Cloud Messaging (push), Sentry (краши). Рекламных SDK и трекинга нет. Яндекс.Метрика — только в веб-версии, в iOS-сборке не используется.

| Категория | Данные | Привязка к пользователю | Используется для трекинга |
|---|---|---|---|
| Contact Info | Email, Phone Number, Name | Да | Нет |
| User Content | Photos or Videos, Audio Data (голосовые), Other User Content (анкеты, посты, сообщения) | Да | Нет |
| Identifiers | User ID, Device ID (push-токен) | Да | Нет |
| Usage Data | Product Interaction (уведомления, отклики) | Да | Нет |
| Diagnostics | Crash Data, Performance Data (Sentry) | Нет | Нет |
| Location | Coarse Location — **нет** (город вводится вручную, геолокация не запрашивается) | — | — |

Цели: App Functionality, Analytics (только диагностика). Ответ «Do you or your third-party partners use data for tracking?» — **No**.

## 6. Скриншоты

Нужны с реального iPhone в светлой теме, аккаунт без тестовых анкет и чужих персональных данных (использовать анкету «Кухарь Мия» и 2–3 реальные одобренные анкеты, на которые есть согласие).

Размеры: 6.9″/6.7″ (iPhone 16 Pro Max / 15 Pro Max) — обязательно; 6.5″ (11 Pro Max / XS Max) — если есть; iPad — не требуется: со сборки 9 приложение только для iPhone (TARGETED_DEVICE_FAMILY = 1).

Порядок (6 экранов):
1. Каталог с фильтрами (Каталог → открыть фильтры).
2. Анкета модели (обложка, галерея, параметры).
3. Кастинги — список.
4. Кастинг — страница с кнопкой «Откликнуться».
5. Лента с постом с фото.
6. Чат с заказчиком.

Снимать: iPhone → Громкость+ и боковая кнопка одновременно. Файлы собрать в папку `store/ios/6.7/` и прислать.

## 7. Что нового (для первой версии 1.1.0)

Первый релиз PK Management для iPhone: каталог моделей и актёров, кастинги с откликами, подборки для заказчиков, лента, чаты и уведомления.

## 8. Информация для App Review

**Review account:** `art@test.ru` (существующий тестовый аккаунт). Пароль — только в App Store Connect → App Information → App Review Information → Sign-in required; в документы и чат не копируем.

**Notes for the reviewer (en):**

PK Management is a B2B platform for the modelling industry (models, actors, casting directors, agencies).

How to test: sign in with the review account above. The catalogue, castings, feed and chats are available immediately. The review account has the "client" role, so you can also create a selection and a casting.

User-generated content: every model profile is reviewed by a human moderator before it becomes visible. Posts, comments and chat messages can be reported from the "…" menu; users can be blocked from the account page. Reported content is reviewed and removed within 24 hours; the moderation team is reachable at artem@president-kids.ru. Child-safety standards: https://app.pk.management/#/child-safety

Payments: listing a profile in the catalogue is a service purchased on our website; the iOS app does not sell anything and does not show prices or links to purchase — it only shows the current listing status.

Sign in with Apple is available on the login screen (iOS); email and phone sign-in are also available. The review account above uses email sign-in.

**Contact:** Artem Kukhar, artem@president-kids.ru, +7 925 507-86-93.

## 9. Чеклист перед Submit

- [ ] Сборка 9 (1.1.0+9, только iPhone) обработана и выбрана в версии 1.1.0.
- [ ] Скриншоты 6.7″ загружены (6 шт.).
- [ ] Название, подзаголовок, описание, ключевые слова, промо-текст заполнены (ru-RU основной, en-US добавить).
- [ ] Категория Business / Social Networking.
- [x] Возрастной рейтинг заполнен, 13+ без переопределения.
- [ ] App Privacy заполнен по таблице выше.
- [ ] Review account `art@test.ru`: пароль введён в App Review Information, Notes вставлены.
- [ ] Export Compliance: «не использует нестандартное шифрование» (HTTPS только) — ответ No.
- [ ] Content Rights: приложение содержит контент третьих лиц (фото пользователей) — «Yes, I have the rights» (согласие по Условиям).
- [ ] Release: Manually release this version (чтобы выпустить после ревью вручную).
