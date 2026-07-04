import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_logger.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/appearance_lookups.dart';
import '../../ui/brand/brand_calendar.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/location_lookups.dart';
import '../../ui/brand/searchable_choice_field.dart';
import '../../ui/brand/ui_constants.dart';
import 'my_profile_controller.dart';
import 'profile_media_upload_queue.dart';
import 'profile_media_web_native_picker_stub.dart'
    if (dart.library.html) 'profile_media_web_native_picker_web.dart';
import 'profile_model.dart';

part 'my_profile_edit_parts.dart';

typedef _NameParts = ({String surname, String name});

const String _kSkipMediaDeleteConfirmKey = 'skip_media_delete_confirm';
const double _kMediaRemoveInset = 4;
const double _kProfileEditDesktopBreakpoint = 900.0;
const double _kProfileEditDesktopMaxWidth = 1360.0;
const double _kProfileEditDesktopSideWidth = 380.0;
const EdgeInsets _kProfileEditDesktopPad = EdgeInsets.fromLTRB(32, 22, 32, 32);
const List<String> _kProfileMediaCategories = [
  'Портфолио',
  'Портрет',
  'Снэп-шоты',
  'Polaroid',
  'Backstage',
  'Работы',
  'Showreel',
];

Alignment _coverFocalAlignment(double x, double y) {
  return Alignment(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));
}

String _profileErrorText(Object e, AppLocalizations t) {
  if (e is MyProfileException) {
    switch (e.code) {
      case MyProfileError.noUser:
        return t.profileErrorNoUser;
      case MyProfileError.fullNameRequired:
        return t.profileErrorFullNameRequired;
      case MyProfileError.ageRequired:
        return t.profileErrorAgeRequired;
      case MyProfileError.ageOutOfRange:
        return t.profileErrorAgeRange;
      case MyProfileError.heightRequired:
        return t.profileErrorHeightRequired;
      case MyProfileError.heightOutOfRange:
        return t.profileErrorHeightRange;
      case MyProfileError.bustRequired:
        return t.profileErrorBustRequired;
      case MyProfileError.bustOutOfRange:
        return t.profileErrorBustRange;
      case MyProfileError.waistRequired:
        return t.profileErrorWaistRequired;
      case MyProfileError.waistOutOfRange:
        return t.profileErrorWaistRange;
      case MyProfileError.hipsRequired:
        return t.profileErrorHipsRequired;
      case MyProfileError.hipsOutOfRange:
        return t.profileErrorHipsRange;
      case MyProfileError.profileLimitReached:
        return t.profileErrorLimitReached;
    }
  }
  return t.profileErrorSaveFailed;
}

class _EmptyProfileImagePlaceholder extends StatelessWidget {
  const _EmptyProfileImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(decoration: profileImagePlaceholderDecoration());
  }
}

class MyProfileEditPage extends ConsumerStatefulWidget {
  const MyProfileEditPage({
    super.key,
    required this.startBlank,
    required this.initial,
    this.initialProfileType,
  });
  final bool startBlank;
  final MyProfileState? initial;
  final ProfessionalProfileType? initialProfileType;

  @override
  ConsumerState<MyProfileEditPage> createState() => _MyProfileEditPageState();
}

class _MyProfileEditPageState extends ConsumerState<MyProfileEditPage> {
  bool get _isBusy => _actionBusy || _saving;
  SupabaseClient get _sb => ref.read(supabaseProvider);
  static const _skipMediaDeleteConfirmKey = _kSkipMediaDeleteConfirmKey;

  final _surnameC = TextEditingController();
  final _nameC = TextEditingController();
  final _birthDateC = TextEditingController();
  final _ageC = TextEditingController();
  final _heightC = TextEditingController();
  final _bustC = TextEditingController();
  final _waistC = TextEditingController();
  final _hipsC = TextEditingController();
  final _shoeSizeC = TextEditingController();
  final _minHourlyRateC = TextEditingController();
  final _minDailyFeeC = TextEditingController();
  final _eyeColorC = TextEditingController();
  final _hairColorC = TextEditingController();
  final _countryC = TextEditingController();
  final _cityC = TextEditingController();
  final _resumeC = TextEditingController();
  final _experienceC = TextEditingController();
  final _skillsC = TextEditingController();
  final _servicesC = TextEditingController();
  final _genresC = TextEditingController();
  final _equipmentC = TextEditingController();

  bool _inited = false;
  bool _saving = false;
  bool _actionBusy = false;
  String? _error;
  MyProfileState? _currentProfile;
  ProfessionalProfileType _profileType = ProfessionalProfileType.model;
  Set<ProfessionalProfileType> _profileRoles = {ProfessionalProfileType.model};
  String _birthDateIso = '';

  final _picker = ImagePicker();
  final List<XFile> _pickedPhotos = [];
  final List<XFile> _pickedVideos = [];
  int? _pickedCoverPhotoIndex;

  List<String> _photoUrls = [];
  List<String> _photoCategoryLabels = [];
  String _coverPhotoUrl = '';
  List<String> _videoUrls = [];
  List<String> _videoPreviewUrls = [];
  List<String> _videoCategoryLabels = [];
  String _showreelUrl = '';
  String _showreelPreviewUrl = '';
  double _coverPhotoFocalX = 0;
  double _coverPhotoFocalY = -0.72;
  List<String> _pendingPhotoUrls = [];
  List<String> _pendingPhotoCategoryLabels = [];
  String _pendingCoverPhotoUrl = '';
  double _pendingCoverPhotoFocalX = 0;
  double _pendingCoverPhotoFocalY = -0.72;
  List<String> _pendingVideoUrls = [];
  List<String> _pendingVideoPreviewUrls = [];
  List<String> _pendingVideoCategoryLabels = [];
  String _pendingShowreelUrl = '';
  String _pendingShowreelPreviewUrl = '';
  final List<String> _pickedPhotoCategoryLabels = [];
  final List<String> _pickedVideoCategoryLabels = [];
  int? _pickedShowreelVideoIndex;

  final Set<DateTime> _unavailableDays = <DateTime>{};
  AppLocalizations get _t => AppLocalizations.of(context)!;

  List<TextEditingController> get _qualityControllers => [
    _surnameC,
    _nameC,
    _birthDateC,
    _ageC,
    _heightC,
    _bustC,
    _waistC,
    _hipsC,
    _shoeSizeC,
    _eyeColorC,
    _hairColorC,
    _countryC,
    _cityC,
    _resumeC,
    _experienceC,
    _skillsC,
    _servicesC,
    _genresC,
    _equipmentC,
  ];

  List<String> get _countryOptions => countryOptions(_t);

  List<String> get _cityOptions {
    final selectedCountry = _countryC.text.trim();
    return cityOptionsForCountry(_t, selectedCountry);
  }

  List<ProfessionalProfileType> get _effectiveProfileRoles {
    return normalizeProfileRoles(_profileRoles, fallback: _profileType);
  }

  bool _hasProfileRole(ProfessionalProfileType role) {
    return _effectiveProfileRoles.contains(role);
  }

  bool get _usesPhysicalBasics {
    return profileRolesUsePhysicalBasics(_effectiveProfileRoles);
  }

  bool get _usesModelMeasurements {
    return profileRolesUseModelMeasurements(_effectiveProfileRoles);
  }

  bool get _hasProfessionalInfoRole {
    return profileRolesHaveProfessionalInfo(_effectiveProfileRoles);
  }

  ProfessionalProfileType get _professionalFieldsType {
    return profileRolesProfessionalType(_effectiveProfileRoles);
  }

  void _setProfileRoles(Set<ProfessionalProfileType> roles) {
    final normalized = normalizeProfileRoles(roles, fallback: _profileType);
    setState(() {
      _profileRoles = normalized.toSet();
      if (!_profileRoles.contains(_profileType)) {
        _profileType = normalized.first;
      }
    });
  }

  _NameParts _splitFullName(String fullName) {
    return _ProfileNameHelper.split(fullName);
  }

  @override
  void initState() {
    super.initState();
    for (final controller in _qualityControllers) {
      controller.addListener(_onQualityInputChanged);
    }
  }

