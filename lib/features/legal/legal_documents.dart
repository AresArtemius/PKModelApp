const kLegalVersion = '2026-07-10';

enum LegalDocumentKind { privacy, terms, cookies, processingNotice }

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
            'PK Management хранит данные аккаунта, анкет, кастингов, подборок, сообщений, медиафайлов и технические события доставки уведомлений. Для несовершеннолетних участников данные должны предоставляться законным представителем или с его согласия.',
      ),
      LegalDocumentSection(
        title: 'Зачем это нужно',
        body:
            'Данные используются для работы каталога, кастингов, коммуникации между участниками и заказчиками, модерации, безопасности, поддержки и исполнения пользовательских запросов.',
      ),
      LegalDocumentSection(
        title: 'Кому доступны данные',
        body:
            'Доступ зависит от настроек видимости, роли пользователя и участия в кастинге, подборке или диалоге. Администраторы могут видеть данные, необходимые для модерации, поддержки и безопасности.',
      ),
      LegalDocumentSection(
        title: 'Хранение и удаление',
        body:
            'Пользователь может запросить удаление аккаунта и связанных персональных данных. Часть записей может сохраняться ограниченное время, если это требуется для безопасности, журналов действий, споров или законных обязательств.',
      ),
    ],
    sectionsEn: [
      LegalDocumentSection(
        title: 'Data we collect',
        body:
            'PK Management stores account data, profiles, castings, selections, messages, media files and technical notification delivery events. Minors must provide data through a parent/legal guardian or with their consent.',
      ),
      LegalDocumentSection(
        title: 'Why we use it',
        body:
            'Data is used to operate the catalogue, castings, communication, moderation, security, support and user-requested product workflows.',
      ),
      LegalDocumentSection(
        title: 'Who can access it',
        body:
            'Access depends on visibility settings, user role and participation in a casting, selection or dialog. Administrators may access data needed for moderation, support and safety.',
      ),
      LegalDocumentSection(
        title: 'Retention and deletion',
        body:
            'A user can request account deletion and removal of related personal data. Some records may be retained for a limited period when needed for safety, audit logs, disputes or legal obligations.',
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
            'Пользователь отвечает за точность данных, права на загружаемые материалы и корректность коммуникации. Запрещены чужие данные без разрешения, незаконный контент, спам и обход ограничений платформы.',
      ),
      LegalDocumentSection(
        title: 'Модерация и ограничения',
        body:
            'Администрация может скрывать, отклонять, ограничивать или удалять материалы и аккаунты при нарушениях правил, рисках безопасности или запросах правообладателей.',
      ),
      LegalDocumentSection(
        title: 'Кастинги и договоренности',
        body:
            'Приложение помогает организовать процесс, но конкретные условия съемок, оплат, документов и разрешений должны подтверждаться сторонами отдельно.',
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
            'Users are responsible for accurate data, rights to uploaded materials and respectful communication. Unauthorized personal data, illegal content, spam and platform abuse are prohibited.',
      ),
      LegalDocumentSection(
        title: 'Moderation and restrictions',
        body:
            'Administration may hide, reject, restrict or remove materials and accounts when rules are violated, safety risks appear or rights-holder requests are received.',
      ),
      LegalDocumentSection(
        title: 'Castings and agreements',
        body:
            'The app helps organize workflows, but specific shooting terms, payments, documents and permissions must be confirmed separately by the parties.',
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
            'Web-версия может использовать cookies, local storage, IndexedDB и похожие технологии для входа, восстановления сессии, очередей загрузки, сохранения настроек и стабильной работы приложения.',
      ),
      LegalDocumentSection(
        title: 'Служебные данные',
        body:
            'Служебные данные помогают держать пользователя авторизованным, запоминать настройки интерфейса, восстанавливать загрузки и поддерживать безопасность.',
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
            'The web app may use cookies, local storage, IndexedDB and similar technologies for sign-in, session recovery, upload queues, saved settings and stable app operation.',
      ),
      LegalDocumentSection(
        title: 'Functional data',
        body:
            'Functional data keeps the user signed in, remembers interface settings, restores uploads and supports security.',
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
            'Создавая аккаунт, пользователь подтверждает согласие на обработку данных, необходимых для работы анкеты, каталога, кастингов, подборок, сообщений, уведомлений и поддержки.',
      ),
      LegalDocumentSection(
        title: 'Модели, актеры и авторы медиа',
        body:
            'Участник подтверждает, что имеет право передавать свои данные и материалы. Для несовершеннолетних требуется участие или согласие родителя/законного представителя.',
      ),
      LegalDocumentSection(
        title: 'Заказчики и представители',
        body:
            'Заказчик или представитель подтверждает, что использует данные участников только в рамках кастинга, подбора, коммуникации и согласованных рабочих процессов.',
      ),
      LegalDocumentSection(
        title: 'Отзыв согласия',
        body:
            'Пользователь может обратиться за удалением аккаунта или отдельных данных. Часть технических записей может сохраняться ограниченно для безопасности и подтверждения выполненных действий.',
      ),
    ],
    sectionsEn: [
      LegalDocumentSection(
        title: 'Consent',
        body:
            'By creating an account, the user consents to processing data needed for profiles, catalogue, castings, selections, messages, notifications and support.',
      ),
      LegalDocumentSection(
        title: 'Talent and media authors',
        body:
            'Talent confirms they have the right to provide their data and materials. Minors require participation or consent of a parent/legal guardian.',
      ),
      LegalDocumentSection(
        title: 'Clients and representatives',
        body:
            'Clients or representatives confirm that participant data is used only for casting, selection, communication and agreed product workflows.',
      ),
      LegalDocumentSection(
        title: 'Withdrawal',
        body:
            'A user can request account or data deletion. Some technical records may be retained for a limited period for safety and proof of performed actions.',
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
