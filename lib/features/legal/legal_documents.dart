const kLegalVersion = '2026-07-15';

enum LegalDocumentKind { privacy, terms, cookies, processingNotice, requisites }

class LegalDocumentSection {
  const LegalDocumentSection({required this.title, required this.body});

  final String title;
  final String body;
}

class LegalDocument {
  const LegalDocument({
    required this.kind,
    required this.titleRu,
    required this.titleEn,
    required this.route,
    required this.sectionsRu,
    required this.sectionsEn,
  });

  final LegalDocumentKind kind;
  final String titleRu;
  final String titleEn;
  final String route;
  final List<LegalDocumentSection> sectionsRu;
  final List<LegalDocumentSection> sectionsEn;

  String title(bool isRu) => isRu ? titleRu : titleEn;
  List<LegalDocumentSection> sections(bool isRu) =>
      isRu ? sectionsRu : sectionsEn;
}

const legalDocuments = <LegalDocument>[
  LegalDocument(
    kind: LegalDocumentKind.privacy,
    titleRu: 'Политика конфиденциальности',
    titleEn: 'Privacy Policy',
    route: '/privacy',
    sectionsRu: [
      LegalDocumentSection(
        title: 'Что мы собираем',
        body:
            'PK Management хранит данные аккаунта, контактные данные, account tag, роли, анкеты моделей, актеров и других специалистов, кастинги, подборки, сообщения, медиафайлы, настройки уведомлений, данные устройств и технические события доставки уведомлений.',
      ),
      LegalDocumentSection(
        title: 'Зачем это нужно',
        body:
            'Данные используются для регистрации и входа, работы каталога, создания и модерации анкет, проведения кастингов и подборок, общения в чатах, отправки push/email-уведомлений, поддержки, безопасности, аудита важных действий и исполнения запросов пользователя.',
      ),
      LegalDocumentSection(
        title: 'Кому доступны данные',
        body:
            'Доступ зависит от роли пользователя, настроек видимости, участия в кастинге, подборке или диалоге. Администраторы и модераторы могут видеть данные, необходимые для модерации, поддержки, безопасности и обработки запросов. Клиенты и участники получают доступ только к тем данным, которые нужны для согласованных рабочих процессов.',
      ),
      LegalDocumentSection(
        title: 'Медиа и приватные материалы',
        body:
            'Фото, видео, голосовые сообщения, файлы и материалы анкет используются для просмотра, отбора, коммуникации и подготовки подборок. Приватные чатовые медиа хранятся с ограниченным доступом; публичные материалы анкет могут быть видны в каталоге или подборках согласно настройкам и логике приложения.',
      ),
      LegalDocumentSection(
        title: 'Несовершеннолетние участники',
        body:
            'Если данные относятся к несовершеннолетнему участнику, аккаунт и материалы должны создаваться, передаваться и поддерживаться родителем, законным представителем или с его явного согласия. Представитель отвечает за актуальность данных и наличие необходимых разрешений на участие в кастингах, съемках и публикацию материалов.',
      ),
      LegalDocumentSection(
        title: 'Хранение и удаление',
        body:
            'Пользователь может экспортировать доступные ему данные и запросить удаление аккаунта или отдельных данных. Часть записей может сохраняться ограниченное время, если это нужно для безопасности, журналов действий, расследования спорных ситуаций, подтверждения согласий или выполнения обязательных требований.',
      ),
      LegalDocumentSection(
        title: 'Запросы по данным',
        body:
            'Пользователь может обратиться через доступные каналы поддержки приложения, чтобы уточнить состав данных, обновить их, запросить экспорт, ограничение обработки или удаление. Перед выполнением чувствительного запроса может потребоваться подтверждение личности владельца аккаунта.',
      ),
    ],
    sectionsEn: [
      LegalDocumentSection(
        title: 'Data we collect',
        body:
            'PK Management stores account data, contact details, account tag, roles, profiles for models, actors and other specialists, castings, selections, messages, media files, notification settings, device data and technical notification delivery events.',
      ),
      LegalDocumentSection(
        title: 'Why we use it',
        body:
            'Data is used for registration and sign-in, catalogue operation, profile creation and moderation, castings and selections, chats, push/email notifications, support, security, audit of important actions and user-requested workflows.',
      ),
      LegalDocumentSection(
        title: 'Who can access it',
        body:
            'Access depends on user role, visibility settings and participation in a casting, selection or dialog. Administrators and moderators may access data needed for moderation, support, safety and request handling. Clients and participants receive only the data needed for agreed workflows.',
      ),
      LegalDocumentSection(
        title: 'Media and private materials',
        body:
            'Photos, videos, voice messages, files and profile materials are used for review, selection, communication and preparation of selections. Private chat media is stored with restricted access; public profile materials may be visible in the catalogue or selections according to app settings and product logic.',
      ),
      LegalDocumentSection(
        title: 'Minors',
        body:
            'If data relates to a minor, the account and materials must be created, provided and maintained by a parent/legal guardian or with their explicit consent. The representative is responsible for data accuracy and required permissions for castings, shoots and publication of materials.',
      ),
      LegalDocumentSection(
        title: 'Retention and deletion',
        body:
            'A user can export available data and request account or data deletion. Some records may be retained for a limited period when needed for safety, audit logs, dispute investigation, proof of consent or mandatory requirements.',
      ),
      LegalDocumentSection(
        title: 'Data requests',
        body:
            'A user can contact the app through available support channels to clarify stored data, update it, request export, restrict processing or request deletion. Sensitive requests may require identity confirmation by the account owner.',
      ),
    ],
  ),
  LegalDocument(
    kind: LegalDocumentKind.terms,
    titleRu: 'Условия использования',
    titleEn: 'Terms of Service',
    route: '/terms',
    sectionsRu: [
      LegalDocumentSection(
        title: 'Назначение сервиса',
        body:
            'PK Management помогает участникам, представителям, кастинг-директорам и заказчикам вести анкеты, кастинги, подборки и коммуникацию внутри приложения.',
      ),
      LegalDocumentSection(
        title: 'Ответственность пользователя',
        body:
            'Пользователь отвечает за точность данных, права на загружаемые материалы, наличие согласий от изображенных людей и корректность коммуникации. Запрещены чужие данные без разрешения, незаконный контент, спам, обман, обход ограничений платформы и действия, которые могут навредить другим пользователям.',
      ),
      LegalDocumentSection(
        title: 'Анкеты и роли',
        body:
            'Анкеты могут относиться к моделям, актерам, фотографам, видеографам, стилистам, визажистам и другим ролям. Пользователь подтверждает, что информация в анкете актуальна, а материалы можно использовать в рамках каталога, кастингов, подборок и коммуникации в приложении.',
      ),
      LegalDocumentSection(
        title: 'Требования к анкетам моделей',
        body:
            'Модерацию для размещения в каталоге проходят только анкеты профессиональных моделей. Анкета модели должна содержать достоверные и актуальные персональные данные и параметры, корректно указанную дату рождения, рост и другие запрашиваемые характеристики, а также качественное актуальное портфолио, позволяющее оценить внешность и профессиональный опыт. Тестовые, дублирующие, неполные, любительские анкеты, анкеты с недостоверными данными, чужими материалами или портфолио недостаточного качества могут быть отклонены. Для несовершеннолетней модели данные и материалы предоставляет родитель или законный представитель либо они размещаются с его явного согласия. Анкеты других профессиональных ролей оцениваются по полноте профильных данных, опыту и релевантным примерам работ.',
      ),
      LegalDocumentSection(
        title: 'Модерация и ограничения',
        body:
            'Прохождение модерации не гарантируется и определяется администрацией по совокупности данных и материалов анкеты. Администрация может запросить уточнения или дополнительные материалы, а также проверять, скрывать, отклонять, ограничивать или удалять материалы, анкеты, кастинги, подборки и аккаунты при несоответствии профессиональным требованиям, нарушениях правил, рисках безопасности, жалобах, спорных ситуациях или запросах правообладателей.',
      ),
      LegalDocumentSection(
        title: 'Кастинги и договоренности',
        body:
            'Приложение помогает организовать процесс, но конкретные условия съемок, оплат, документов, разрешений, поездок и публикаций должны подтверждаться сторонами отдельно. PK Management не заменяет договор между участником, представителем, заказчиком и другими сторонами.',
      ),
      LegalDocumentSection(
        title: 'Чаты и подборки',
        body:
            'Сообщения, голосовые, файлы и подборки должны использоваться только для рабочих целей, связанных с кастингами, коммуникацией и согласованным подбором. Нельзя распространять материалы из приложения вне разрешенного контекста без согласия правообладателя или участника.',
      ),
      LegalDocumentSection(
        title: 'Платное размещение в базе',
        body:
            'Платная услуга PK Management — размещение утвержденной анкеты в базе на выбранный срок: 1 месяц — 499 ₽ без скидки, 3 месяца — 1422 ₽ со скидкой 5%, 6 месяцев — 2784 ₽ со скидкой 7%, 12 месяцев — 5389 ₽ со скидкой 10%. Оплата относится к конкретной анкете, а не ко всему аккаунту. После успешной оплаты размещение активируется автоматически на оплаченный период.',
      ),
      LegalDocumentSection(
        title: 'Оплата и платежные данные',
        body:
            'Платежи обрабатываются через платежного провайдера ЮKassa. PK Management не получает и не хранит данные банковской карты. Возвраты, отмены и спорные ситуации обрабатываются через поддержку с учетом фактически оказанной услуги и применимых правил платежного провайдера.',
      ),
      LegalDocumentSection(
        title: 'Безопасность аккаунта',
        body:
            'Пользователь должен защищать доступ к аккаунту, не передавать пароль и коды восстановления третьим лицам и своевременно сообщать о подозрительной активности. Администраторы и важные пользователи могут использовать 2FA для дополнительной защиты.',
      ),
    ],
    sectionsEn: [
      LegalDocumentSection(
        title: 'Service purpose',
        body:
            'PK Management helps talent, representatives, casting directors and clients manage profiles, castings, selections and in-app communication.',
      ),
      LegalDocumentSection(
        title: 'User responsibility',
        body:
            'Users are responsible for accurate data, rights to uploaded materials, consent from depicted persons and respectful communication. Unauthorized personal data, illegal content, spam, deception, bypassing platform limits and actions that may harm other users are prohibited.',
      ),
      LegalDocumentSection(
        title: 'Profiles and roles',
        body:
            'Profiles may represent models, actors, photographers, videographers, stylists, makeup artists and other roles. The user confirms that profile information is accurate and materials may be used within the catalogue, castings, selections and in-app communication.',
      ),
      LegalDocumentSection(
        title: 'Requirements for model profiles',
        body:
            'Only professional model profiles are eligible to pass moderation for catalogue placement. A model profile must contain accurate and current personal information and measurements, a correctly stated date of birth, height and other requested characteristics, and a high-quality current portfolio sufficient to assess appearance and professional experience. Test, duplicate, incomplete or amateur profiles, profiles containing inaccurate data, third-party materials or an insufficient-quality portfolio may be rejected. For a minor model, data and materials must be provided by a parent or legal guardian or published with their explicit consent. Profiles for other professional roles are assessed based on complete role-specific information, experience and relevant work samples.',
      ),
      LegalDocumentSection(
        title: 'Moderation and restrictions',
        body:
            'Passing moderation is not guaranteed and is determined by the administration based on the profile data and materials as a whole. Administration may request clarifications or additional materials and may review, hide, reject, restrict or remove materials, profiles, castings, selections and accounts when professional requirements are not met, rules are violated, safety risks appear, complaints are received, disputes arise or rights-holder requests are made.',
      ),
      LegalDocumentSection(
        title: 'Castings and agreements',
        body:
            'The app helps organize workflows, but specific shoot terms, payments, documents, permissions, travel and publication rights must be confirmed separately by the parties. PK Management does not replace an agreement between talent, representatives, clients and other parties.',
      ),
      LegalDocumentSection(
        title: 'Chats and selections',
        body:
            'Messages, voice notes, files and selections must be used only for work purposes related to castings, communication and agreed selection workflows. Materials from the app must not be distributed outside the allowed context without consent from the rights holder or participant.',
      ),
      LegalDocumentSection(
        title: 'Paid profile placement',
        body:
            'PK Management paid service is placement of an approved profile in the database for the selected period: 1 month — 499 ₽ without a discount, 3 months — 1422 ₽ with a 5% discount, 6 months — 2784 ₽ with a 7% discount, 12 months — 5389 ₽ with a 10% discount. Payment applies to a specific profile, not to the whole account. After a successful payment, placement is activated automatically for the paid period.',
      ),
      LegalDocumentSection(
        title: 'Payments and card data',
        body:
            'Payments are processed by the YooKassa payment provider. PK Management does not receive or store bank card details. Refunds, cancellations and disputes are handled through support, taking into account the actually provided service and applicable payment provider rules.',
      ),
      LegalDocumentSection(
        title: 'Account security',
        body:
            'Users must protect account access, keep passwords and recovery codes private and report suspicious activity. Administrators and important users may use 2FA for additional protection.',
      ),
    ],
  ),
  LegalDocument(
    kind: LegalDocumentKind.cookies,
    titleRu: 'Cookie Policy',
    titleEn: 'Cookie Policy',
    route: '/cookies',
    sectionsRu: [
      LegalDocumentSection(
        title: 'Что используется',
        body:
            'Web-версия может использовать cookies, local storage, IndexedDB, service worker cache и похожие технологии для входа, восстановления сессии, очередей загрузки, push-уведомлений, сохранения настроек и стабильной работы приложения.',
      ),
      LegalDocumentSection(
        title: 'Служебные данные',
        body:
            'Служебные данные помогают держать пользователя авторизованным, запоминать настройки интерфейса, восстанавливать загрузки, показывать уведомления, защищать аккаунт и понимать технические ошибки.',
      ),
      LegalDocumentSection(
        title: 'Аналитика и маркетинг',
        body:
            'На текущем launch-first этапе приложение использует прежде всего функциональные технологии, необходимые для работы продукта. Если позже появятся отдельные маркетинговые или рекламные cookies, их нужно будет явно описать и, при необходимости, добавить отдельное согласие.',
      ),
      LegalDocumentSection(
        title: 'Ограничение',
        body:
            'Отключение cookies или локального хранилища в браузере может нарушить авторизацию, загрузку файлов, уведомления и другие функции приложения.',
      ),
    ],
    sectionsEn: [
      LegalDocumentSection(
        title: 'What is used',
        body:
            'The web app may use cookies, local storage, IndexedDB, service worker cache and similar technologies for sign-in, session recovery, upload queues, push notifications, saved settings and stable app operation.',
      ),
      LegalDocumentSection(
        title: 'Functional data',
        body:
            'Functional data keeps the user signed in, remembers interface settings, restores uploads, shows notifications, protects the account and helps diagnose technical errors.',
      ),
      LegalDocumentSection(
        title: 'Analytics and marketing',
        body:
            'At the current launch-first stage, the app primarily uses functional technologies required for the product to work. If separate marketing or advertising cookies are added later, they must be described explicitly and, where needed, covered by separate consent.',
      ),
      LegalDocumentSection(
        title: 'Limitation',
        body:
            'Disabling cookies or local browser storage may break sign-in, uploads, notifications and other app features.',
      ),
    ],
  ),
  LegalDocument(
    kind: LegalDocumentKind.processingNotice,
    titleRu: 'Согласие на обработку данных',
    titleEn: 'Data Processing Notice',
    route: '/processing-notice',
    sectionsRu: [
      LegalDocumentSection(
        title: 'Согласие',
        body:
            'Создавая аккаунт, пользователь подтверждает согласие на обработку данных, необходимых для регистрации, входа, анкеты, каталога, кастингов, подборок, сообщений, уведомлений, безопасности, поддержки, экспорта данных и обработки запроса на удаление.',
      ),
      LegalDocumentSection(
        title: 'Модели, актеры и авторы медиа',
        body:
            'Участник подтверждает, что имеет право передавать свои данные, фото, видео, голосовые сообщения и другие материалы, а также разрешает использовать их внутри приложения для каталога, кастингов, подборок, коммуникации и модерации.',
      ),
      LegalDocumentSection(
        title: 'Несовершеннолетние',
        body:
            'Если участник несовершеннолетний, согласие и данные должны предоставляться родителем или законным представителем либо с его явного разрешения. Представитель подтверждает право управлять аккаунтом и материалами участника.',
      ),
      LegalDocumentSection(
        title: 'Заказчики и представители',
        body:
            'Заказчик или представитель подтверждает, что использует данные участников только в рамках кастинга, подбора, коммуникации и согласованных рабочих процессов, не передает их третьим лицам вне разрешенного контекста и соблюдает права участников и авторов материалов.',
      ),
      LegalDocumentSection(
        title: 'Уведомления и безопасность',
        body:
            'Пользователь соглашается получать сервисные уведомления, связанные с сообщениями, кастингами, анкетами, безопасностью аккаунта и важными изменениями. Настройки push/email можно менять в центре уведомлений, кроме сообщений, необходимых для безопасности и работы аккаунта.',
      ),
      LegalDocumentSection(
        title: 'Отзыв согласия',
        body:
            'Пользователь может запросить удаление аккаунта или отдельных данных. Часть технических записей может сохраняться ограниченно для безопасности, подтверждения согласий, истории важных действий, исполнения обязательных требований или разбора спорных ситуаций.',
      ),
    ],
    sectionsEn: [
      LegalDocumentSection(
        title: 'Consent',
        body:
            'By creating an account, the user consents to processing data needed for registration, sign-in, profiles, catalogue, castings, selections, messages, notifications, security, support, data export and account deletion requests.',
      ),
      LegalDocumentSection(
        title: 'Talent and media authors',
        body:
            'Talent confirms they have the right to provide their data, photos, videos, voice messages and other materials and permits their use inside the app for the catalogue, castings, selections, communication and moderation.',
      ),
      LegalDocumentSection(
        title: 'Minors',
        body:
            'If a participant is a minor, consent and data must be provided by a parent/legal guardian or with their explicit permission. The representative confirms the right to manage the participant account and materials.',
      ),
      LegalDocumentSection(
        title: 'Clients and representatives',
        body:
            'Clients or representatives confirm that participant data is used only for casting, selection, communication and agreed workflows, is not shared with third parties outside the allowed context and respects the rights of participants and media authors.',
      ),
      LegalDocumentSection(
        title: 'Notifications and security',
        body:
            'The user agrees to receive service notifications related to messages, castings, profiles, account security and important changes. Push/email preferences can be changed in the notification center, except for messages required for account security and operation.',
      ),
      LegalDocumentSection(
        title: 'Withdrawal',
        body:
            'A user can request account or data deletion. Some technical records may be retained for a limited period for safety, proof of consent, history of important actions, mandatory requirements or dispute handling.',
      ),
    ],
  ),

  LegalDocument(
    kind: LegalDocumentKind.requisites,
    titleRu: 'Реквизиты и контакты',
    titleEn: 'Legal Details and Contacts',
    route: '/requisites',
    sectionsRu: [
      LegalDocumentSection(
        title: 'Исполнитель и оператор сервиса',
        body:
            'Полное наименование: Общество с ограниченной ответственностью «Модельное агентство “Биг Вест”». Сокращенное наименование: ООО «Модельное агентство “Биг Вест”».',
      ),
      LegalDocumentSection(
        title: 'Регистрационные данные',
        body:
            'ИНН: 7719223552. КПП: 771901001. ОГРН: 1027739885667. Директор: Кухарь Лариса Анатольевна.',
      ),
      LegalDocumentSection(
        title: 'Юридический адрес',
        body: '105215, Москва г, Парковая 9-я ул, дом № 66, корпус 2, к.112.',
      ),
      LegalDocumentSection(
        title: 'Банковские реквизиты',
        body:
            'Расчетный счет: 40702810200000080651. Банк: Филиал “Центральный” Банка ВТБ (ПАО) в г. Москве. Корреспондентский счет: 30101810145250000411 в Главном управлении Банка России по Центральному федеральному округу г. Москва. БИК: 044525411.',
      ),
      LegalDocumentSection(
        title: 'Платная услуга',
        body:
            'Размещение утвержденной анкеты в базе PK Management на выбранный период: 1 месяц — 499 ₽ без скидки, 3 месяца — 1422 ₽ со скидкой 5%, 6 месяцев — 2784 ₽ со скидкой 7%, 12 месяцев — 5389 ₽ со скидкой 10%. Услуга оплачивается отдельно для каждой анкеты.',
      ),
      LegalDocumentSection(
        title: 'Контакты',
        body:
            'Email: info@president-kids.ru, artem@president-kids.ru. Телефоны: +7 925 507-86-93, +7 925 542-09-23.',
      ),
    ],
    sectionsEn: [
      LegalDocumentSection(
        title: 'Service operator',
        body:
            'Full legal name: Limited Liability Company “Model Agency Big West”. Short legal name: LLC “Model Agency Big West”.',
      ),
      LegalDocumentSection(
        title: 'Registration details',
        body:
            'Tax ID: 7719223552. Tax registration code: 771901001. Primary state registration number: 1027739885667. Director: Larisa Anatolyevna Kukhar.',
      ),
      LegalDocumentSection(
        title: 'Legal address',
        body:
            '105215, Moscow, 9th Parkovaya Street, building 66, building 2, office 112, Russia.',
      ),
      LegalDocumentSection(
        title: 'Bank details',
        body:
            'Settlement account: 40702810200000080651. Bank: Central Branch of VTB Bank (PJSC) in Moscow. Correspondent account: 30101810145250000411 at the Main Department of the Bank of Russia for the Central Federal District, Moscow. BIC: 044525411.',
      ),
      LegalDocumentSection(
        title: 'Paid service',
        body:
            'Placement of an approved profile in the PK Management database for the selected period: 1 month — 499 ₽ without a discount, 3 months — 1422 ₽ with a 5% discount, 6 months — 2784 ₽ with a 7% discount, 12 months — 5389 ₽ with a 10% discount. The service is paid separately for each profile.',
      ),
      LegalDocumentSection(
        title: 'Contacts',
        body:
            'Email: info@president-kids.ru, artem@president-kids.ru. Phones: +7 925 507-86-93, +7 925 542-09-23.',
      ),
    ],
  ),
];

LegalDocument legalDocumentByKind(LegalDocumentKind kind) {
  return legalDocuments.firstWhere((document) => document.kind == kind);
}

Map<String, dynamic> legalConsentVersionsMetadata({
  required String source,
  required String userAgent,
}) {
  final acceptedAt = DateTime.now().toUtc().toIso8601String();
  return {
    'legal_consent_accepted': true,
    'legal_consent_source': source,
    'legal_consent_accepted_at': acceptedAt,
    'legal_consent_user_agent': userAgent,
    'privacy_policy_version': kLegalVersion,
    'terms_version': kLegalVersion,
    'cookie_policy_version': kLegalVersion,
    'processing_notice_version': kLegalVersion,
  };
}