  void _onQualityInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _runIfIdle(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _actionBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _removeAtSafe<T>(List<T> list, int index) {
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
  }

  MyProfileState _resolveBaseProfile() {
    final uid = _sb.auth.currentUser?.id ?? '';

    if (widget.startBlank) {
      final current = _currentProfile;
      if (current != null && current.id.trim().isNotEmpty) {
        return current;
      }
      return MyProfileState.blank(userId: uid);
    }

    final current = _currentProfile;
    final initial = widget.initial;
    if (current != null &&
        current.id.trim().isNotEmpty &&
        (initial == null || current.id == initial.id)) {
      return current;
    }

    return initial ?? MyProfileState.blank(userId: uid);
  }

  void _onCountryChanged(String value) {
    final normalized = value.trim();

    setState(() {
      _countryC.text = normalized;

      final allowedCities = cityOptionsForCountry(_t, normalized);
      final currentCity = _cityC.text.trim();
      if (currentCity.isNotEmpty && !allowedCities.contains(currentCity)) {
        _cityC.clear();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _qualityControllers) {
      controller.removeListener(_onQualityInputChanged);
    }
    _surnameC.dispose();
    _nameC.dispose();
    _birthDateC.dispose();
    _ageC.dispose();
    _heightC.dispose();
    _bustC.dispose();
    _waistC.dispose();
    _hipsC.dispose();
    _shoeSizeC.dispose();
    _minHourlyRateC.dispose();
    _minDailyFeeC.dispose();
    _eyeColorC.dispose();
    _hairColorC.dispose();
    _countryC.dispose();
    _cityC.dispose();
    _resumeC.dispose();
    _experienceC.dispose();
    _skillsC.dispose();
    _servicesC.dispose();
    _genresC.dispose();
    _equipmentC.dispose();
    super.dispose();
  }

  void _clearForm() {
    _surnameC.clear();
    _nameC.clear();
    _birthDateC.clear();
    _ageC.clear();
    _heightC.clear();
    _bustC.clear();
    _waistC.clear();
    _hipsC.clear();
    _shoeSizeC.clear();
    _minHourlyRateC.clear();
    _minDailyFeeC.clear();
    _eyeColorC.clear();
    _hairColorC.clear();
    _countryC.clear();
    _cityC.clear();
    _resumeC.clear();
    _experienceC.clear();
    _skillsC.clear();
    _servicesC.clear();
    _genresC.clear();
    _equipmentC.clear();

    _profileType = widget.initialProfileType ?? ProfessionalProfileType.model;
    _profileRoles = {_profileType};
    _birthDateIso = '';
    _unavailableDays.clear();
    _photoUrls = [];
    _photoCategoryLabels = [];
    _coverPhotoUrl = '';
    _videoUrls = [];
    _videoPreviewUrls = [];
    _videoCategoryLabels = [];
    _showreelUrl = '';
    _showreelPreviewUrl = '';
    _coverPhotoFocalX = 0;
    _coverPhotoFocalY = -0.72;
    _pendingPhotoUrls = [];
    _pendingPhotoCategoryLabels = [];
    _pendingCoverPhotoUrl = '';
    _pendingCoverPhotoFocalX = 0;
    _pendingCoverPhotoFocalY = -0.72;
    _pendingVideoUrls = [];
    _pendingVideoPreviewUrls = [];
    _pendingVideoCategoryLabels = [];
    _pendingShowreelUrl = '';
    _pendingShowreelPreviewUrl = '';
    _pickedPhotos.clear();
    _pickedVideos.clear();
    _pickedPhotoCategoryLabels.clear();
    _pickedVideoCategoryLabels.clear();
    _pickedCoverPhotoIndex = null;
    _pickedShowreelVideoIndex = null;
    _currentProfile = null;
    _error = null;
  }

  void _initFromState(MyProfileState s) {
    if (_inited) return;
    _inited = true;
    _currentProfile = s;
    _profileType = s.profileType;
    _profileRoles = s.effectiveProfileRoles.toSet();

    if (widget.startBlank) {
      _clearForm();
      return;
    }

    final nameParts = _splitFullName(s.fullName);
    _surnameC.text = nameParts.surname;
    _nameC.text = nameParts.name;

    _birthDateIso = s.birthDate;
    _birthDateC.text = _birthDateLabel(s.birthDate);
    final calculatedAge = _ageFromBirthDateIso(s.birthDate) ?? s.age;
    _ageC.text = calculatedAge > 0 ? calculatedAge.toString() : '';
    _heightC.text = s.height > 0 ? s.height.toString() : '';
    _bustC.text = s.bust > 0 ? s.bust.toString() : '';
    _waistC.text = s.waist > 0 ? s.waist.toString() : '';
    _hipsC.text = s.hips > 0 ? s.hips.toString() : '';
    _shoeSizeC.text = s.shoeSize > 0 ? s.shoeSize.toString() : '';
    _minHourlyRateC.text = s.minHourlyRate > 0
        ? s.minHourlyRate.toString()
        : '';
    _minDailyFeeC.text = s.minDailyFee > 0 ? s.minDailyFee.toString() : '';
    _eyeColorC.text = s.eyeColor;
    _hairColorC.text = s.hairColor;
    _countryC.text = s.country;
    _cityC.text = s.city;
    _resumeC.text = s.resume;
    _experienceC.text = s.experience;
    _skillsC.text = s.skills;
    _servicesC.text = s.services;
    _genresC.text = s.genres;
    _equipmentC.text = s.equipment;

    _unavailableDays
      ..clear()
      ..addAll(
        s.unavailableDays
            .map((v) => DateTime.tryParse(v))
            .whereType<DateTime>()
            .map(_dateOnly),
      );

    _photoUrls = List<String>.from(s.photoUrls);
    _photoCategoryLabels = _categoryLabelsFor(
      s.photoCategoryLabels,
      s.photoUrls.length,
      fallback: 'Портфолио',
    );
    _coverPhotoUrl = s.coverPhotoUrl.trim();
    _videoUrls = List<String>.from(s.videoUrls);
    _videoPreviewUrls = List<String>.from(s.videoPreviewUrls);
    _videoCategoryLabels = _categoryLabelsFor(
      s.videoCategoryLabels,
      s.videoUrls.length,
      fallback: 'Видео',
    );
    _showreelUrl = s.showreelUrl.trim();
    _showreelPreviewUrl = s.showreelPreviewUrl.trim();
    _coverPhotoFocalX = s.coverPhotoFocalX;
    _coverPhotoFocalY = s.coverPhotoFocalY;
    _pendingPhotoUrls = List<String>.from(s.pendingPhotoUrls);
    _pendingPhotoCategoryLabels = _categoryLabelsFor(
      s.pendingPhotoCategoryLabels,
      s.pendingPhotoUrls.length,
      fallback: 'Портфолио',
    );
    _pendingCoverPhotoUrl = s.pendingCoverPhotoUrl.trim();
    _pendingCoverPhotoFocalX = s.pendingCoverPhotoFocalX;
    _pendingCoverPhotoFocalY = s.pendingCoverPhotoFocalY;
    _pendingVideoUrls = List<String>.from(s.pendingVideoUrls);
    _pendingVideoPreviewUrls = List<String>.from(s.pendingVideoPreviewUrls);
    _pendingVideoCategoryLabels = _categoryLabelsFor(
      s.pendingVideoCategoryLabels,
      s.pendingVideoUrls.length,
      fallback: 'Видео',
    );
    _pendingShowreelUrl = s.pendingShowreelUrl.trim();
    _pendingShowreelPreviewUrl = s.pendingShowreelPreviewUrl.trim();
  }

  List<String> _categoryLabelsFor(
    List<String> labels,
    int length, {
    required String fallback,
  }) {
    String normalize(String label) {
      final clean = label.trim();
      if (clean.toLowerCase() == 'full length') return 'Снэп-шоты';
      return clean;
    }

    return [
      for (var i = 0; i < length; i++)
        if (i < labels.length && labels[i].trim().isNotEmpty)
          normalize(labels[i])
        else
          fallback,
    ];
  }

  int _intOrZero(String s) => int.tryParse(s.trim()) ?? 0;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? _parseIsoDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  int _ageFromBirthDate(DateTime birthDate) {
    final today = _dateOnly(DateTime.now());
    var age = today.year - birthDate.year;
    final hadBirthdayThisYear =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthdayThisYear) age -= 1;
    return age.clamp(0, 120);
  }

  int? _ageFromBirthDateIso(String iso) {
    final date = _parseIsoDate(iso);
    if (date == null) return null;
    return _ageFromBirthDate(date);
  }

  String _isoDate(DateTime date) => date.toIso8601String().split('T').first;

  String _birthDateLabel(String iso) {
    final date = _parseIsoDate(iso);
    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final age = _ageFromBirthDate(date);
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    final suffix = lang == 'ru' ? '$age лет' : '$age y.o.';
    return '$day.$month.$year · $suffix';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final current = _parseIsoDate(_birthDateIso);
    final initial = current ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 100, now.month, now.day),
      lastDate: now,
      helpText:
          Localizations.localeOf(context).languageCode.toLowerCase() == 'ru'
          ? 'Дата рождения'
          : 'Birth date',
    );
    if (picked == null || !mounted) return;

    final date = _dateOnly(picked);
    final age = _ageFromBirthDate(date);
    setState(() {
      _birthDateIso = _isoDate(date);
      _birthDateC.text = _birthDateLabel(_birthDateIso);
      _ageC.text = age.toString();
    });
  }

