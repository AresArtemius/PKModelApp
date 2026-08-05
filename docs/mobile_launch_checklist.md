# PK Management: чек-лист запуска iOS и Android

Обновлено: 2026-08-01

## Текущий результат аудита

- `flutter analyze --no-pub`: ошибок нет.
- iOS plist и entitlements: синтаксически валидны.
- Мобильный responsive smoke на 390×844 и 360×800: стартовая страница, вход, регистрация, каталог и кастинги не имеют горизонтального переполнения или критически сломанной компоновки.
- Брендовые иконки PK Management уже установлены для iOS и Android.
- iOS использует bundle ID `com.artemkukhar.modelapp`, команду разработчика `89HUP535JN` и минимальную версию iOS 15.0.
- Android приведён к тому же application ID `com.artemkukhar.modelapp`.
- В Android release добавлены обязательные разрешения Internet, Camera, Record audio и Notifications.
- В iOS добавлены понятные описания доступа к камере, медиатеке и микрофону, Background Mode для remote notifications и декларация стандартного шифрования.
- Android release больше нельзя случайно собрать с debug-ключом: без локального `android/key.properties` release-сборка завершится понятной ошибкой.

## Блокеры до первой нативной сборки

### На компьютере разработчика

- [ ] Установить недостающие компоненты Xcode (`sudo xcodebuild -runFirstLaunch`), затем снова выполнить `flutter doctor -v`.
- [ ] Установить Android Studio, Android SDK, platform-tools, emulator и JDK 17.
- [ ] Создать минимум один Android-эмулятор актуальной версии и проверить его через `flutter devices`.
- [ ] Убедиться, что Android SDK записан в `android/local.properties` как `sdk.dir=...`.

### Android Firebase и push

- [ ] В Firebase Console зарегистрировать Android-приложение `com.artemkukhar.modelapp` в том же проекте, где настроен iOS.
- [ ] Скачать `google-services.json` и положить в `android/app/google-services.json`.
- [ ] Подключить Google Services Gradle plugin после добавления файла.
- [ ] Проверить получение FCM token, foreground/background push и переход по push в нужный экран.

### Подпись Android

- [x] Создать upload keystore и сохранить резервную копию вне репозитория.
- [x] Создать локальный `android/key.properties` со значениями `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
- [x] Не добавлять keystore и `key.properties` в Git.
- [x] Собрать `flutter build appbundle --release` и проверить подпись AAB.

### iOS signing и push

- [ ] Проверить App ID `com.artemkukhar.modelapp` в Apple Developer.
- [ ] Включить Push Notifications и Background Modes / Remote notifications для App ID и Runner target.
- [ ] Загрузить APNs key в Firebase Console.
- [ ] Собрать archive Release с distribution profile и загрузить в TestFlight.
- [ ] Проверить push на реальном iPhone: симулятор не заменяет этот тест полностью.

## Функциональный QA на обеих платформах

- [ ] Первый запуск, splash, русский/английский язык, системные размеры шрифта.
- [ ] Регистрация email и телефона, подтверждение, вход/выход, восстановление доступа.
- [ ] Google/Apple sign-in и возврат через `modelapp://login-callback`.
- [ ] Создание, редактирование и удаление анкеты; фото, камера, видео, голосовые сообщения и системные разрешения.
- [ ] Модерация: realtime-обновление статуса и уведомление пользователю.
- [ ] Каталог, обычный/расширенный поиск, карточка анкеты, фото-галерея и стрелки.
- [ ] Кастинги: создание, просмотр, отклик, статусы, референсы, удаление.
- [ ] Подборки и PDF: генерация, открытие модели, название файла и системный share/download.
- [ ] Чаты: текст, копирование, редактирование, удаление у обоих участников, фото/файл/голосовое, push и unread badge.
- [ ] Поддержка: приложение ↔ Telegram ↔ администратор, вложения, назначение оператора и непрочитанные.
- [x] Тарифы: в iOS/Android отображаются только текущий статус и срок размещения; цены, выбор периода, ЮKassa и внешняя оплата скрыты. Web checkout, webhook, продление и скрытие анкеты после окончания продолжают работать отдельно.
- [ ] Админка на телефоне: AdminGuard, модерация, предпросмотр анкеты, ручное размещение и восстановление отключённой анкеты.
- [ ] Работа при медленной сети, без сети, после сворачивания/возврата и после принудительного закрытия приложения.

## Визуальная матрица

- [ ] iPhone SE / компактный экран.
- [ ] iPhone 15/16/17 Pro и устройство с Dynamic Island.
- [ ] iPhone Pro Max.
- [ ] iPad portrait/landscape или официально отключить iPad, если планшетный интерфейс не готов.
- [ ] Android 360×800.
- [ ] Android 412×915.
- [ ] Android с увеличенным шрифтом 130–150%.
- [ ] Светлая и тёмная системная тема: приложение должно сохранять осознанный фирменный вид.
- [ ] Клавиатура открыта: кнопки отправки/сохранения и активное поле остаются видимыми.
- [ ] Камера, фото, системные диалоги разрешений и возврат из внешнего браузера.

## Store-ready материалы и решения

- [ ] Утвердить название, подзаголовок, описание, ключевые слова, категорию и возрастной рейтинг.
- [ ] Подготовить store-скриншоты без тестовых анкет и чужих персональных данных.
- [ ] Подготовить URL поддержки, Privacy Policy, Terms, удаление аккаунта и контакт для review.
- [ ] Заполнить Apple App Privacy и Google Play Data safety по фактическим данным/SDK.
- [ ] Добавить тестовый review-аккаунт и инструкцию, как проверить закрытые функции.
- [x] Для первого store-релиза утверждена безопасная мобильная платёжная схема: iOS/Android не показывают цены, выбор срока, ЮKassa, внешние ссылки и призывы оплатить вне приложения. Мобильный экран показывает только статус и дату окончания; checkout остаётся только в web. Вызов платёжной Edge Function дополнительно заблокирован на уровне мобильного клиента.
- [ ] Настроить universal/app links для `app.pk.management`, чтобы публичные ссылки и возврат оплаты открывали приложение, когда оно установлено.
- [ ] Провести закрытый TestFlight и Google Play Internal testing минимум на двух реальных устройствах каждой платформы.

## Команды финальной проверки

```bash
flutter doctor -v
flutter analyze
flutter test
flutter build ios --release --no-codesign \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Для Android release-сборки предпочтительно использовать
`scripts/android_release_build.sh`: скрипт завершится с ошибкой, если обязательные
клиентские параметры Supabase не переданы.

Секреты service role, ЮKassa, Firebase Admin и Telegram никогда не передаются в клиентские `dart-define` и не включаются в IPA/AAB.
