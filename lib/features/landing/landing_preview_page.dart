import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../ui/brand/brand_theme.dart';

class LandingPreviewPage extends StatelessWidget {
  const LandingPreviewPage({super.key});

  static const _ink = Color(0xFF181818);
  static const _paper = Color(0xFFE7E7E7);
  static const _muted = Color(0xFF616161);
  static const _line = Color(0xFFC8C8C8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, BrandTheme.greyTop, BrandTheme.greyMid],
          ),
        ),
        child: SelectionArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverToBoxAdapter(child: _hero(context)),
              const SliverToBoxAdapter(child: _AudienceSection()),
              const SliverToBoxAdapter(child: _FeatureSection()),
              const SliverToBoxAdapter(child: _StepsSection()),
              const SliverToBoxAdapter(child: _TrustSection()),
              SliverToBoxAdapter(child: _closingCta(context)),
              const SliverToBoxAdapter(child: _LandingFooter()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, BrandTheme.greyTop, BrandTheme.greyMid],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFCCCCCC))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Row(
            children: [
              Image.asset(
                'assets/images/pk-logo-red-512.png',
                width: 46,
                height: 46,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'PK MANAGEMENT',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 720) ...[
                _HeaderLink(label: 'ВОЗМОЖНОСТИ', onTap: () {}),
                _HeaderLink(label: 'КАК РАБОТАЕТ', onTap: () {}),
                _HeaderLink(label: 'ТАРИФЫ', onTap: () {}),
                const SizedBox(width: 8),
              ],
              OutlinedButton(
                onPressed: () => context.go(Routes.login),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _ink),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 17,
                  ),
                ),
                child: const Text('ВОЙТИ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 780;
    return Container(
      color: _ink,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: SizedBox(
            height: compact ? 840 : 690,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/landing-hero-draft.png',
                  fit: BoxFit.cover,
                  alignment: compact
                      ? const Alignment(0.56, 0)
                      : Alignment.center,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: compact
                          ? const [
                              Color(0xF5181818),
                              Color(0xA8181818),
                              Color(0x5C7A0000),
                            ]
                          : const [
                              Color(0xFF111111),
                              Color(0xE8191919),
                              Color(0x707A0000),
                              Color(0x10181818),
                            ],
                      stops: compact
                          ? const [0, 0.62, 1]
                          : const [0, 0.28, 0.58, 0.82],
                    ),
                  ),
                ),
                Align(
                  alignment: compact
                      ? Alignment.bottomLeft
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 24 : 72,
                      42,
                      24,
                      compact ? 46 : 42,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ЕДИНАЯ ПЛАТФОРМА ДЛЯ МОДЕЛЬНОЙ ИНДУСТРИИ',
                            style: TextStyle(
                              color: Color(0xFFFF746B),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'ТАЛАНТЫ. КАСТИНГИ. НОВЫЕ ВОЗМОЖНОСТИ.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 42 : 64,
                              height: 0.98,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Создавайте профессиональные анкеты, находите моделей и специалистов, проводите кастинги и управляйте проектами в одном приложении.',
                            style: TextStyle(
                              color: Color(0xFFE8E8E8),
                              fontSize: 18,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _HeroButton(
                                label: 'СОЗДАТЬ АНКЕТУ',
                                filled: true,
                                onTap: () => context.go(Routes.register),
                              ),
                              _HeroButton(
                                label: 'НАЙТИ МОДЕЛЬ',
                                onTap: () => context.go(Routes.search),
                              ),
                              _HeroButton(
                                label: 'РАЗМЕСТИТЬ КАСТИНГ',
                                onTap: () => context.go(Routes.register),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 22,
                  bottom: 18,
                  child: Text(
                    'ВРЕМЕННЫЙ ВИЗУАЛ ДЛЯ СОГЛАСОВАНИЯ',
                    style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _closingCta(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCA0000), BrandTheme.redTop, BrandTheme.redBottom],
          stops: [0, 0.48, 1],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 76),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 40,
            runSpacing: 30,
            children: [
              const SizedBox(
                width: 650,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ВАША СЛЕДУЮЩАЯ РАБОТА МОЖЕТ НАЧАТЬСЯ ЗДЕСЬ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Присоединяйтесь к профессиональному сообществу PK Management.',
                      style: TextStyle(
                        color: Color(0xFFF0D6D6),
                        fontSize: 17,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => context.go(Routes.register),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _ink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 22,
                  ),
                ),
                child: const Text('НАЧАТЬ РАБОТУ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudienceSection extends StatelessWidget {
  const _AudienceSection();

  @override
  Widget build(BuildContext context) {
    return const _LandingSection(
      eyebrow: 'ДЛЯ КАЖДОГО УЧАСТНИКА ИНДУСТРИИ',
      title: 'ОДНО ПРИЛОЖЕНИЕ — ТРИ СЦЕНАРИЯ РАБОТЫ',
      child: _ResponsiveCards(
        children: [
          _AudienceCard(
            number: '01',
            title: 'МОДЕЛЯМ И ТАЛАНТАМ',
            text:
                'Профессиональная анкета, портфолио, кастинги, отклики и прямое общение с заказчиками.',
            icon: Icons.person_outline_rounded,
          ),
          _AudienceCard(
            number: '02',
            title: 'АГЕНТСТВАМ',
            text:
                'Единая база моделей, подборки, PDF-презентации, кастинги и управление коммуникацией.',
            icon: Icons.apartment_rounded,
          ),
          _AudienceCard(
            number: '03',
            title: 'ЗАКАЗЧИКАМ',
            text:
                'Расширенный поиск, быстрый отбор, шорт-листы и доступ к проверенным профессионалам.',
            icon: Icons.business_center_outlined,
          ),
        ],
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF343434), Color(0xFF1E1E1E), Color(0xFF0E0E0E)],
        ),
      ),
      child: const _LandingSection(
        dark: true,
        eyebrow: 'ВОЗМОЖНОСТИ PK MANAGEMENT',
        title: 'ВСЁ НУЖНОЕ ДЛЯ ПРОФЕССИОНАЛЬНОЙ РАБОТЫ',
        child: _ResponsiveCards(
          minCardWidth: 230,
          children: [
            _FeatureCard(
              icon: Icons.badge_outlined,
              title: 'ПРОФЕССИОНАЛЬНЫЕ АНКЕТЫ',
              text:
                  'Точные параметры, роли, портфолио, видео и актуальный опыт.',
            ),
            _FeatureCard(
              icon: Icons.manage_search_rounded,
              title: 'УМНЫЙ ПОИСК',
              text:
                  'Фильтры по возрасту, росту, городу, внешности, роли и ставке.',
            ),
            _FeatureCard(
              icon: Icons.movie_filter_outlined,
              title: 'КАСТИНГИ',
              text: 'Публикация проектов, отклики, шорт-листы и этапы отбора.',
            ),
            _FeatureCard(
              icon: Icons.folder_copy_outlined,
              title: 'ПОДБОРКИ И PDF',
              text: 'Презентации кандидатов для клиента в несколько кликов.',
            ),
            _FeatureCard(
              icon: Icons.forum_outlined,
              title: 'РАБОЧИЕ ЧАТЫ',
              text: 'Вся коммуникация по анкете и кастингу в одном месте.',
            ),
            _FeatureCard(
              icon: Icons.verified_user_outlined,
              title: 'МОДЕРАЦИЯ',
              text:
                  'В каталоге размещаются профессиональные и актуальные анкеты.',
            ),
          ],
        ),
      ),
    );
  }
}

class _StepsSection extends StatelessWidget {
  const _StepsSection();

  @override
  Widget build(BuildContext context) {
    return const _LandingSection(
      eyebrow: 'КАК ЭТО РАБОТАЕТ',
      title: 'ОТ РЕГИСТРАЦИИ ДО НОВОГО ПРОЕКТА',
      child: _ResponsiveCards(
        children: [
          _StepCard(
            step: '01',
            title: 'СОЗДАЙТЕ ПРОФИЛЬ',
            text:
                'Зарегистрируйте аккаунт и выберите свою профессиональную роль.',
          ),
          _StepCard(
            step: '02',
            title: 'ЗАПОЛНИТЕ АНКЕТУ',
            text:
                'Добавьте точные данные, портфолио, опыт и актуальные контакты.',
          ),
          _StepCard(
            step: '03',
            title: 'НАЧНИТЕ РАБОТАТЬ',
            text:
                'Размещайтесь в каталоге, откликайтесь и находите нужных специалистов.',
          ),
        ],
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, BrandTheme.greyTop, BrandTheme.greyBottom],
        ),
        border: Border(
          top: BorderSide(color: LandingPreviewPage._line),
          bottom: BorderSide(color: LandingPreviewPage._line),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 66),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: const Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            spacing: 34,
            runSpacing: 30,
            children: [
              _TrustMetric(value: '01', label: 'единая профессиональная база'),
              _TrustMetric(value: '24/7', label: 'доступ к анкетам и проектам'),
              _TrustMetric(
                value: '100%',
                label: 'контроль владельца над анкетой',
              ),
              _TrustMetric(
                value: '10–22',
                label: 'поддержка по московскому времени',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingSection extends StatelessWidget {
  const _LandingSection({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.dark = false,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 86),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: BrandTheme.redTop,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 790),
                child: Text(
                  title,
                  style: TextStyle(
                    color: dark ? Colors.white : LandingPreviewPage._ink,
                    fontSize: MediaQuery.sizeOf(context).width < 600 ? 32 : 46,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 46),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveCards extends StatelessWidget {
  const _ResponsiveCards({required this.children, this.minCardWidth = 300});

  final List<Widget> children;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? (children.length >= 4 ? 3 : children.length)
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map(
                (child) => SizedBox(
                  width: width < minCardWidth && columns > 1
                      ? constraints.maxWidth
                      : width,
                  child: child,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({
    required this.number,
    required this.title,
    required this.text,
    required this.icon,
  });

  final String number;
  final String title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 310,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF4F4F4), Color(0xFFE5E5E5)],
        ),
        border: Border.all(color: LandingPreviewPage._line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                number,
                style: const TextStyle(
                  color: BrandTheme.redTop,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Icon(icon, size: 38, color: LandingPreviewPage._ink),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: LandingPreviewPage._ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            text,
            style: const TextStyle(
              color: LandingPreviewPage._muted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B3B3B), Color(0xFF202020), Color(0xFF171717)],
        ),
        border: Border.all(color: const Color(0xFF4A4A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFF5A52), size: 34),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFBEBEBE),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.text,
  });

  final String step;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 22, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: const TextStyle(
              color: BrandTheme.redTop,
              fontSize: 54,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [BrandTheme.redTop, Color(0xFFBDBDBD)],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(
              color: LandingPreviewPage._ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: LandingPreviewPage._muted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustMetric extends StatelessWidget {
  const _TrustMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: LandingPreviewPage._ink,
              fontSize: 39,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: LandingPreviewPage._muted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2C2C), Color(0xFF151515), Colors.black],
        ),
        border: Border(top: BorderSide(color: BrandTheme.redTop, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 30,
            runSpacing: 20,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/pk-logo-red-512.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'PK MANAGEMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
              const Text(
                'Черновик презентационной страницы · не опубликован',
                style: TextStyle(color: Color(0xFF898989), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: LandingPreviewPage._ink),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, letterSpacing: 1.1),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
    );
    if (filled) {
      return FilledButton(
        onPressed: onTap,
        style: style.copyWith(
          backgroundColor: const WidgetStatePropertyAll(BrandTheme.redTop),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: style.copyWith(
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        side: const WidgetStatePropertyAll(BorderSide(color: Colors.white54)),
      ),
      child: Text(label),
    );
  }
}