  void _toggleUnavailableDay(DateTime d) {
    final dd = _dateOnly(d);
    setState(() {
      if (_unavailableDays.contains(dd)) {
        _unavailableDays.remove(dd);
      } else {
        _unavailableDays.add(dd);
      }
    });
  }

  List<String> _unavailableDaysAsIsoDates() {
    return _unavailableDays
        .map((d) => _dateOnly(d).toIso8601String().split('T').first)
        .toList(growable: false);
  }

  MyProfileState _buildNextProfile(
    MyProfileState base,
    _NameParts nn, {
    required bool submitForReview,
    required bool approveImmediately,
    String selectedUploadedCoverPhotoUrl = '',
  }) {
    final birthDate = _birthDateIso.trim();
    final calculatedAge =
        _ageFromBirthDateIso(birthDate) ?? _intOrZero(_ageC.text);
    final nextStatus = approveImmediately
        ? ProfileStatus.approved
        : submitForReview
        ? ProfileStatus.pending
        : base.status;
    final uploadedCover = selectedUploadedCoverPhotoUrl.trim();
    final selectedFocalX = _pickedCoverPhotoIndex != null
        ? _pendingCoverPhotoFocalX
        : _coverPhotoFocalX;
    final selectedFocalY = _pickedCoverPhotoIndex != null
        ? _pendingCoverPhotoFocalY
        : _coverPhotoFocalY;
    final nextCoverPhotoUrl = approveImmediately || base.id.trim().isEmpty
        ? (uploadedCover.isNotEmpty ? uploadedCover : _coverPhotoUrl.trim())
        : _coverPhotoUrl.trim();
    final nextPendingCoverPhotoUrl =
        !approveImmediately &&
            base.id.trim().isNotEmpty &&
            uploadedCover.isNotEmpty
        ? uploadedCover
        : _pendingCoverPhotoUrl.trim();
    return base.copyWith(
      profileType: _profileType,
      profileRoles: _effectiveProfileRoles,
      fullName: _ProfileNameHelper.buildFullName(nn),
      birthDate: birthDate,
      status: nextStatus,
      moderationComment: submitForReview || approveImmediately
          ? null
          : base.moderationComment,
      age: calculatedAge,
      height: _intOrZero(_heightC.text),
      bust: _intOrZero(_bustC.text),
      waist: _intOrZero(_waistC.text),
      hips: _intOrZero(_hipsC.text),
      city: _cityC.text.trim(),
      shoeSize: _intOrZero(_shoeSizeC.text),
      minHourlyRate: _intOrZero(_minHourlyRateC.text),
      minDailyFee: _intOrZero(_minDailyFeeC.text),
      eyeColor: _eyeColorC.text.trim(),
      hairColor: _hairColorC.text.trim(),
      country: _countryC.text.trim(),
      resume: _resumeC.text,
      experience: _experienceC.text.trim(),
      skills: _skillsC.text.trim(),
      services: _servicesC.text.trim(),
      genres: _genresC.text.trim(),
      equipment: _equipmentC.text.trim(),
      unavailableDays: _unavailableDaysAsIsoDates(),
      photoUrls: List<String>.from(_photoUrls),
      photoCategoryLabels: _categoryLabelsFor(
        _photoCategoryLabels,
        _photoUrls.length,
        fallback: 'Портфолио',
      ),
      coverPhotoUrl: nextCoverPhotoUrl,
      coverPhotoFocalX: approveImmediately || base.id.trim().isEmpty
          ? selectedFocalX
          : _coverPhotoFocalX,
      coverPhotoFocalY: approveImmediately || base.id.trim().isEmpty
          ? selectedFocalY
          : _coverPhotoFocalY,
      videoUrls: List<String>.from(_videoUrls),
      videoPreviewUrls: List<String>.from(_videoPreviewUrls),
      videoCategoryLabels: _categoryLabelsFor(
        _videoCategoryLabels,
        _videoUrls.length,
        fallback: 'Видео',
      ),
      showreelUrl: _showreelUrl.trim(),
      showreelPreviewUrl: _showreelPreviewUrl.trim(),
      pendingPhotoUrls: List<String>.from(_pendingPhotoUrls),
      pendingPhotoCategoryLabels: _categoryLabelsFor(
        _pendingPhotoCategoryLabels,
        _pendingPhotoUrls.length,
        fallback: 'Портфолио',
      ),
      pendingCoverPhotoUrl: nextPendingCoverPhotoUrl,
      pendingCoverPhotoFocalX: nextPendingCoverPhotoUrl.isNotEmpty
          ? selectedFocalX
          : _pendingCoverPhotoFocalX,
      pendingCoverPhotoFocalY: nextPendingCoverPhotoUrl.isNotEmpty
          ? selectedFocalY
          : _pendingCoverPhotoFocalY,
      pendingVideoUrls: List<String>.from(_pendingVideoUrls),
      pendingVideoPreviewUrls: List<String>.from(_pendingVideoPreviewUrls),
      pendingVideoCategoryLabels: _categoryLabelsFor(
        _pendingVideoCategoryLabels,
        _pendingVideoUrls.length,
        fallback: 'Видео',
      ),
      pendingShowreelUrl: _pendingShowreelUrl.trim(),
      pendingShowreelPreviewUrl: _pendingShowreelPreviewUrl.trim(),
      hasPendingMedia:
          _pendingPhotoUrls.isNotEmpty ||
          _pendingVideoUrls.isNotEmpty ||
          _pendingVideoPreviewUrls.isNotEmpty ||
          _pendingShowreelUrl.trim().isNotEmpty,
    );
  }

  _ProfileQuality _profileQuality() {
    final t = AppLocalizations.of(context)!;
    final photoCount = _photoUrls.length + _pickedPhotos.length;
    final videoCount = _videoUrls.length + _pickedVideos.length;
    final isModel = _hasProfileRole(ProfessionalProfileType.model);
    final usesModelMeasurements = _usesModelMeasurements;
    final usesPhysicalBasics = _usesPhysicalBasics;
    final hasProfessionalRole = _hasProfessionalInfoRole;
    final hasBirthDate = _parseIsoDate(_birthDateIso) != null;
    final hasProfessionalInfo =
        _experienceC.text.trim().isNotEmpty ||
        _skillsC.text.trim().isNotEmpty ||
        _servicesC.text.trim().isNotEmpty ||
        _genresC.text.trim().isNotEmpty;

    final requiredChecks = <bool>[
      _surnameC.text.trim().isNotEmpty,
      _nameC.text.trim().isNotEmpty,
      if (usesPhysicalBasics) hasBirthDate,
      if (usesPhysicalBasics) _intOrZero(_heightC.text) > 0,
      if (usesModelMeasurements) _intOrZero(_bustC.text) > 0,
      if (usesModelMeasurements) _intOrZero(_waistC.text) > 0,
      if (usesModelMeasurements) _intOrZero(_hipsC.text) > 0,
      if (usesModelMeasurements) _intOrZero(_shoeSizeC.text) > 0,
      if (usesModelMeasurements) _eyeColorC.text.trim().isNotEmpty,
      if (usesModelMeasurements) _hairColorC.text.trim().isNotEmpty,
      _countryC.text.trim().isNotEmpty,
      _cityC.text.trim().isNotEmpty,
      if (hasProfessionalRole) hasProfessionalInfo,
    ];

    var score = 0;
    for (final ok in requiredChecks) {
      if (ok) score += 5;
    }
    if (photoCount >= 1) score += 15;
    if (isModel && photoCount >= 2) score += 15;
    if (_resumeC.text.trim().length >= 30) score += 5;
    if (videoCount >= 1) score += 5;
    final maxScore =
        (requiredChecks.length * 5) + 15 + (isModel ? 15 : 0) + 5 + 5;
    final percent = maxScore <= 0 ? 0 : ((score / maxScore) * 100).round();

    return _ProfileQuality(
      percent: percent.clamp(0, 100),
      missing: [
        if (requiredChecks.any((ok) => !ok)) t.profileQualityRequiredFields,
        if (photoCount < 1) t.profileQualityPortraitPhoto,
        if (isModel && photoCount < 2) t.profileQualityFullBodyPhoto,
        if (hasProfessionalRole && !hasProfessionalInfo)
          t.profileQualityProfessionalInfo,
        if (_resumeC.text.trim().length < 30) t.profileQualityAbout,
        if (videoCount < 1) t.profileQualityVideo,
      ],
    );
  }

