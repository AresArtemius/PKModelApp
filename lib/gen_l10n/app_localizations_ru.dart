// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'ModelApp';

  @override
  String get loginTitle => 'Вход';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get signIn => 'Войти';

  @override
  String get signUp => 'Создать аккаунт';

  @override
  String get signOut => 'Выйти';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get error => 'Ошибка';

  @override
  String get unknownError => 'Неизвестная ошибка';

  @override
  String get networkConnectionError =>
      'Нет соединения с Supabase. Проверьте интернет, VPN/прокси, DNS или SUPABASE_URL.';

  @override
  String get catalogUpper => 'КАТАЛОГ';

  @override
  String get signInUpper => 'ВОЙТИ';

  @override
  String get registerUpper => 'РЕГИСТРАЦИЯ';

  @override
  String get noAccount => 'Нет аккаунта? ';

  @override
  String get enterEmail => 'Введите email';

  @override
  String get invalidEmail => 'Некорректный email';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get passwordMin6 => 'Пароль минимум 6 символов';

  @override
  String get signInUserIdMissing => 'Ошибка входа: userId не получен';

  @override
  String get signInGenericError => 'Ошибка входа. Попробуйте ещё раз.';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get continueWith => 'или';

  @override
  String get continueWithPhone => 'ПРОДОЛЖИТЬ ПО ТЕЛЕФОНУ';

  @override
  String get continueWithGoogle => 'ПРОДОЛЖИТЬ ЧЕРЕЗ GOOGLE';

  @override
  String get continueWithApple => 'ПРОДОЛЖИТЬ ЧЕРЕЗ APPLE';

  @override
  String get oauthOpenFailed => 'Не удалось открыть вход. Попробуйте ещё раз.';

  @override
  String get oauthProviderDisabled =>
      'Этот способ входа пока не включён в Supabase.';

  @override
  String get phoneProviderDisabled =>
      'Вход по телефону пока не включён в Supabase.';

  @override
  String get phoneLoginTitle => 'Вход по телефону';

  @override
  String get phoneNumber => 'Телефон';

  @override
  String get phoneInternationalHint =>
      'Выберите код страны и введите номер телефона';

  @override
  String get phoneOtpCode => 'Код из SMS';

  @override
  String get phoneOtpSend => 'ОТПРАВИТЬ КОД';

  @override
  String get phoneOtpVerify => 'ВОЙТИ';

  @override
  String get phoneOtpEnterCode => 'Введите код из SMS';

  @override
  String get phoneOtpSendFailed =>
      'Не удалось отправить код. Попробуйте ещё раз.';

  @override
  String get phoneOtpVerifyFailed =>
      'Не удалось подтвердить код. Попробуйте ещё раз.';

  @override
  String get signInEmailNotConfirmed =>
      'Email ещё не подтверждён. Проверьте почту и перейдите по ссылке подтверждения.';

  @override
  String get emailRateLimitExceeded =>
      'Слишком много писем отправлено за короткое время. Подождите несколько минут и попробуйте снова.';

  @override
  String get continueSignUpWithPhone => 'ПРОДОЛЖИТЬ ПО ТЕЛЕФОНУ';

  @override
  String get continueSignUpWithGoogle => 'ПРОДОЛЖИТЬ ЧЕРЕЗ GOOGLE';

  @override
  String get continueSignUpWithApple => 'ПРОДОЛЖИТЬ ЧЕРЕЗ APPLE';

  @override
  String get emailVerificationTitle => 'Подтвердите email';

  @override
  String emailVerificationSubtitle(String email) {
    return 'Мы отправили письмо на $email. Перейдите по ссылке, чтобы активировать аккаунт.';
  }

  @override
  String get emailVerificationSubtitleNoEmail =>
      'Проверьте почту и перейдите по ссылке, чтобы активировать аккаунт.';

  @override
  String get emailVerificationExpires =>
      'Ссылка должна действовать 24 часа, если это включено в настройках Supabase Auth.';

  @override
  String get emailVerificationGoLoginUpper => 'Я ПОДТВЕРДИЛ, ВОЙТИ';

  @override
  String get emailVerificationResendUpper => 'ОТПРАВИТЬ ЕЩЁ РАЗ';

  @override
  String get emailVerificationResent => 'Письмо отправлено повторно.';

  @override
  String get emailVerificationChecking => 'Проверяем подтверждение email...';

  @override
  String get emailVerificationStillPending =>
      'Email ещё не подтверждён. Откройте письмо от Supabase и перейдите по ссылке, затем нажмите кнопку ещё раз.';

  @override
  String get emailVerificationLoginManually =>
      'Не удалось проверить автоматически: приложение было перезапущено или данные регистрации не сохранились. Войдите вручную после подтверждения email.';

  @override
  String get guestUpper => 'ГОСТЬ';

  @override
  String get accountUpper => 'АККАУНТ';

  @override
  String get catalogSearchHintUpper => 'ПОИСК ПО КАТАЛОГУ';

  @override
  String get catalogLoadError => 'Ошибка загрузки каталога';

  @override
  String get savedSearchFashion1825 => 'fashion 18-25';

  @override
  String get savedSearchKids => 'kids';

  @override
  String get savedSearchCommercial => 'commercial';

  @override
  String get savedSearchSports => 'sports';

  @override
  String get savedSearchSaveCurrent => 'СОХРАНИТЬ';

  @override
  String get savedSearchSaveTitle => 'СОХРАНИТЬ ПОИСК';

  @override
  String get savedSearchNameHint => 'Название поиска';

  @override
  String get savedSearchNameRequired => 'Введите название';

  @override
  String get savedSearchSaved => 'Поиск сохранен';

  @override
  String get savedSearchDeleted => 'Поиск удален';

  @override
  String get noApprovedProfilesYet => 'Пока нет одобренных анкет';

  @override
  String get city => 'Город';

  @override
  String get age => 'Возраст';

  @override
  String get height => 'Рост';

  @override
  String get cm => 'см';

  @override
  String get advancedSearchUpper => 'РАСШИРЕННЫЙ ПОИСК';

  @override
  String get resetUpper => 'СБРОСИТЬ';

  @override
  String get applyUpper => 'ПРИМЕНИТЬ';

  @override
  String get signOutConfirmTitleUpper => 'ВЫЙТИ ИЗ АККАУНТА?';

  @override
  String get signOutConfirmGuestStay => 'Вы останетесь в каталоге как гость.';

  @override
  String get deleteAccountUpper => 'УДАЛИТЬ АККАУНТ';

  @override
  String get deleteAccountSubtitle => 'Удалить профиль, анкеты и доступ';

  @override
  String get deleteAccountConfirmTitleUpper => 'УДАЛИТЬ АККАУНТ?';

  @override
  String get deleteAccountConfirmMessage =>
      'Аккаунт, анкеты, подборки, сообщения и связанные данные будут удалены без восстановления.';

  @override
  String get deleteAccountConfirmActionUpper => 'УДАЛИТЬ';

  @override
  String get deleteAccountSetupRequired =>
      'Удаление аккаунта включится после применения SQL delete_my_account.sql в Supabase.';

  @override
  String get deleteAccountFailed =>
      'Не удалось удалить аккаунт. Попробуйте ещё раз.';

  @override
  String rangeFromTo(int from, int to) {
    return 'от $from до $to';
  }

  @override
  String get shoeSize => 'Размер обуви';

  @override
  String get shoeSizeHint => 'например 39';

  @override
  String get bust => 'Грудь';

  @override
  String get bustHint => 'например 90';

  @override
  String get waist => 'Талия';

  @override
  String get waistHint => 'например 60';

  @override
  String get hips => 'Бёдра';

  @override
  String get hipsHint => 'например 90';

  @override
  String get eyeColor => 'Цвет глаз';

  @override
  String get eyeColorHint => 'например карие';

  @override
  String get hairColor => 'Цвет волос';

  @override
  String get hairColorHint => 'например русые';

  @override
  String get country => 'Страна';

  @override
  String get countryHint => 'например Австралия';

  @override
  String get cityHint => 'например Sydney';

  @override
  String get date => 'Дата';

  @override
  String get weekdayMonUpper => 'ПН';

  @override
  String get weekdayTueUpper => 'ВТ';

  @override
  String get weekdayWedUpper => 'СР';

  @override
  String get weekdayThuUpper => 'ЧТ';

  @override
  String get weekdayFriUpper => 'ПТ';

  @override
  String get weekdaySatUpper => 'СБ';

  @override
  String get weekdaySunUpper => 'ВС';

  @override
  String get monthJanuaryUpper => 'ЯНВАРЬ';

  @override
  String get monthFebruaryUpper => 'ФЕВРАЛЬ';

  @override
  String get monthMarchUpper => 'МАРТ';

  @override
  String get monthAprilUpper => 'АПРЕЛЬ';

  @override
  String get monthMayUpper => 'МАЙ';

  @override
  String get monthJuneUpper => 'ИЮНЬ';

  @override
  String get monthJulyUpper => 'ИЮЛЬ';

  @override
  String get monthAugustUpper => 'АВГУСТ';

  @override
  String get monthSeptemberUpper => 'СЕНТЯБРЬ';

  @override
  String get monthOctoberUpper => 'ОКТЯБРЬ';

  @override
  String get monthNovemberUpper => 'НОЯБРЬ';

  @override
  String get monthDecemberUpper => 'ДЕКАБРЬ';

  @override
  String get castingsUpper => 'КАСТИНГИ';

  @override
  String get castingsTab => 'Кастинги';

  @override
  String get catalogTab => 'Каталог';

  @override
  String get invitationsTab => 'Приглашения';

  @override
  String get myProfileTab => 'Мой аккаунт';

  @override
  String get adminTab => 'Админ';

  @override
  String get billingTitleUpper => 'ТАРИФЫ';

  @override
  String get billingAccountEntrySubtitle => 'Текущий план и лимиты';

  @override
  String get billingCurrentUpper => 'ТЕКУЩИЙ';

  @override
  String get billingPlanActive => 'АКТИВНЫЙ ПЛАН';

  @override
  String get billingPlanFreeStatus => 'ТЕКУЩИЙ ПЛАН';

  @override
  String get billingPlanFree => 'Базовый';

  @override
  String get billingPlanModelPro => 'Model Pro';

  @override
  String get billingPlanCastingAgentPro => 'Casting Agent Pro';

  @override
  String get billingPlanAgencyAdmin => 'Администратор';

  @override
  String get billingFreeSubtitle =>
      'Присутствие в каталоге без активного общения с заказчиками.';

  @override
  String get billingModelProSubtitle =>
      'Приглашения, чат и продвижение анкеты для активной работы.';

  @override
  String get billingCastingProSubtitle =>
      'Профессиональные инструменты для кастинг-агентов и клиентских подборок.';

  @override
  String get billingAgencySubtitle =>
      'Командный доступ, экспорты и аналитика для агентств.';

  @override
  String get billingBasicCatalog =>
      'Публикация в каталоге и инструменты анкеты';

  @override
  String billingProfileLimit(int limit) {
    return 'До $limit анкет';
  }

  @override
  String get billingUnlimitedProfiles => 'Безлимит анкет';

  @override
  String get billingInvitationsPreview =>
      'Видно, что вас пригласили или добавили в подборку';

  @override
  String get billingChatRequiresPro =>
      'Открыть чат и ответить можно в Model Pro';

  @override
  String get billingChatAndInvitations => 'Полный доступ к приглашениям и чату';

  @override
  String billingProfileBoostsIncluded(int count) {
    return '$count поднятия анкеты в месяц';
  }

  @override
  String get billingBasicAnalytics => 'Базовая статистика просмотров';

  @override
  String get billingBoostOneTime => 'Разовое поднятие анкеты';

  @override
  String get billingBoostOneTimeSubtitle =>
      'Можно купить отдельно без подписки Pro.';

  @override
  String get billingBoostOneTimeFeature =>
      'Поднять выбранную анкету выше в каталоге';

  @override
  String get billingUpgradeRequiredTitle => 'Нужен Model Pro';

  @override
  String get billingUpgradeRequiredMessage =>
      'Вы видите приглашение, но открыть чат и ответить можно после подключения Model Pro.';

  @override
  String get billingUpgradeActionUpper => 'К ТАРИФАМ';

  @override
  String billingSelectionSizeLimit(int limit) {
    return 'До $limit моделей в одной подборке';
  }

  @override
  String billingSelectionCountLimit(int limit) {
    return 'До $limit активных подборок';
  }

  @override
  String get billingUnlimitedSelectionSize => 'Безлимит моделей в подборках';

  @override
  String get billingUnlimitedSelections => 'Безлимит подборок';

  @override
  String get billingProfileBoost => 'Поднятие анкеты';

  @override
  String get billingExpandedMedia => 'Расширенная медиа-галерея';

  @override
  String get billingProBadge => 'Бейдж Pro';

  @override
  String get billingBrandedPdf => 'PDF-экспорт с брендингом';

  @override
  String get billingFoldersAndNotes => 'Папки и приватные заметки';

  @override
  String get billingTeamAccess => 'Командный доступ';

  @override
  String get billingAnalytics => 'Аналитика';

  @override
  String get billingExports => 'Расширенные экспорты';

  @override
  String get billingPaymentsSoon =>
      'Платежи еще не подключены. Этот экран показывает структуру тарифов; следующим шагом можно подключить Stripe или RevenueCat.';

  @override
  String get onboardingTitle => 'Как вы будете использовать ModelApp?';

  @override
  String get onboardingSubtitle =>
      'Выберите роль один раз, и приложение сразу откроет подходящий сценарий.';

  @override
  String get onboardingModelTitle => 'Я модель';

  @override
  String get onboardingModelSubtitle =>
      'Создавайте анкету, добавляйте медиа, отвечайте на кастинги и следите за приглашениями.';

  @override
  String get onboardingActorTitle => 'Я актер';

  @override
  String get onboardingActorSubtitle =>
      'Создавайте актерскую анкету, добавляйте медиа, откликайтесь на кастинги и проекты.';

  @override
  String get onboardingCastingTitle => 'Я кастинг-агент';

  @override
  String get onboardingCastingSubtitle =>
      'Ищите моделей, создавайте подборки, экспортируйте PDF и ведите проекты клиентов.';

  @override
  String get onboardingBrandTitle => 'Я бренд';

  @override
  String get onboardingBrandSubtitle =>
      'Ищите лица для кампаний, собирайте подборки и согласовывайте кандидатов с командой.';

  @override
  String get onboardingPhotographerTitle => 'Я фотограф';

  @override
  String get onboardingPhotographerSubtitle =>
      'Ищите моделей для съемок, тестов, кампаний и творческих проектов.';

  @override
  String get onboardingVideographerTitle => 'Я видеограф';

  @override
  String get onboardingVideographerSubtitle =>
      'Подбирайте моделей и актеров для видео, reels, рекламы и production-задач.';

  @override
  String get onboardingStylistTitle => 'Я стилист';

  @override
  String get onboardingStylistSubtitle =>
      'Собирайте команду для съемок, показов, лукбуков и коммерческих проектов.';

  @override
  String get onboardingMakeupArtistTitle => 'Я визажист';

  @override
  String get onboardingMakeupArtistSubtitle =>
      'Находите моделей для beauty-съемок, тестов, портфолио и клиентских проектов.';

  @override
  String get onboardingHairStylistTitle => 'Я стилист по волосам';

  @override
  String get onboardingHairStylistSubtitle =>
      'Ищите моделей для hair-съемок, окрашиваний, тестов и творческих проектов.';

  @override
  String get onboardingChooseUpper => 'ВЫБРАТЬ';

  @override
  String get onboardingSaveFailed =>
      'Не удалось сохранить роль. Попробуйте еще раз.';

  @override
  String get addProfileUpper => 'ДОБАВИТЬ АНКЕТУ';

  @override
  String get logoutUpper => 'ВЫЙТИ';

  @override
  String get registerFillBelow => 'Заполните данные ниже';

  @override
  String get accountTypeUpper => 'ТИП АККАУНТА';

  @override
  String get accountTypeUser => 'ОБЫЧНЫЙ';

  @override
  String get accountTypeCastingAgent => 'КАСТИНГ-АГЕНТ';

  @override
  String get passwordRepeat => 'Повтор пароля';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get passwordsDontMatch => 'Пароли не совпадают';

  @override
  String get signUpGenericError => 'Ошибка регистрации. Попробуйте ещё раз.';

  @override
  String get signUpDatabaseError =>
      'Ошибка Supabase при создании пользователя. Запустите SQL auth_signup_trigger_hard_reset.sql и попробуйте новый email.';

  @override
  String get notRegisteredTitle => 'ВЫ НЕ ЗАРЕГИСТРИРОВАНЫ';

  @override
  String get notRegisteredMessage =>
      'Чтобы открыть «Мою анкету», нужно войти или зарегистрироваться.';

  @override
  String get adminExitUpper => 'ВЫЙТИ';

  @override
  String get adminCreateCastingUpper => 'СОЗДАТЬ КАСТИНГ';

  @override
  String get adminModelsCatalogUpper => 'КАТАЛОГ МОДЕЛЕЙ';

  @override
  String get adminModerationUpper => 'МОДЕРАЦИЯ';

  @override
  String get adminAgentApplicationsUpper => 'ЗАЯВКИ АГЕНТОВ';

  @override
  String get adminAgentApplicationsEmpty => 'ЗАЯВОК НЕТ';

  @override
  String get agentApplicationApproveUpper => 'ОДОБРИТЬ';

  @override
  String get agentApplicationRejectUpper => 'ОТКЛОНИТЬ';

  @override
  String get adminOnlyUpper => 'ЭТА СТРАНИЦА ДОСТУПНА ТОЛЬКО АДМИНАМ';

  @override
  String get moderationRejectTitle => 'Причина отказа';

  @override
  String get moderationRejectHint => 'Комментарий для модели';

  @override
  String get moderationRejectRequired => 'Выберите или напишите причину';

  @override
  String get moderationRejectActionUpper => 'ОТКЛОНИТЬ';

  @override
  String get moderationRejectPoorPhotos => 'Некачественные фото';

  @override
  String get moderationRejectFaceNotVisible => 'Не видно лицо';

  @override
  String get moderationRejectIncompleteData => 'Неполные данные';

  @override
  String get moderationRejectInvalidMedia => 'Неподходящие медиа';

  @override
  String get moderationRejectSuspicious => 'Подозрительный профиль';

  @override
  String get castingTitle => 'Название кастинга';

  @override
  String get projectDescription => 'Описание проекта';

  @override
  String get rights => 'Права';

  @override
  String get fee => 'Гонорар';

  @override
  String get dates => 'Даты';

  @override
  String get backUpper => 'НАЗАД';

  @override
  String get profileCreateUpper => 'СОЗДАТЬ АНКЕТУ';

  @override
  String get profileTypeUpper => 'ТИП АНКЕТЫ';

  @override
  String get profileTypeModel => 'Модель';

  @override
  String get profileTypeActor => 'Актер';

  @override
  String get profileTypePhotographer => 'Фотограф';

  @override
  String get profileTypeVideographer => 'Видеограф';

  @override
  String get profileTypeStylist => 'Стилист';

  @override
  String get profileTypeMakeupArtist => 'Визажист';

  @override
  String get profileTypeHairStylist => 'Стилист по волосам';

  @override
  String get profileTypeSelectTitle => 'Кого добавить?';

  @override
  String get profileTypeSelectSubtitle =>
      'Выберите тип анкеты. В одном аккаунте можно вести несколько разных анкет.';

  @override
  String get profilePhysicalDetailsUpper => 'ФИЗИЧЕСКИЕ ДАННЫЕ';

  @override
  String get profileProfessionalInfoUpper => 'ПРОФЕССИОНАЛЬНАЯ ИНФОРМАЦИЯ';

  @override
  String get profileSurname => 'Фамилия';

  @override
  String get profileName => 'Имя';

  @override
  String get profileAge => 'Возраст';

  @override
  String get profileHeightCm => 'Рост (см)';

  @override
  String get profileBustCm => 'Грудь (см)';

  @override
  String get profileWaistCm => 'Талия (см)';

  @override
  String get profileHipsCm => 'Бёдра (см)';

  @override
  String get profileShoeSize => 'Размер обуви';

  @override
  String get profileEyeColor => 'Цвет глаз';

  @override
  String get profileHairColor => 'Цвет волос';

  @override
  String get profileCountry => 'Страна';

  @override
  String get profileCity => 'Город';

  @override
  String get profileAboutHint => 'Коротко о себе (опыт, навыки, ссылки)';

  @override
  String get profileMediaUpper => 'МЕДИА';

  @override
  String get profileResumeUpper => 'РЕЗЮМЕ';

  @override
  String get profileCalendarUpper => 'КАЛЕНДАРЬ';

  @override
  String get profileSubmitUpper => 'ОТПРАВИТЬ НА МОДЕРАЦИЮ';

  @override
  String get profileSaveUpper => 'СОХРАНИТЬ';

  @override
  String get profileDeleteUpper => 'УДАЛИТЬ АНКЕТУ';

  @override
  String get profileAddPhotoUpper => 'ДОБАВИТЬ ФОТО';

  @override
  String get profileAddVideoUpper => 'ДОБАВИТЬ ВИДЕО';

  @override
  String get profileMediaEmpty => 'Фото/видео пока не добавлены';

  @override
  String profileQualityComplete(int percent) {
    return 'Анкета заполнена на $percent%';
  }

  @override
  String get profileQualityReady =>
      'Хорошо: анкету можно отправлять на модерацию.';

  @override
  String get profileQualityRequiredFields =>
      'Заполните обязательные параметры и город';

  @override
  String get profileQualityPortraitPhoto => 'Добавьте четкое портретное фото';

  @override
  String get profileQualityFullBodyPhoto => 'Добавьте фото в полный рост';

  @override
  String get profileQualityProfessionalInfo =>
      'Добавьте опыт, услуги, жанры или навыки';

  @override
  String get profileQualityAbout =>
      'Добавьте короткое описание: опыт, навыки, ссылки';

  @override
  String get profileQualityVideo => 'Добавьте видео-визитку, если она есть';

  @override
  String get profileExperience => 'Опыт, клиенты, публикации';

  @override
  String get profileActingExperience => 'Актерский опыт, проекты, образование';

  @override
  String get profileSkills => 'Навыки и специализация';

  @override
  String get profileActorSkills => 'Навыки: языки, спорт, танцы, вокал';

  @override
  String get profileServices => 'Услуги';

  @override
  String get profileActorRoles => 'Типажи и роли';

  @override
  String get profileActingGenres => 'Жанры: кино, реклама, театр';

  @override
  String get profilePhotoGenres => 'Жанры съемок';

  @override
  String get profileVideoGenres => 'Жанры видео и production';

  @override
  String get profileWorkGenres => 'Направления работ';

  @override
  String get profileEquipment => 'Оборудование / студия / локации';

  @override
  String get profileVideo => 'Видео';

  @override
  String get profileVideoSelected => 'Видео выбрано';

  @override
  String get profileVideoUploaded => 'Видео загружено';

  @override
  String get profileStatusPendingUpper => 'НА МОДЕРАЦИИ';

  @override
  String get profileStatusPendingSubtitle =>
      'Анкета отправлена и ожидает проверки';

  @override
  String get profileStatusApprovedUpper => 'ОДОБРЕНО';

  @override
  String get profileStatusApprovedSubtitle => 'Анкета активна в каталоге';

  @override
  String get profileStatusRejectedUpper => 'ОТКЛОНЕНО';

  @override
  String get profileStatusRejectedSubtitleDefault =>
      'Исправь данные и отправь снова';

  @override
  String get profileStatusDraftUpper => 'ЧЕРНОВИК';

  @override
  String get profileStatusDraftSubtitle =>
      'Заполни анкету и отправь на модерацию';

  @override
  String get profileVerifiedUpper => 'ПРОФИЛЬ ПРОВЕРЕН';

  @override
  String get profileVerifiedSubtitle => 'Анкета подтверждена администратором';

  @override
  String get profileVerificationAvailableUpper => 'ВЕРИФИКАЦИЯ';

  @override
  String get profileVerificationAvailableSubtitle =>
      'Запросите проверку, чтобы получить отметку доверия';

  @override
  String get profileVerificationPendingUpper => 'ВЕРИФИКАЦИЯ НА ПРОВЕРКЕ';

  @override
  String get profileVerificationPendingSubtitle =>
      'Администратор проверит анкету и поставит отметку';

  @override
  String get profileVerificationRejectedUpper => 'ВЕРИФИКАЦИЯ ОТКЛОНЕНА';

  @override
  String get profileVerificationRejectedSubtitle =>
      'Проверьте данные и запросите проверку снова';

  @override
  String get profileVerificationRequestUpper => 'ЗАПРОСИТЬ';

  @override
  String get profileVerificationRequestFailed =>
      'Не удалось запросить верификацию. Попробуйте ещё раз.';

  @override
  String get profileErrorSurnameRequired => 'Заполни фамилию';

  @override
  String get profileErrorNameRequired => 'Заполни имя';

  @override
  String get profileErrorSaveFailed =>
      'Не удалось сохранить. Попробуйте ещё раз.';

  @override
  String get profileErrorDeleteFailed =>
      'Не удалось удалить. Попробуйте ещё раз.';

  @override
  String get profileErrorLimitReached =>
      'Лимит анкет по текущему тарифу исчерпан. Перейдите на Model Pro или удалите лишнюю анкету.';

  @override
  String get profileErrorNoUser => 'Нет пользователя';

  @override
  String get profileErrorFullNameRequired => 'Заполни ФИО перед отправкой';

  @override
  String get profileErrorAgeRequired => 'Добавьте дату рождения';

  @override
  String get profileErrorAgeRange => 'Проверьте дату рождения';

  @override
  String get profileErrorHeightRequired => 'Добавьте рост';

  @override
  String get profileErrorHeightRange => 'Рост должен быть 120–220 см';

  @override
  String get profileErrorBustRequired => 'Добавьте параметры груди';

  @override
  String get profileErrorBustRange => 'Грудь должна быть 40–140 см';

  @override
  String get profileErrorWaistRequired => 'Добавьте параметры талии';

  @override
  String get profileErrorWaistRange => 'Талия должна быть 40–140 см';

  @override
  String get profileErrorHipsRequired => 'Добавьте параметры бёдер';

  @override
  String get profileErrorHipsRange => 'Бёдра должны быть 40–140 см';

  @override
  String profileLoadError(Object error) {
    return 'Ошибка загрузки анкеты: $error';
  }

  @override
  String get profileMediaPreviewPlaceholder => 'Тут появятся превью фото/видео';

  @override
  String get bootstrapErrorMessage =>
      'Не удалось инициализировать приложение.\nПроверьте настройки Supabase и перезапустите.';

  @override
  String get retryButton => 'Перезапустить';

  @override
  String get bootstrapConfigErrorTitle => 'Ошибка конфигурации';

  @override
  String get bootstrapConfigErrorMessage =>
      'Supabase не настроен.\n\nЗапусти приложение с:\n--dart-define=SUPABASE_URL=...\n--dart-define=SUPABASE_ANON_KEY=...';

  @override
  String get bootstrapInitErrorTitle => 'Ошибка запуска';

  @override
  String get bootstrapInitErrorMessage =>
      'Не удалось инициализировать Supabase:';

  @override
  String get loadingDots => '...';

  @override
  String get respondUpper => 'ОТКЛИКНУТЬСЯ';

  @override
  String get respondAuthRequiredTitle => 'ТРЕБУЕТСЯ АВТОРИЗАЦИЯ';

  @override
  String get respondAuthRequiredMessage =>
      'Чтобы откликнуться на кастинг, войдите или зарегистрируйтесь.';

  @override
  String get respondSentMessage => 'ОТКЛИК ОТПРАВЛЕН';

  @override
  String get respondChooseProfilesTitle => 'ВЫБЕРИТЕ АНКЕТЫ';

  @override
  String get respondChooseProfilesMessage =>
      'У вас несколько анкет. Выберите одну или несколько, чтобы отправить отклик.';

  @override
  String get respondNoProfilesTitle => 'НЕТ АНКЕТ';

  @override
  String get respondNoProfilesMessage =>
      'Чтобы откликнуться, сначала создайте анкету в разделе профиля.';

  @override
  String get castingResponseStatusSubmitted => 'ОТПРАВЛЕНО';

  @override
  String get castingResponseStatusViewed => 'ПРОСМОТРЕНО';

  @override
  String get castingResponseStatusInvited => 'ПРИГЛАШЕНА';

  @override
  String get castingResponseStatusRejected => 'ОТКАЗ';

  @override
  String get goToProfileUpper => 'В ПРОФИЛЬ';

  @override
  String get profileUpper => 'АНКЕТА';

  @override
  String get selectionUpper => 'ВЫБОРКА';

  @override
  String get selectionStatusUpper => 'СТАТУС ПОДБОРКИ';

  @override
  String get selectionStatusDraft => 'Черновик';

  @override
  String get selectionStatusSent => 'Отправлено клиенту';

  @override
  String get selectionStatusViewed => 'Клиент смотрел';

  @override
  String get selectionStatusSelected => 'Выбраны';

  @override
  String get selectionStatusRejected => 'Отказ';

  @override
  String get responsesUpper => 'ОТКЛИКИ';

  @override
  String get noCastingsMessage => 'КАСТИНГОВ НЕТ';

  @override
  String get noResponsesMessage => 'ОТКЛИКОВ НЕТ';

  @override
  String get errorUpper => 'ОШИБКА';

  @override
  String get ageShort => 'возраст';

  @override
  String get heightShort => 'рост';

  @override
  String get profileMinHourlyRate => 'Мин. гонорар в час';

  @override
  String get profileMinDailyFee => 'Мин. гонорар в день';

  @override
  String get profileDetailsUpper => 'ДАННЫЕ';

  @override
  String get profileNoName => 'Без имени';

  @override
  String get profileResumeEmpty => 'Резюме будет добавлено позже.';

  @override
  String get profileNotFoundUpper => 'АНКЕТА НЕ НАЙДЕНА';

  @override
  String get retryUpper => 'ПОВТОРИТЬ';

  @override
  String get noCastingsYetUpper => 'КАСТИНГОВ ПОКА НЕТ';

  @override
  String get profileNotFoundSubtitle =>
      'Возможно, она ещё не одобрена или была удалена.';

  @override
  String get advancedMinHourlyRateUpper => 'МИН. ГОНОРАР В ЧАС';

  @override
  String get advancedMinDailyFeeUpper => 'МИН. ГОНОРАР В ДЕНЬ';

  @override
  String get selectedUpper => 'ВЫБРАНО';

  @override
  String get selectUpper => 'ВЫБРАТЬ';

  @override
  String get projectTitleUpper => 'НАЗВАНИЕ ПРОЕКТА';

  @override
  String get enterProjectTitleHint => 'Введите название';

  @override
  String get enterProjectTitleError => 'Введите название проекта';

  @override
  String get cancelUpper => 'ОТМЕНА';

  @override
  String get saveUpper => 'СОХРАНИТЬ';

  @override
  String get pdfOptionPhoto => 'Фото';

  @override
  String get pdfOptionFullName => 'ФИО';

  @override
  String get pdfOptionMeasurements => 'Параметры';

  @override
  String get pdfOptionModelLink => 'Ссылка на модель';

  @override
  String deleteSelectedItemsConfirm(int count) {
    return 'Удалить выбранные элементы ($count)?';
  }

  @override
  String get profileTitleUpper => 'АНКЕТА';

  @override
  String get profileDeleteMediaConfirmTitle => 'Удалить файл';

  @override
  String get profileDeleteMediaConfirmMessage =>
      'Вы действительно хотите удалить этот файл?';

  @override
  String get profileDeleteMediaDontAskAgain => 'Больше не спрашивать';

  @override
  String get yesUpper => 'ДА';

  @override
  String get noUpper => 'НЕТ';

  @override
  String get profileSubmitRequiredTitle => 'Нужна модерация';

  @override
  String get profileSubmitRequiredMessage =>
      'Вы добавили новые фото или видео. Чтобы применить эти изменения, анкету нужно отправить на модерацию.';

  @override
  String get okUpper => 'ОК';

  @override
  String get countryRussia => 'Россия';

  @override
  String get countryAustralia => 'Австралия';

  @override
  String get countryAustria => 'Австрия';

  @override
  String get countryBelarus => 'Беларусь';

  @override
  String get countryBelgium => 'Бельгия';

  @override
  String get countryBulgaria => 'Болгария';

  @override
  String get countryUnitedKingdom => 'Великобритания';

  @override
  String get countryGermany => 'Германия';

  @override
  String get countryGreece => 'Греция';

  @override
  String get countryGeorgia => 'Грузия';

  @override
  String get countrySpain => 'Испания';

  @override
  String get countryItaly => 'Италия';

  @override
  String get countryKazakhstan => 'Казахстан';

  @override
  String get countryCanada => 'Канада';

  @override
  String get countryCyprus => 'Кипр';

  @override
  String get countryNetherlands => 'Нидерланды';

  @override
  String get countryUae => 'ОАЭ';

  @override
  String get countryPoland => 'Польша';

  @override
  String get countryPortugal => 'Португалия';

  @override
  String get countryUsa => 'США';

  @override
  String get countryTurkey => 'Турция';

  @override
  String get countryUzbekistan => 'Узбекистан';

  @override
  String get countryFrance => 'Франция';

  @override
  String get countryCzechia => 'Чехия';

  @override
  String get countrySwitzerland => 'Швейцария';

  @override
  String get cityMoscow => 'Москва';

  @override
  String get citySaintPetersburg => 'Санкт-Петербург';

  @override
  String get cityKazan => 'Казань';

  @override
  String get cityYekaterinburg => 'Екатеринбург';

  @override
  String get cityNovosibirsk => 'Новосибирск';

  @override
  String get citySochi => 'Сочи';

  @override
  String get cityKrasnodar => 'Краснодар';

  @override
  String get cityRostovOnDon => 'Ростов-на-Дону';

  @override
  String get cityNizhnyNovgorod => 'Нижний Новгород';

  @override
  String get citySamara => 'Самара';

  @override
  String get cityUfa => 'Уфа';

  @override
  String get cityVladivostok => 'Владивосток';

  @override
  String get citySydney => 'Сидней';

  @override
  String get cityMelbourne => 'Мельбурн';

  @override
  String get cityBrisbane => 'Брисбен';

  @override
  String get cityPerth => 'Перт';

  @override
  String get cityAdelaide => 'Аделаида';

  @override
  String get cityGoldCoast => 'Голд-Кост';

  @override
  String get cityCanberra => 'Канберра';

  @override
  String get cityVienna => 'Вена';

  @override
  String get citySalzburg => 'Зальцбург';

  @override
  String get cityGraz => 'Грац';

  @override
  String get cityInnsbruck => 'Инсбрук';

  @override
  String get cityLinz => 'Линц';

  @override
  String get cityMinsk => 'Минск';

  @override
  String get cityBrest => 'Брест';

  @override
  String get cityGrodno => 'Гродно';

  @override
  String get cityVitebsk => 'Витебск';

  @override
  String get cityGomel => 'Гомель';

  @override
  String get cityBrussels => 'Брюссель';

  @override
  String get cityAntwerp => 'Антверпен';

  @override
  String get cityGhent => 'Гент';

  @override
  String get cityBruges => 'Брюгге';

  @override
  String get cityLiege => 'Льеж';

  @override
  String get citySofia => 'София';

  @override
  String get cityVarna => 'Варна';

  @override
  String get cityBurgas => 'Бургас';

  @override
  String get cityPlovdiv => 'Пловдив';

  @override
  String get cityLondon => 'Лондон';

  @override
  String get cityManchester => 'Манчестер';

  @override
  String get cityLiverpool => 'Ливерпуль';

  @override
  String get cityBirmingham => 'Бирмингем';

  @override
  String get cityEdinburgh => 'Эдинбург';

  @override
  String get cityGlasgow => 'Глазго';

  @override
  String get cityBerlin => 'Берлин';

  @override
  String get cityMunich => 'Мюнхен';

  @override
  String get cityHamburg => 'Гамбург';

  @override
  String get cityFrankfurt => 'Франкфурт';

  @override
  String get cityCologne => 'Кёльн';

  @override
  String get cityDusseldorf => 'Дюссельдорф';

  @override
  String get cityStuttgart => 'Штутгарт';

  @override
  String get cityAthens => 'Афины';

  @override
  String get cityThessaloniki => 'Салоники';

  @override
  String get cityHeraklion => 'Ираклион';

  @override
  String get cityPatras => 'Патры';

  @override
  String get cityTbilisi => 'Тбилиси';

  @override
  String get cityBatumi => 'Батуми';

  @override
  String get cityKutaisi => 'Кутаиси';

  @override
  String get cityMadrid => 'Мадрид';

  @override
  String get cityBarcelona => 'Барселона';

  @override
  String get cityValencia => 'Валенсия';

  @override
  String get citySeville => 'Севилья';

  @override
  String get cityMalaga => 'Малага';

  @override
  String get cityAlicante => 'Аликанте';

  @override
  String get cityIbiza => 'Ибица';

  @override
  String get cityRome => 'Рим';

  @override
  String get cityMilan => 'Милан';

  @override
  String get cityFlorence => 'Флоренция';

  @override
  String get cityVenice => 'Венеция';

  @override
  String get cityNaples => 'Неаполь';

  @override
  String get cityTurin => 'Турин';

  @override
  String get cityBologna => 'Болонья';

  @override
  String get cityAlmaty => 'Алматы';

  @override
  String get cityAstana => 'Астана';

  @override
  String get cityShymkent => 'Шымкент';

  @override
  String get cityKaraganda => 'Караганда';

  @override
  String get cityAtyrau => 'Атырау';

  @override
  String get cityToronto => 'Торонто';

  @override
  String get cityVancouver => 'Ванкувер';

  @override
  String get cityMontreal => 'Монреаль';

  @override
  String get cityCalgary => 'Калгари';

  @override
  String get cityOttawa => 'Оттава';

  @override
  String get cityNicosia => 'Никосия';

  @override
  String get cityLimassol => 'Лимасол';

  @override
  String get cityLarnaca => 'Ларнака';

  @override
  String get cityPaphos => 'Пафос';

  @override
  String get cityAmsterdam => 'Амстердам';

  @override
  String get cityRotterdam => 'Роттердам';

  @override
  String get cityTheHague => 'Гаага';

  @override
  String get cityUtrecht => 'Утрехт';

  @override
  String get cityEindhoven => 'Эйндховен';

  @override
  String get cityDubai => 'Дубай';

  @override
  String get cityAbuDhabi => 'Абу-Даби';

  @override
  String get citySharjah => 'Шарджа';

  @override
  String get cityAjman => 'Аджман';

  @override
  String get cityWarsaw => 'Варшава';

  @override
  String get cityKrakow => 'Краков';

  @override
  String get cityWroclaw => 'Вроцлав';

  @override
  String get cityGdansk => 'Гданьск';

  @override
  String get cityPoznan => 'Познань';

  @override
  String get cityLisbon => 'Лиссабон';

  @override
  String get cityPorto => 'Порту';

  @override
  String get cityFaro => 'Фару';

  @override
  String get cityBraga => 'Брага';

  @override
  String get cityNewYork => 'Нью-Йорк';

  @override
  String get cityLosAngeles => 'Лос-Анджелес';

  @override
  String get cityMiami => 'Майами';

  @override
  String get cityChicago => 'Чикаго';

  @override
  String get cityLasVegas => 'Лас-Вегас';

  @override
  String get citySanFrancisco => 'Сан-Франциско';

  @override
  String get cityBoston => 'Бостон';

  @override
  String get cityHouston => 'Хьюстон';

  @override
  String get cityIstanbul => 'Стамбул';

  @override
  String get cityAnkara => 'Анкара';

  @override
  String get cityIzmir => 'Измир';

  @override
  String get cityAntalya => 'Анталья';

  @override
  String get cityBodrum => 'Бодрум';

  @override
  String get cityTashkent => 'Ташкент';

  @override
  String get citySamarkand => 'Самарканд';

  @override
  String get cityBukhara => 'Бухара';

  @override
  String get cityParis => 'Париж';

  @override
  String get cityNice => 'Ницца';

  @override
  String get cityLyon => 'Лион';

  @override
  String get cityMarseille => 'Марсель';

  @override
  String get cityCannes => 'Канны';

  @override
  String get cityBordeaux => 'Бордо';

  @override
  String get cityPrague => 'Прага';

  @override
  String get cityBrno => 'Брно';

  @override
  String get cityOstrava => 'Острава';

  @override
  String get cityKarlovyVary => 'Карловы Вары';

  @override
  String get cityZurich => 'Цюрих';

  @override
  String get cityGeneva => 'Женева';

  @override
  String get cityBasel => 'Базель';

  @override
  String get cityLausanne => 'Лозанна';

  @override
  String get cityBern => 'Берн';

  @override
  String get deleteUpper => 'УДАЛИТЬ';

  @override
  String get invitationsUpper => 'ПРИГЛАШЕНИЯ';

  @override
  String get noInvitationsUpper => 'ПРИГЛАШЕНИЙ НЕТ';

  @override
  String get noInvitationsMessage =>
      'Когда вашу анкету добавят в подборку кастинга, сообщение появится здесь.';

  @override
  String get consideredForCastingMessage => 'ВАС РАССМАТРИВАЮТ НА КАСТИНГ';

  @override
  String get requestVideoIntro => 'Запросить видео-визитку';

  @override
  String get videoIntroRequirementsHint => 'Требования к видео-визитке';

  @override
  String get videoIntroRequiredMessage => 'ТРЕБУЕТСЯ ВИДЕО-ВИЗИТКА';

  @override
  String get openChatUpper => 'ОТКРЫТЬ ЧАТ';

  @override
  String get chatUpper => 'ЧАТ';

  @override
  String get chatEmptyMessage =>
      'Сообщений пока нет. Напишите первое сообщение.';

  @override
  String get messageHint => 'Сообщение';

  @override
  String get copyPublicLinkUpper => 'СКОПИРОВАТЬ ССЫЛКУ';

  @override
  String get publicLinkCopied => 'Ссылка скопирована';

  @override
  String get publicSelectionEnable => 'Опубликовать подборку';

  @override
  String get publicSelectionDisable => 'Скрыть подборку';

  @override
  String get publicSelectionLinkUpper => 'ПУБЛИЧНАЯ ССЫЛКА';

  @override
  String get publicSelectionCopyLink => 'Скопировать';

  @override
  String get publicSelectionLinkCopied => 'Ссылка на подборку скопирована';

  @override
  String get publicSelectionUnavailable =>
      'Подборка недоступна или больше не опубликована.';

  @override
  String get publicSelectionClientTitle => 'Оцените моделей в подборке';

  @override
  String get publicSelectionClientSubtitle =>
      'Поставьте лайк или отказ и оставьте комментарий по каждой модели.';

  @override
  String get clientFeedbackLike => 'Нравится';

  @override
  String get clientFeedbackReject => 'Отказ';

  @override
  String get clientFeedbackCommentHint => 'Комментарий для агента';

  @override
  String get clientFeedbackSaveComment => 'Сохранить';

  @override
  String get clientFeedbackSaved => 'Ответ сохранен';

  @override
  String get clientFeedbackEmpty => 'Клиентский фидбек пока пуст';

  @override
  String clientFeedbackLikesCount(int count) {
    return 'Нравится: $count';
  }

  @override
  String clientFeedbackRejectsCount(int count) {
    return 'Отказ: $count';
  }

  @override
  String get agentWorkspaceUpper => 'РАБОТА АГЕНТА';

  @override
  String get agentFoldersUpper => 'ПАПКИ';

  @override
  String get agentFolderCreateUpper => 'НОВАЯ';

  @override
  String get agentFolderCreateTitle => 'Новая папка';

  @override
  String get agentFolderName => 'Название папки';

  @override
  String get agentNoFolders => 'Папок пока нет';

  @override
  String get agentMyFoldersUpper => 'МОИ ПАПКИ';

  @override
  String get agentFolderEmpty => 'В этой папке пока нет моделей';

  @override
  String get agentFavoriteFolderTitle => 'Избранное';

  @override
  String get quickAddTitleUpper => 'БЫСТРО ДОБАВИТЬ';

  @override
  String get quickAddFavorite => 'Избранное';

  @override
  String get quickAddSelection => 'Подборка';

  @override
  String get quickAddFolder => 'Добавить в папку';

  @override
  String get quickAddCreateFolder => 'Новая папка';

  @override
  String get quickAddFavoriteDone => 'Модель добавлена в избранное';

  @override
  String quickAddFolderDone(String folder) {
    return 'Модель добавлена в папку «$folder»';
  }

  @override
  String quickAddSelectionDone(String selection) {
    return 'Подборка «$selection» создана';
  }

  @override
  String get agentPrivateNoteUpper => 'ПРИВАТНАЯ ЗАМЕТКА';

  @override
  String get agentPrivateNoteEmpty => 'Заметки пока нет';

  @override
  String get agentEditNoteUpper => 'ИЗМЕНИТЬ';

  @override
  String get agentNoteHint => 'Заметка видна только вам';

  @override
  String selectionProfileLimitMessage(int limit) {
    return 'На Free можно добавить до $limit моделей в одну подборку.';
  }

  @override
  String selectionCountLimitMessage(int limit) {
    return 'На Free можно создать до $limit подборок. Для большего нужен Pro.';
  }

  @override
  String get notificationsUpper => 'УВЕДОМЛЕНИЯ';

  @override
  String get notificationsAccountEntrySubtitle =>
      'События по подборкам, сообщениям и профилям';

  @override
  String get notificationsEmpty => 'Пока нет уведомлений';

  @override
  String get analyticsUpper => 'АНАЛИТИКА';

  @override
  String get analyticsAccountEntrySubtitle =>
      'Просмотры анкеты, подборки и приглашения';

  @override
  String get analyticsProfiles => 'Анкет';

  @override
  String get analyticsProfileViews => 'Просмотры профиля';

  @override
  String get analyticsSelectionAdds => 'Попадания в подборки';

  @override
  String get analyticsInvitations => 'Приглашения';

  @override
  String get analyticsHint =>
      'Данные появятся после применения SQL и новых действий в приложении.';

  @override
  String get safetyAdminUpper => 'БЕЗОПАСНОСТЬ';

  @override
  String get safetyReportsEmpty => 'Жалоб пока нет';

  @override
  String get reportProfileUpper => 'ПОЖАЛОВАТЬСЯ';

  @override
  String get blockUserUpper => 'ЗАБЛОКИРОВАТЬ';

  @override
  String get reportReasonSpam => 'Спам или мошенничество';

  @override
  String get reportReasonFake => 'Фейковый профиль';

  @override
  String get reportReasonInappropriate => 'Неподходящий контент';

  @override
  String get reportReasonOther => 'Другое';

  @override
  String get profileReportSent => 'Жалоба отправлена';

  @override
  String get profileReportSetupRequired =>
      'Жалобы включатся после применения SQL.';

  @override
  String get profileBlocked => 'Пользователь заблокирован';

  @override
  String get profileBlockSetupRequired =>
      'Блокировки включатся после применения SQL.';

  @override
  String get projectClientHint => 'Клиент';

  @override
  String get projectBrandHint => 'Бренд';

  @override
  String get projectBudgetHint => 'Бюджет';

  @override
  String get projectLocationHint => 'Локация';

  @override
  String get projectDatesHint => 'Даты проекта';

  @override
  String get projectRolesHint => 'Роли и задачи: модель, актер, стилист...';

  @override
  String get projectCampaignUpper => 'КАМПАНИЯ';

  @override
  String get projectClient => 'Клиент';

  @override
  String get projectBrand => 'Бренд';

  @override
  String get projectBudget => 'Бюджет';

  @override
  String get projectLocation => 'Локация';

  @override
  String get projectDates => 'Даты';

  @override
  String get projectRoles => 'Роли';
}