  _NameParts? _resolveNameForSave(MyProfileState base) {
    try {
      return _ProfileNameHelper.resolveForSave(
        isNewProfile: widget.startBlank || base.id.trim().isEmpty,
        surnameInput: _surnameC.text,
        nameInput: _nameC.text,
        fallbackFullName: (_currentProfile ?? base).fullName,
        t: _t,
        setError: (message) => setState(() => _error = message),
      );
    } on _ProfileNameResolveException {
      return null;
    }
  }

  Future<String> _requireUid() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw MyProfileException(MyProfileError.noUser);
    return uid;
  }

  Future<void> _pickPhotos() async {
    await _runIfIdle(() async {
      setState(() => _error = null);

      try {
        final list = kIsWeb && ProfileMediaWebNativePicker.isSupported
            ? await ProfileMediaWebNativePicker.pickPhotos()
            : await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
        if (list.isEmpty || !mounted) return;

        final hadNoPhotos =
            _photoUrls.isEmpty &&
            _pendingPhotoUrls.isEmpty &&
            _pickedPhotos.isEmpty &&
            _coverPhotoUrl.trim().isEmpty &&
            _pendingCoverPhotoUrl.trim().isEmpty;
        setState(() {
          final firstNewIndex = _pickedPhotos.length;
          _pickedPhotos.addAll(list);
          _pickedPhotoCategoryLabels.addAll(
            List<String>.filled(list.length, 'Портфолио'),
          );
          if (hadNoPhotos && list.isNotEmpty) {
            _pickedCoverPhotoIndex = firstNewIndex;
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _error = _t.profileErrorSaveFailed);
      }
    });
  }

  Future<void> _pickVideo() async {
    await _runIfIdle(() async {
      setState(() => _error = null);

      try {
        final picked = kIsWeb && ProfileMediaWebNativePicker.isSupported
            ? await ProfileMediaWebNativePicker.pickVideos()
            : <XFile>[
                if (await _picker.pickVideo(source: ImageSource.gallery)
                    case final v?)
                  if (_isPickedVideo(v)) v,
              ];

        if (picked.isEmpty || !mounted) return;

        setState(() {
          _pickedVideos.addAll(picked);
          _pickedVideoCategoryLabels.addAll(
            List<String>.filled(picked.length, 'Видео'),
          );
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _error = _t.profileErrorSaveFailed);
      }
    });
  }

  bool _isPickedVideo(XFile file) {
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('video/')) return true;

    final path = file.path.toLowerCase();
    final name = file.name.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        path.endsWith('.webm') ||
        path.endsWith('.avi') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.m4v') ||
        name.endsWith('.webm') ||
        name.endsWith('.avi');
  }

  Future<void> _saveExistingProfile(MyProfileState base) async {
    await _runIfIdle(() async {
      await _saveAndMaybeSubmit(base, submitForReview: false);
    });
  }

  Future<void> _submitExistingProfile(MyProfileState base) async {
    await _runIfIdle(() async {
      await _saveAndMaybeSubmit(base, submitForReview: true);
    });
  }

  Future<String?> _saveAndMaybeSubmit(
    MyProfileState base, {
    required bool submitForReview,
    bool approveImmediately = false,
    bool closeAfter = true,
  }) async {
    if (_saving) return null;

    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _saving = true;
    });

    final nn = _resolveNameForSave(base);
    if (nn == null) {
      if (mounted) {
        setState(() => _saving = false);
      }
      return null;
    }

    try {
      final uid = await _requireUid();
      final pickedPhotos = List<XFile>.from(_pickedPhotos);
      final pickedVideos = List<XFile>.from(_pickedVideos);
      final pickedCoverPhotoIndex = _pickedCoverPhotoIndex;
      final pickedPhotoCategoryLabels = List<String>.from(
        _pickedPhotoCategoryLabels,
      );
      final pickedVideoCategoryLabels = List<String>.from(
        _pickedVideoCategoryLabels,
      );
      final pickedShowreelVideoIndex = _pickedShowreelVideoIndex;
      final hasPickedMedia = pickedPhotos.isNotEmpty || pickedVideos.isNotEmpty;

      final next = _buildNextProfile(
        base,
        nn,
        submitForReview: submitForReview,
        approveImmediately: approveImmediately,
      );

      final saved = await ref
          .read(myProfileProvider.notifier)
          .saveProfileWithPendingMedia(
            profile: next,
            newPhotoUrls: const <String>[],
            newVideoUrls: const <String>[],
            newVideoPreviewUrls: const <String>[],
          );
      final visibleSaved = approveImmediately
          ? await ref
                .read(myProfileProvider.notifier)
                .publishAdminProfile(saved.id)
          : saved;

      if (!approveImmediately &&
          submitForReview &&
          visibleSaved.status != ProfileStatus.pending) {
        await ref
            .read(myProfileProvider.notifier)
            .submitForReview(visibleSaved.id);
      }

      if (!mounted) return visibleSaved.id;

      setState(() {
        _currentProfile = visibleSaved;
        _pickedPhotos.clear();
        _pickedVideos.clear();
        _pickedPhotoCategoryLabels.clear();
        _pickedVideoCategoryLabels.clear();
        _pickedCoverPhotoIndex = null;
        _pickedShowreelVideoIndex = null;

        _photoUrls = List<String>.from(visibleSaved.photoUrls);
        _photoCategoryLabels = _categoryLabelsFor(
          visibleSaved.photoCategoryLabels,
          visibleSaved.photoUrls.length,
          fallback: 'Портфолио',
        );
        _coverPhotoUrl = visibleSaved.coverPhotoUrl.trim();
        _videoUrls = List<String>.from(visibleSaved.videoUrls);
        _videoPreviewUrls = List<String>.from(visibleSaved.videoPreviewUrls);
        _videoCategoryLabels = _categoryLabelsFor(
          visibleSaved.videoCategoryLabels,
          visibleSaved.videoUrls.length,
          fallback: 'Видео',
        );
        _showreelUrl = visibleSaved.showreelUrl.trim();
        _showreelPreviewUrl = visibleSaved.showreelPreviewUrl.trim();
        _pendingPhotoUrls = List<String>.from(visibleSaved.pendingPhotoUrls);
        _pendingPhotoCategoryLabels = _categoryLabelsFor(
          visibleSaved.pendingPhotoCategoryLabels,
          visibleSaved.pendingPhotoUrls.length,
          fallback: 'Портфолио',
        );
        _pendingCoverPhotoUrl = visibleSaved.pendingCoverPhotoUrl.trim();
        _pendingVideoUrls = List<String>.from(visibleSaved.pendingVideoUrls);
        _pendingVideoPreviewUrls = List<String>.from(
          visibleSaved.pendingVideoPreviewUrls,
        );
        _pendingVideoCategoryLabels = _categoryLabelsFor(
          visibleSaved.pendingVideoCategoryLabels,
          visibleSaved.pendingVideoUrls.length,
          fallback: 'Видео',
        );
        _pendingShowreelUrl = visibleSaved.pendingShowreelUrl.trim();
        _pendingShowreelPreviewUrl = visibleSaved.pendingShowreelPreviewUrl
            .trim();
      });

      if (hasPickedMedia) {
        _showMediaUploadQueuedSnack();
        ref
            .read(profileMediaUploadQueueProvider.notifier)
            .enqueue(
              uid: uid,
              profile: visibleSaved,
              pickedPhotos: pickedPhotos,
              pickedVideos: pickedVideos,
              pickedCoverPhotoIndex: pickedCoverPhotoIndex,
              pickedPhotoCategoryLabels: pickedPhotoCategoryLabels,
              pickedVideoCategoryLabels: pickedVideoCategoryLabels,
              pickedShowreelVideoIndex: pickedShowreelVideoIndex,
              approveImmediately: approveImmediately,
            );
      }

      if (closeAfter) Navigator.of(context).pop();
      return visibleSaved.id;
    } catch (e, st) {
      AppLogger.error('Failed to save profile', error: e, stackTrace: st);
      if (!mounted) return null;
      setState(() {
        _error = e is MyProfileException
            ? _profileErrorText(e, _t)
            : _t.profileErrorSaveFailed;
      });
      return null;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMediaUploadQueuedSnack() {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRussian
              ? 'Анкета сохранена. Фото и видео догружаются в фоне.'
              : 'Profile saved. Photos and videos are uploading in the background.',
        ),
      ),
    );
  }

  Future<void> _submitNew(MyProfileState base) async {
    await _runIfIdle(() async {
      await _saveAndMaybeSubmit(base, submitForReview: true);
    });
  }

  Future<void> _saveAdminProfile(MyProfileState base) async {
    await _runIfIdle(() async {
      await _saveAndMaybeSubmit(
        base,
        submitForReview: false,
        approveImmediately: true,
      );
    });
  }

  Future<void> _delete(MyProfileState base) async {
    await _runIfIdle(() async {
      FocusScope.of(context).unfocus();
      setState(() => _error = null);

      try {
        await ref.read(myProfileProvider.notifier).deleteProfile(base.id);
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e is MyProfileException
              ? _profileErrorText(e, _t)
              : _t.profileErrorDeleteFailed;
        });
      }
    });
  }

  Future<bool> _confirmMediaDelete() async {
    final prefs = await SharedPreferences.getInstance();
    final skipConfirm = prefs.getBool(_skipMediaDeleteConfirmKey) ?? false;
    if (skipConfirm) return true;
    if (!mounted) return false;

    bool dontAskAgain = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return _BrandedDialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t.profileDeleteMediaConfirmTitle,
                    style: kProfileDialogTitleStyle,
                  ),
                  const SizedBox(height: kGap12),
                  Text(
                    _t.profileDeleteMediaConfirmMessage,
                    style: kProfileDialogBodyStyle,
                  ),
                  const SizedBox(height: kGap14),
                  InkWell(
                    borderRadius: BorderRadius.circular(
                      kProfileCheckboxRowRadius,
                    ),
                    onTap: () {
                      setLocalState(() {
                        dontAskAgain = !dontAskAgain;
                      });
                    },
                    child: Padding(
                      padding: kProfileCheckboxRowPad,
                      child: Row(
                        children: [
                          Container(
                            width: kProfileCheckboxSize,
                            height: kProfileCheckboxSize,
                            decoration: BoxDecoration(
                              color: dontAskAgain ? kTextDark : Colors.white,
                              borderRadius: BorderRadius.circular(
                                kProfileCheckboxRadius,
                              ),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: dontAskAgain
                                ? const Icon(
                                    Icons.check,
                                    size: kProfileCheckboxIconSize,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: kProfileCheckboxGap),
                          Expanded(
                            child: Text(
                              _t.profileDeleteMediaDontAskAgain,
                              style: kProfileDialogCheckboxTextStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: kGap14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: BrandTheme.pillHeight,
                          child: BrandPillButton(
                            label: _t.noUpper,
                            style: BrandPillStyle.light,
                            onTap: () => Navigator.of(context).pop(false),
                          ),
                        ),
                      ),
                      const SizedBox(width: kGap10),
                      Expanded(
                        child: SizedBox(
                          height: BrandTheme.pillHeight,
                          child: BrandPillButton(
                            label: _t.yesUpper,
                            style: BrandPillStyle.dark,
                            onTap: () => Navigator.of(context).pop(true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final confirmed = result ?? false;
    if (confirmed && dontAskAgain) {
      await prefs.setBool(_skipMediaDeleteConfirmKey, true);
    }
    return confirmed;
  }

  Future<void> _removePhotoAt(int index, {required bool isPicked}) async {
    final confirmed = await _confirmMediaDelete();
    if (!confirmed || !mounted) return;

    setState(() {
      if (isPicked) {
        _removeAtSafe(_pickedPhotos, index);
        _removeAtSafe(_pickedPhotoCategoryLabels, index);
        final selected = _pickedCoverPhotoIndex;
        if (selected == index) {
          _pickedCoverPhotoIndex = null;
        } else if (selected != null && selected > index) {
          _pickedCoverPhotoIndex = selected - 1;
        }
      } else {
        final removed = index >= 0 && index < _photoUrls.length
            ? _photoUrls[index]
            : '';
        _removeAtSafe(_photoUrls, index);
        _removeAtSafe(_photoCategoryLabels, index);
        if (_coverPhotoUrl.trim() == removed.trim()) {
          _coverPhotoUrl = _photoUrls.isEmpty ? '' : _photoUrls.first;
        }
      }
    });
  }

  Future<void> _removeVideoAt(int index, {required bool isPicked}) async {
    final confirmed = await _confirmMediaDelete();
    if (!confirmed || !mounted) return;

    setState(() {
      if (isPicked) {
        _removeAtSafe(_pickedVideos, index);
        _removeAtSafe(_pickedVideoCategoryLabels, index);
        final selected = _pickedShowreelVideoIndex;
        if (selected == index) {
          _pickedShowreelVideoIndex = null;
        } else if (selected != null && selected > index) {
          _pickedShowreelVideoIndex = selected - 1;
        }
      } else {
        final removed = index >= 0 && index < _videoUrls.length
            ? _videoUrls[index]
            : '';
        _removeAtSafe(_videoUrls, index);
        _removeAtSafe(_videoPreviewUrls, index);
        _removeAtSafe(_videoCategoryLabels, index);
        if (_showreelUrl.trim() == removed.trim()) {
          _showreelUrl = '';
          _showreelPreviewUrl = '';
        }
      }
    });
  }

  void _makeCoverPhotoAt(int index, {required bool isPicked}) {
    setState(() {
      if (isPicked) {
        if (index < 0 || index >= _pickedPhotos.length) return;
        _pickedCoverPhotoIndex = index;
        _pendingCoverPhotoFocalX = 0;
        _pendingCoverPhotoFocalY = -0.72;
      } else {
        if (index < 0 || index >= _photoUrls.length) return;
        _coverPhotoUrl = _photoUrls[index].trim();
        _pickedCoverPhotoIndex = null;
        _coverPhotoFocalX = 0;
        _coverPhotoFocalY = -0.72;
      }
    });
  }

  Future<void> _editCoverFrame({required bool pending}) async {
    var draftX = pending ? _pendingCoverPhotoFocalX : _coverPhotoFocalX;
    var draftY = pending ? _pendingCoverPhotoFocalY : _coverPhotoFocalY;
    var draftZoom = 1.0;
    final imageFile =
        pending &&
            _pickedCoverPhotoIndex != null &&
            _pickedCoverPhotoIndex! >= 0 &&
            _pickedCoverPhotoIndex! < _pickedPhotos.length
        ? _pickedPhotos[_pickedCoverPhotoIndex!]
        : null;
    final imageUrl = imageFile == null
        ? (pending ? _pendingCoverPhotoUrl : _coverPhotoUrl).trim()
        : '';
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void update({double? x, double? y}) {
              setSheetState(() {
                draftX = (x ?? draftX).clamp(-1.0, 1.0);
                draftY = (y ?? draftY).clamp(-1.0, 1.0);
              });
              if (!mounted) return;
              setState(() {
                if (pending) {
                  _pendingCoverPhotoFocalX = draftX;
                  _pendingCoverPhotoFocalY = draftY;
                } else {
                  _coverPhotoFocalX = draftX;
                  _coverPhotoFocalY = draftY;
                }
              });
            }

            void updateZoom(double value) {
              setSheetState(() {
                draftZoom = value.clamp(1.0, 2.4);
              });
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: profileCardDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isRussian ? 'КАДР ОБЛОЖКИ' : 'COVER FRAME',
                        textAlign: TextAlign.center,
                        style: BrandTheme.pillText.copyWith(
                          color: kTextDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CoverFramePreview(
                        imageUrl: imageUrl,
                        imageFile: imageFile,
                        alignment: _coverFocalAlignment(draftX, draftY),
                        zoom: draftZoom,
                        onDrag: (delta, size) {
                          if (size.width <= 0 || size.height <= 0) return;
                          update(
                            x: draftX + (delta.dx / size.width) * 2.9,
                            y: draftY - (delta.dy / size.height) * 2.9,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.zoom_out_rounded,
                            color: kTextMuted,
                            size: 20,
                          ),
                          Expanded(
                            child: Slider(
                              value: draftZoom,
                              min: 1,
                              max: 2.4,
                              activeColor: BrandTheme.redTop,
                              inactiveColor: kBorderColor,
                              onChanged: updateZoom,
                            ),
                          ),
                          const Icon(
                            Icons.zoom_in_rounded,
                            color: kTextMuted,
                            size: 20,
                          ),
                        ],
                      ),
                      Text(
                        isRussian
                            ? 'Передвиньте фото внутри кадра'
                            : 'Drag the photo inside the frame',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: BrandPillButton(
                              label: isRussian ? 'СБРОСИТЬ' : 'RESET',
                              style: BrandPillStyle.light,
                              onTap: () {
                                update(x: 0, y: -0.72);
                                updateZoom(1);
                              },
                            ),
                          ),
                          const SizedBox(width: kGap10),
                          Expanded(
                            child: BrandPillButton(
                              label: isRussian ? 'ГОТОВО' : 'DONE',
                              style: BrandPillStyle.dark,
                              onTap: () => Navigator.of(sheetContext).pop(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _changePhotoCategory(
    int index, {
    required bool isPicked,
    required String category,
  }) {
    setState(() {
      if (isPicked) {
        if (index < 0 || index >= _pickedPhotoCategoryLabels.length) return;
        _pickedPhotoCategoryLabels[index] = category;
      } else {
        if (index < 0 || index >= _photoCategoryLabels.length) return;
        _photoCategoryLabels[index] = category;
      }
    });
  }

  void _changeVideoCategory(
    int index, {
    required bool isPicked,
    required String category,
  }) {
    setState(() {
      if (isPicked) {
        if (index < 0 || index >= _pickedVideoCategoryLabels.length) return;
        _pickedVideoCategoryLabels[index] = category;
      } else {
        if (index < 0 || index >= _videoCategoryLabels.length) return;
        _videoCategoryLabels[index] = category;
      }
    });
  }

  void _makeShowreelVideoAt(int index, {required bool isPicked}) {
    setState(() {
      if (isPicked) {
        if (index < 0 || index >= _pickedVideos.length) return;
        if (_pickedShowreelVideoIndex == index) {
          _pickedShowreelVideoIndex = null;
          if (index < _pickedVideoCategoryLabels.length) {
            _pickedVideoCategoryLabels[index] = 'Видео';
          }
          return;
        }
        if (_pickedShowreelVideoIndex != null &&
            _pickedShowreelVideoIndex! >= 0 &&
            _pickedShowreelVideoIndex! < _pickedVideoCategoryLabels.length) {
          _pickedVideoCategoryLabels[_pickedShowreelVideoIndex!] = 'Видео';
        }
        _pickedShowreelVideoIndex = index;
        if (index < _pickedVideoCategoryLabels.length) {
          _pickedVideoCategoryLabels[index] = 'Showreel';
        }
      } else {
        if (index < 0 || index >= _videoUrls.length) return;
        final selectedUrl = _videoUrls[index].trim();
        if (_showreelUrl.trim() == selectedUrl) {
          _showreelUrl = '';
          _showreelPreviewUrl = '';
          if (index < _videoCategoryLabels.length) {
            _videoCategoryLabels[index] = 'Видео';
          }
          return;
        }
        for (var i = 0; i < _videoCategoryLabels.length; i++) {
          if (_videoCategoryLabels[i].trim() == 'Showreel') {
            _videoCategoryLabels[i] = 'Видео';
          }
        }
        _showreelUrl = _videoUrls[index].trim();
        _showreelPreviewUrl = index < _videoPreviewUrls.length
            ? _videoPreviewUrls[index].trim()
            : '';
        _pendingShowreelUrl = '';
        _pendingShowreelPreviewUrl = '';
        _pickedShowreelVideoIndex = null;
        if (index < _videoCategoryLabels.length) {
          _videoCategoryLabels[index] = 'Showreel';
        }
      }
    });
  }

  String _birthDateFieldLabel(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ru'
      ? 'Дата рождения'
      : 'Birth date';

  Widget _buildDesktopIdentitySection(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row2(
          left: _Field(label: t.profileSurname, controller: _surnameC),
          right: _Field(label: t.profileName, controller: _nameC),
        ),
      ],
    );
  }

  Widget _buildDesktopPhysicalSection(AppLocalizations t) {
    if (!_usesPhysicalBasics) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kGap16),
        _SectionTitle(t.profilePhysicalDetailsUpper),
        const SizedBox(height: kGap10),
        _Row2(
          left: _Field(
            label: _birthDateFieldLabel(context),
            controller: _birthDateC,
            readOnly: true,
            onTap: _pickBirthDate,
          ),
          right: _Field(
            label: t.profileHeightCm,
            controller: _heightC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopModelMeasurementsSection(AppLocalizations t) {
    if (!_usesModelMeasurements) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kGap12),
        _Row2(
          left: _Field(
            label: t.profileBustCm,
            controller: _bustC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          right: _Field(
            label: t.profileWaistCm,
            controller: _waistC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(height: kGap12),
        _Row2(
          left: _Field(
            label: t.profileHipsCm,
            controller: _hipsC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          right: _Field(
            label: t.profileShoeSize,
            controller: _shoeSizeC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(height: kGap12),
        _Row2(
          left: SearchableChoiceField(
            label: t.profileEyeColor,
            controller: _eyeColorC,
            options: eyeColorOptions,
          ),
          right: SearchableChoiceField(
            label: t.profileHairColor,
            controller: _hairColorC,
            options: hairColorOptions,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLocationSection(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kGap12),
        _Row2(
          left: SearchableChoiceField(
            label: t.profileCountry,
            controller: _countryC,
            options: _countryOptions,
            onChanged: _onCountryChanged,
          ),
          right: SearchableChoiceField(
            label: t.profileCity,
            controller: _cityC,
            options: _cityOptions,
            enabled: _countryC.text.trim().isNotEmpty,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopProfessionalSection(AppLocalizations t) {
    if (!_hasProfessionalInfoRole) return const SizedBox.shrink();
    final professionalType = _professionalFieldsType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kGap16),
        _SectionTitle(t.profileProfessionalInfoUpper),
        const SizedBox(height: kGap10),
        _Field(
          label: _professionalExperienceLabel(t, professionalType),
          controller: _experienceC,
          maxLines: 4,
        ),
        const SizedBox(height: kGap12),
        _Row2(
          left: _Field(
            label: _professionalSkillsLabel(t, professionalType),
            controller: _skillsC,
            maxLines: 3,
          ),
          right: _Field(
            label: _professionalServicesLabel(t, professionalType),
            controller: _servicesC,
            maxLines: 3,
          ),
        ),
        const SizedBox(height: kGap12),
        _Row2(
          left: _Field(
            label: _professionalGenresLabel(t, professionalType),
            controller: _genresC,
            maxLines: 3,
          ),
          right:
              _hasProfileRole(ProfessionalProfileType.photographer) ||
                  _hasProfileRole(ProfessionalProfileType.videographer)
              ? _Field(
                  label: t.profileEquipment,
                  controller: _equipmentC,
                  maxLines: 3,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDesktopRatesSection(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kGap16),
        _Row2(
          left: _Field(
            label: t.profileMinHourlyRate,
            controller: _minHourlyRateC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          right: _Field(
            label: t.profileMinDailyFee,
            controller: _minDailyFeeC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaBlock(AppLocalizations t, {bool desktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(t.profileMediaUpper),
        const SizedBox(height: kGap10),
        _MediaBlock(
          desktop: desktop,
          uploading: false,
          onAddPhoto: _pickPhotos,
          onAddVideo: _pickVideo,
          photoUrls: _photoUrls,
          photoCategoryLabels: _photoCategoryLabels,
          coverPhotoUrl: _coverPhotoUrl,
          coverPhotoFocalX: _coverPhotoFocalX,
          coverPhotoFocalY: _coverPhotoFocalY,
          videoUrls: _videoUrls,
          videoPreviewUrls: _videoPreviewUrls,
          videoCategoryLabels: _videoCategoryLabels,
          showreelUrl: _showreelUrl,
          pendingPhotoUrls: _pendingPhotoUrls,
          pendingPhotoCategoryLabels: _pendingPhotoCategoryLabels,
          pendingCoverPhotoUrl: _pendingCoverPhotoUrl,
          pendingCoverPhotoFocalX: _pendingCoverPhotoFocalX,
          pendingCoverPhotoFocalY: _pendingCoverPhotoFocalY,
          pendingVideoUrls: _pendingVideoUrls,
          pendingVideoPreviewUrls: _pendingVideoPreviewUrls,
          pendingVideoCategoryLabels: _pendingVideoCategoryLabels,
          pendingShowreelUrl: _pendingShowreelUrl,
          pickedPhotos: _pickedPhotos,
          pickedPhotoCategoryLabels: _pickedPhotoCategoryLabels,
          pickedCoverPhotoIndex: _pickedCoverPhotoIndex,
          pickedVideos: _pickedVideos,
          pickedVideoCategoryLabels: _pickedVideoCategoryLabels,
          pickedShowreelVideoIndex: _pickedShowreelVideoIndex,
          onRemovePhoto: _removePhotoAt,
          onRemoveVideo: _removeVideoAt,
          onMakeCoverPhoto: _makeCoverPhotoAt,
          onEditCoverFrame: _editCoverFrame,
          onMakeShowreelVideo: _makeShowreelVideoAt,
          onChangePhotoCategory: _changePhotoCategory,
          onChangeVideoCategory: _changeVideoCategory,
        ),
      ],
    );
  }

  Widget _buildDesktopActions(
    AppLocalizations t,
    MyProfileState base, {
    required bool isAdmin,
    required bool showDelete,
  }) {
    final actions = <Widget>[];

    void addButton({
      required String label,
      required BrandPillStyle style,
      required VoidCallback? onTap,
    }) {
      if (actions.isNotEmpty) actions.add(const SizedBox(height: kGap10));
      actions.add(
        SizedBox(
          width: double.infinity,
          height: BrandTheme.pillHeight,
          child: BrandPillButton(label: label, style: style, onTap: onTap),
        ),
      );
    }

    if (isAdmin) {
      addButton(
        label: t.profileSaveUpper,
        style: BrandPillStyle.dark,
        onTap: _isBusy ? null : () => _saveAdminProfile(base),
      );
      if (showDelete) {
        addButton(
          label: t.profileDeleteUpper,
          style: BrandPillStyle.light,
          onTap: _isBusy ? null : () => _delete(base),
        );
      }
    } else if (widget.startBlank) {
      addButton(
        label: t.profileSubmitUpper,
        style: BrandPillStyle.light,
        onTap: _isBusy ? null : () => _submitNew(base),
      );
    } else {
      addButton(
        label: t.profileSaveUpper,
        style: BrandPillStyle.dark,
        onTap: _isBusy ? null : () => _saveExistingProfile(base),
      );
      addButton(
        label: t.profileSubmitUpper,
        style: BrandPillStyle.light,
        onTap: _isBusy ? null : () => _submitExistingProfile(base),
      );
      if (showDelete) {
        addButton(
          label: t.profileDeleteUpper,
          style: BrandPillStyle.light,
          onTap: _isBusy ? null : () => _delete(base),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: actions,
    );
  }

  Widget _buildDesktopEditor(
    AppLocalizations t,
    MyProfileState base, {
    required bool isAdmin,
    required bool showDelete,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.profileTitleUpper,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: kTextDark,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: kGap14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: kProfileErrorTextStyle,
                      ),
                    ],
                    const SizedBox(height: kGap16),
                    _buildDesktopIdentitySection(t),
                    _buildDesktopPhysicalSection(t),
                    _buildDesktopModelMeasurementsSection(t),
                    _buildDesktopLocationSection(t),
                    _buildDesktopProfessionalSection(t),
                    _buildDesktopRatesSection(t),
                    const SizedBox(height: kGap16),
                    _SectionTitle(t.profileResumeUpper),
                    const SizedBox(height: kGap10),
                    _Field(
                      label: t.profileAboutHint,
                      controller: _resumeC,
                      maxLines: 7,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kGap16),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(t.profileCalendarUpper),
                    const SizedBox(height: kGap10),
                    BrandCalendar(
                      selectionMode: BrandCalendarSelectionMode.multiple,
                      selectedDates: _unavailableDays,
                      allowPastDates: false,
                      allowPreviousMonths: false,
                      onDateToggled: _toggleUnavailableDay,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: _kProfileEditDesktopSideWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileQualityCard(quality: _profileQuality()),
                    const SizedBox(height: kGap16),
                    _ProfileRolesSelector(
                      selected: _profileRoles,
                      onChanged: _setProfileRoles,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kGap16),
              _Card(child: _buildMediaBlock(t, desktop: true)),
              const SizedBox(height: kGap16),
              _Card(
                child: _buildDesktopActions(
                  t,
                  base,
                  isAdmin: isAdmin,
                  showDelete: showDelete,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final base = _resolveBaseProfile();

    _initFromState(base);
    final showDelete = !widget.startBlank && base.id.trim().isNotEmpty;
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop =
                    constraints.maxWidth >= _kProfileEditDesktopBreakpoint;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop
                          ? _kProfileEditDesktopMaxWidth
                          : double.infinity,
                    ),
                    child: ListView(
                      padding: isDesktop
                          ? _kProfileEditDesktopPad
                          : kMyProfileEditPagePad,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Padding(
                              padding: kProfileBackButtonPad,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 22,
                                color: kTextDark,
                              ),
                            ),
                          ),
                        ),

                        if (!widget.startBlank) ...[
                          _Header(
                            status: base.status,
                            comment: base.moderationComment,
                          ),
                          const SizedBox(height: kGap14),
                        ],

                        if (isDesktop)
                          _buildDesktopEditor(
                            t,
                            base,
                            isAdmin: isAdmin,
                            showDelete: showDelete,
                          )
                        else
                          _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  t.profileTitleUpper,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                    color: kTextDark,
                                  ),
                                ),
                                const SizedBox(height: kGap16),

                                _ProfileQualityCard(quality: _profileQuality()),
                                const SizedBox(height: kGap16),

                                _ProfileRolesSelector(
                                  selected: _profileRoles,
                                  onChanged: _setProfileRoles,
                                ),
                                const SizedBox(height: kGap16),

                                if (_error != null) ...[
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: kProfileErrorTextStyle,
                                  ),
                                  const SizedBox(height: kGap12),
                                ],

                                _Row2(
                                  left: _Field(
                                    label: t.profileSurname,
                                    controller: _surnameC,
                                  ),
                                  right: _Field(
                                    label: t.profileName,
                                    controller: _nameC,
                                  ),
                                ),
                                const SizedBox(height: kGap12),

                                if (_usesPhysicalBasics) ...[
                                  _SectionTitle(t.profilePhysicalDetailsUpper),
                                  const SizedBox(height: kGap10),
                                  _Row2(
                                    left: _Field(
                                      label:
                                          Localizations.localeOf(
                                                context,
                                              ).languageCode.toLowerCase() ==
                                              'ru'
                                          ? 'Дата рождения'
                                          : 'Birth date',
                                      controller: _birthDateC,
                                      readOnly: true,
                                      onTap: _pickBirthDate,
                                    ),
                                    right: _Field(
                                      label: t.profileHeightCm,
                                      controller: _heightC,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: kGap12),
                                ],

                                if (_usesModelMeasurements) ...[
                                  _Row2(
                                    left: _Field(
                                      label: t.profileBustCm,
                                      controller: _bustC,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                    right: _Field(
                                      label: t.profileWaistCm,
                                      controller: _waistC,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: kGap12),

                                  _Row2(
                                    left: _Field(
                                      label: t.profileHipsCm,
                                      controller: _hipsC,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                    right: _Field(
                                      label: t.profileShoeSize,
                                      controller: _shoeSizeC,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: kGap12),

                                  _Row2(
                                    left: SearchableChoiceField(
                                      label: t.profileEyeColor,
                                      controller: _eyeColorC,
                                      options: eyeColorOptions,
                                    ),
                                    right: SearchableChoiceField(
                                      label: t.profileHairColor,
                                      controller: _hairColorC,
                                      options: hairColorOptions,
                                    ),
                                  ),
                                  const SizedBox(height: kGap12),
                                ],

                                _Row2(
                                  left: SearchableChoiceField(
                                    label: t.profileCountry,
                                    controller: _countryC,
                                    options: _countryOptions,
                                    onChanged: _onCountryChanged,
                                  ),
                                  right: SearchableChoiceField(
                                    label: t.profileCity,
                                    controller: _cityC,
                                    options: _cityOptions,
                                    enabled: _countryC.text.trim().isNotEmpty,
                                  ),
                                ),
                                const SizedBox(height: kGap12),

                                if (_hasProfessionalInfoRole) ...[
                                  const SizedBox(height: kGap4),
                                  _SectionTitle(t.profileProfessionalInfoUpper),
                                  const SizedBox(height: kGap10),
                                  _Field(
                                    label: _professionalExperienceLabel(
                                      t,
                                      _professionalFieldsType,
                                    ),
                                    controller: _experienceC,
                                    maxLines: 4,
                                  ),
                                  const SizedBox(height: kGap12),
                                  _Field(
                                    label: _professionalSkillsLabel(
                                      t,
                                      _professionalFieldsType,
                                    ),
                                    controller: _skillsC,
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: kGap12),
                                  _Field(
                                    label: _professionalServicesLabel(
                                      t,
                                      _professionalFieldsType,
                                    ),
                                    controller: _servicesC,
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: kGap12),
                                  _Field(
                                    label: _professionalGenresLabel(
                                      t,
                                      _professionalFieldsType,
                                    ),
                                    controller: _genresC,
                                    maxLines: 3,
                                  ),
                                  if (_hasProfileRole(
                                        ProfessionalProfileType.photographer,
                                      ) ||
                                      _hasProfileRole(
                                        ProfessionalProfileType.videographer,
                                      )) ...[
                                    const SizedBox(height: kGap12),
                                    _Field(
                                      label: t.profileEquipment,
                                      controller: _equipmentC,
                                      maxLines: 3,
                                    ),
                                  ],
                                  const SizedBox(height: kGap12),
                                ],

                                _Row2(
                                  left: _Field(
                                    label: t.profileMinHourlyRate,
                                    controller: _minHourlyRateC,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                  right: _Field(
                                    label: t.profileMinDailyFee,
                                    controller: _minDailyFeeC,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                ),
                                const SizedBox(height: kGap12),
                                const SizedBox(height: kGap16),

                                _SectionTitle(t.profileMediaUpper),
                                const SizedBox(height: kGap10),
                                _MediaBlock(
                                  uploading: false,
                                  onAddPhoto: _pickPhotos,
                                  onAddVideo: _pickVideo,
                                  photoUrls: _photoUrls,
                                  photoCategoryLabels: _photoCategoryLabels,
                                  coverPhotoUrl: _coverPhotoUrl,
                                  coverPhotoFocalX: _coverPhotoFocalX,
                                  coverPhotoFocalY: _coverPhotoFocalY,
                                  videoUrls: _videoUrls,
                                  videoPreviewUrls: _videoPreviewUrls,
                                  videoCategoryLabels: _videoCategoryLabels,
                                  showreelUrl: _showreelUrl,
                                  pendingPhotoUrls: _pendingPhotoUrls,
                                  pendingPhotoCategoryLabels:
                                      _pendingPhotoCategoryLabels,
                                  pendingCoverPhotoUrl: _pendingCoverPhotoUrl,
                                  pendingCoverPhotoFocalX:
                                      _pendingCoverPhotoFocalX,
                                  pendingCoverPhotoFocalY:
                                      _pendingCoverPhotoFocalY,
                                  pendingVideoUrls: _pendingVideoUrls,
                                  pendingVideoPreviewUrls:
                                      _pendingVideoPreviewUrls,
                                  pendingVideoCategoryLabels:
                                      _pendingVideoCategoryLabels,
                                  pendingShowreelUrl: _pendingShowreelUrl,
                                  pickedPhotos: _pickedPhotos,
                                  pickedPhotoCategoryLabels:
                                      _pickedPhotoCategoryLabels,
                                  pickedCoverPhotoIndex: _pickedCoverPhotoIndex,
                                  pickedVideos: _pickedVideos,
                                  pickedVideoCategoryLabels:
                                      _pickedVideoCategoryLabels,
                                  pickedShowreelVideoIndex:
                                      _pickedShowreelVideoIndex,
                                  onRemovePhoto: _removePhotoAt,
                                  onRemoveVideo: _removeVideoAt,
                                  onMakeCoverPhoto: _makeCoverPhotoAt,
                                  onEditCoverFrame: _editCoverFrame,
                                  onMakeShowreelVideo: _makeShowreelVideoAt,
                                  onChangePhotoCategory: _changePhotoCategory,
                                  onChangeVideoCategory: _changeVideoCategory,
                                ),
                                const SizedBox(height: kGap16),

                                _SectionTitle(t.profileResumeUpper),
                                const SizedBox(height: kGap10),
                                _Field(
                                  label: t.profileAboutHint,
                                  controller: _resumeC,
                                  maxLines: 6,
                                ),

                                const SizedBox(height: kGap16),
                                _SectionTitle(t.profileCalendarUpper),
                                const SizedBox(height: kGap10),
                                BrandCalendar(
                                  selectionMode:
                                      BrandCalendarSelectionMode.multiple,
                                  selectedDates: _unavailableDays,
                                  allowPastDates: false,
                                  allowPreviousMonths: false,
                                  onDateToggled: _toggleUnavailableDay,
                                ),

                                const SizedBox(height: kGap14),

                                if (isAdmin) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: BrandTheme.pillHeight,
                                    child: BrandPillButton(
                                      label: t.profileSaveUpper,
                                      style: BrandPillStyle.dark,
                                      onTap: _isBusy
                                          ? null
                                          : () => _saveAdminProfile(base),
                                    ),
                                  ),
                                  if (showDelete) ...[
                                    const SizedBox(height: kGap10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: BrandTheme.pillHeight,
                                      child: BrandPillButton(
                                        label: t.profileDeleteUpper,
                                        style: BrandPillStyle.light,
                                        onTap: _isBusy
                                            ? null
                                            : () => _delete(base),
                                      ),
                                    ),
                                  ],
                                ] else if (widget.startBlank) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: BrandTheme.pillHeight,
                                    child: BrandPillButton(
                                      label: t.profileSubmitUpper,
                                      style: BrandPillStyle.light,
                                      onTap: _isBusy
                                          ? null
                                          : () => _submitNew(base),
                                    ),
                                  ),
                                ] else ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: BrandTheme.pillHeight,
                                    child: BrandPillButton(
                                      label: t.profileSaveUpper,
                                      style: BrandPillStyle.dark,
                                      onTap: _isBusy
                                          ? null
                                          : () => _saveExistingProfile(base),
                                    ),
                                  ),
                                  const SizedBox(height: kGap10),
                                  SizedBox(
                                    width: double.infinity,
                                    height: BrandTheme.pillHeight,
                                    child: BrandPillButton(
                                      label: t.profileSubmitUpper,
                                      style: BrandPillStyle.light,
                                      onTap: _isBusy
                                          ? null
                                          : () => _submitExistingProfile(base),
                                    ),
                                  ),
                                  if (showDelete) ...[
                                    const SizedBox(height: kGap10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: BrandTheme.pillHeight,
                                      child: BrandPillButton(
                                        label: t.profileDeleteUpper,
                                        style: BrandPillStyle.light,
                                        onTap: _isBusy
                                            ? null
                                            : () => _delete(base),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
