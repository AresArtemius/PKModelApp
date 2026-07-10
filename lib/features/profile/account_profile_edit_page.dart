import 'dart:async';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account_profile_service.dart';
import '../../core/auth_providers.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../auth/auth_controller.dart';
import '../auth/password_strength.dart';

const String _kAccountAvatarBucket = 'profile-media';

TextStyle _accountEditCommandStyle({
  Color color = kTextDark,
  double size = 16,
  double spacing = 1.4,
  FontWeight weight = FontWeight.w600,
}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
  );
}

TextStyle _accountEditBodyStyle({
  Color color = kTextMuted,
  double size = 15,
  double spacing = 0.2,
  FontWeight weight = FontWeight.w600,
  double height = 1.22,
}) {
  return TextStyle(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
    height: height,
  );
}

class _PhoneCountryCode {
  const _PhoneCountryCode(this.label, this.code);

  final String label;
  final String code;
}

const _phoneCodes = [
  _PhoneCountryCode('RU +7', '+7'),
  _PhoneCountryCode('US +1', '+1'),
  _PhoneCountryCode('GB +44', '+44'),
  _PhoneCountryCode('DE +49', '+49'),
  _PhoneCountryCode('FR +33', '+33'),
  _PhoneCountryCode('IT +39', '+39'),
  _PhoneCountryCode('ES +34', '+34'),
  _PhoneCountryCode('AE +971', '+971'),
  _PhoneCountryCode('TR +90', '+90'),
  _PhoneCountryCode('PL +48', '+48'),
  _PhoneCountryCode('GE +995', '+995'),
  _PhoneCountryCode('AM +374', '+374'),
  _PhoneCountryCode('UA +380', '+380'),
  _PhoneCountryCode('BY +375', '+375'),
  _PhoneCountryCode('IL +972', '+972'),
];

class AccountProfileEditPage extends ConsumerStatefulWidget {
  const AccountProfileEditPage({super.key});

  @override
  ConsumerState<AccountProfileEditPage> createState() =>
      _AccountProfileEditPageState();
}

class _AccountProfileEditPageState
    extends ConsumerState<AccountProfileEditPage> {
  final _fullNameC = TextEditingController();
  final _companyC = TextEditingController();
  final _positionC = TextEditingController();
  final _accountTagC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneNumberC = TextEditingController();
  final _cityC = TextEditingController();
  final _countryC = TextEditingController();
  final _websiteC = TextEditingController();
  final _socialC = TextEditingController();
  final _bioC = TextEditingController();
  final _phoneOtpC = TextEditingController();

  bool _hydrated = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _linkingEmail = false;
  bool _linkingPhone = false;
  bool _changingPassword = false;
  bool _requestingMerge = false;
  bool _phoneOtpSent = false;
  int _phoneResendSeconds = 0;
  String _phoneCode = '+7';
  String _avatarUrl = '';
  String _pendingPhone = '';
  String _phoneConflictPhone = '';
  String _lastConfirmedEmail = '';
  String _lastConfirmedPhone = '';
  AccountTagVisibility _accountTagVisibility = AccountTagVisibility.public;
  String? _error;
  Timer? _phoneResendTimer;
  final _picker = ImagePicker();

  SupabaseClient get _sb => ref.read(supabaseProvider);

  bool get _isRussian {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
  }

  @override
  void dispose() {
    _fullNameC.dispose();
    _companyC.dispose();
    _positionC.dispose();
    _accountTagC.dispose();
    _emailC.dispose();
    _phoneNumberC.dispose();
    _cityC.dispose();
    _countryC.dispose();
    _websiteC.dispose();
    _socialC.dispose();
    _bioC.dispose();
    _phoneOtpC.dispose();
    _phoneResendTimer?.cancel();
    super.dispose();
  }

  void _hydrate(AccountOwnerProfile profile) {
    if (_hydrated) return;
    _hydrated = true;
    _fullNameC.text = profile.fullName;
    _companyC.text = profile.companyName;
    _positionC.text = profile.position;
    _accountTagC.text = profile.normalizedAccountTag;
    _accountTagVisibility = profile.accountTagVisibility;
    _emailC.text = profile.email;
    _lastConfirmedEmail = profile.email;
    _avatarUrl = profile.avatarUrl;
    final splitPhone = _splitPhone(profile.phone);
    _phoneCode = splitPhone.code;
    _phoneNumberC.text = splitPhone.number;
    _lastConfirmedPhone = profile.phone;
    _cityC.text = profile.city;
    _countryC.text = profile.country;
    _websiteC.text = profile.website;
    _socialC.text = profile.socialUrl;
    _bioC.text = profile.bio;
  }

  Future<void> _save() async {
    if (_saving || _uploadingAvatar) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final profile = AccountOwnerProfile(
      email: _confirmedEmailForSave(user),
      phone: _confirmedPhoneForSave(user),
      accountTag: _accountTagC.text,
      accountTagVisibility: _accountTagVisibility,
      avatarUrl: _avatarUrl,
      fullName: _fullNameC.text,
      companyName: _companyC.text,
      position: _positionC.text,
      city: _cityC.text,
      country: _countryC.text,
      website: _websiteC.text,
      socialUrl: _socialC.text,
      bio: _bioC.text,
    );

    if (!profile.hasMinimumForRequest) {
      setState(() {
        _error = _isRussian
            ? 'Заполните имя и email или телефон.'
            : 'Fill in your name and email or phone.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(accountProfileServiceProvider)
          .saveOwnerProfile(user, profile);
      ref.invalidate(accountOwnerProfileProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().toLowerCase();
      final tagTaken =
          message.contains('user_profiles_account_tag_lower_idx') ||
          (message.contains('duplicate') && message.contains('account_tag'));
      setState(() {
        _error = tagTaken
            ? (_isRussian
                  ? 'Этот тэг аккаунта уже занят.'
                  : 'This account tag is already taken.')
            : (_isRussian
                  ? 'Не удалось сохранить профиль аккаунта.\n$e'
                  : 'Could not save account profile.\n$e');
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _confirmedEmailForSave(User user) {
    final authEmail = user.email?.trim() ?? '';
    if (authEmail.isNotEmpty) return authEmail;
    return _lastConfirmedEmail.trim();
  }

  String _confirmedPhoneForSave(User user) {
    final authPhone = user.phone?.trim() ?? '';
    if (authPhone.isNotEmpty) return authPhone;
    return _lastConfirmedPhone.trim();
  }

  Future<void> _linkEmailForLogin() async {
    if (_saving || _uploadingAvatar || _linkingEmail) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = _isRussian
            ? 'Введите email, который будет использоваться для входа.'
            : 'Enter the email you want to use for sign-in.';
      });
      return;
    }

    final password = await _askPassword(
      title: _isRussian ? 'Пароль для email' : 'Email password',
      actionLabel: _isRussian ? 'ПРИВЯЗАТЬ' : 'LINK',
      email: email,
    );
    if (password == null) return;
    final passwordMessage = newPasswordValidationMessage(
      password,
      isRussian: _isRussian,
      email: email,
      phone: _confirmedPhoneForSave(user),
    );
    if (passwordMessage != null) {
      setState(() {
        _error = passwordMessage;
      });
      return;
    }

    setState(() {
      _linkingEmail = true;
      _error = null;
    });

    try {
      await _sb.auth.updateUser(
        UserAttributes(email: email, password: password),
        emailRedirectTo: AuthController.authRedirectTo,
      );
      final updatedUser = _sb.auth.currentUser ?? user;
      await ref
          .read(accountProfileServiceProvider)
          .saveOwnerProfile(
            updatedUser,
            AccountOwnerProfile(
              email: _confirmedEmailForSave(updatedUser),
              phone: _confirmedPhoneForSave(updatedUser),
              accountTag: _accountTagC.text,
              accountTagVisibility: _accountTagVisibility,
              avatarUrl: _avatarUrl,
              fullName: _fullNameC.text,
              companyName: _companyC.text,
              position: _positionC.text,
              city: _cityC.text,
              country: _countryC.text,
              website: _websiteC.text,
              socialUrl: _socialC.text,
              bio: _bioC.text,
            ),
          );
      ref.invalidate(accountOwnerProfileProvider);
      if (!mounted) return;
      setState(() {
        _error = _isRussian
            ? 'Письмо подтверждения отправлено. После подтверждения можно будет входить по email и телефону.'
            : 'Confirmation email sent. After confirmation, you can sign in with email and phone.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isRussian
            ? 'Не удалось привязать email. Возможно, он уже используется другим аккаунтом.\n$e'
            : 'Could not link email. It may already be used by another account.\n$e';
      });
    } finally {
      if (mounted) setState(() => _linkingEmail = false);
    }
  }

  Future<void> _changePasswordForLogin() async {
    if (_saving ||
        _uploadingAvatar ||
        _linkingEmail ||
        _linkingPhone ||
        _changingPassword) {
      return;
    }
    final password = await _askPassword(
      title: _isRussian ? 'Пароль для входа' : 'Sign-in password',
      actionLabel: _isRussian ? 'СОХРАНИТЬ' : 'SAVE',
      email: ref.read(currentUserProvider) == null
          ? null
          : _confirmedEmailForSave(ref.read(currentUserProvider)!),
      phone: ref.read(currentUserProvider) == null
          ? null
          : _confirmedPhoneForSave(ref.read(currentUserProvider)!),
    );
    if (password == null) return;
    final user = ref.read(currentUserProvider);
    final passwordMessage = newPasswordValidationMessage(
      password,
      isRussian: _isRussian,
      email: user == null ? null : _confirmedEmailForSave(user),
      phone: user == null ? null : _confirmedPhoneForSave(user),
    );
    if (passwordMessage != null) {
      setState(() {
        _error = passwordMessage;
      });
      return;
    }

    setState(() {
      _changingPassword = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider)
          .setCurrentUserPassword(password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isRussian
                  ? 'Пароль для входа обновлен.'
                  : 'Sign-in password has been updated.',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isRussian
            ? 'Не удалось обновить пароль.\n$e'
            : 'Could not update password.\n$e';
      });
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _resetPendingPhoneLink() {
    if (!_phoneOtpSent && _pendingPhone.isEmpty && _phoneOtpC.text.isEmpty) {
      return;
    }
    _phoneResendTimer?.cancel();
    setState(() {
      _phoneOtpSent = false;
      _pendingPhone = '';
      _phoneResendSeconds = 0;
      _phoneOtpC.clear();
    });
  }

  void _startPhoneResendTimer() {
    _phoneResendTimer?.cancel();
    setState(() => _phoneResendSeconds = 60);
    _phoneResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_phoneResendSeconds <= 1) {
        timer.cancel();
        setState(() => _phoneResendSeconds = 0);
        return;
      }
      setState(() => _phoneResendSeconds--);
    });
  }

  Future<void> _sendPhoneLinkCode({bool resend = false}) async {
    if (_saving ||
        _uploadingAvatar ||
        _linkingEmail ||
        _linkingPhone ||
        _requestingMerge) {
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final phone = _composePhone();
    if (phone.isEmpty) {
      setState(() {
        _error = _isRussian
            ? 'Введите телефон, который будет использоваться для входа.'
            : 'Enter the phone number you want to use for sign-in.';
      });
      return;
    }
    if (_phoneDigits(phone) == _phoneDigits(_lastConfirmedPhone)) {
      setState(() {
        _error = _isRussian
            ? 'Этот номер уже указан в аккаунте.'
            : 'This phone is already set on the account.';
      });
      return;
    }

    setState(() {
      _linkingPhone = true;
      _error = null;
      _phoneConflictPhone = '';
    });

    try {
      await ref.read(authControllerProvider).linkPhoneForLogin(phone: phone);
      if (!mounted) return;
      _phoneOtpC.clear();
      _startPhoneResendTimer();
      setState(() {
        _phoneOtpSent = true;
        _pendingPhone = phone;
        _error = resend
            ? (_isRussian
                  ? 'Код отправлен повторно.'
                  : 'The code has been sent again.')
            : (_isRussian
                  ? 'Код отправлен. Введите его ниже.'
                  : 'The code has been sent. Enter it below.');
      });
    } catch (e) {
      if (!mounted) return;
      if (_isPhoneAlreadyRegistered(e)) {
        setState(() {
          _phoneConflictPhone = phone;
          _error = _isRussian
              ? 'Этот номер уже используется другим аккаунтом. Если это ваш второй аккаунт, отправьте заявку на объединение. Если на другом аккаунте уже есть другая почта, объединение должен проверить админ.'
              : 'This phone number is already used by another account. If it is your second account, request an account merge. If the other account has a different email, an admin must review it.';
        });
        return;
      }
      setState(() {
        _error = _isRussian
            ? 'Не удалось отправить код. Возможно, номер уже используется другим аккаунтом.\n$e'
            : 'Could not send the code. The number may already be used by another account.\n$e';
      });
    } finally {
      if (mounted) setState(() => _linkingPhone = false);
    }
  }

  bool _isPhoneAlreadyRegistered(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('phone_exists') ||
        text.contains('phone number has already been registered') ||
        text.contains('already been registered');
  }

  Future<void> _requestAccountMerge() async {
    if (_saving ||
        _uploadingAvatar ||
        _linkingEmail ||
        _linkingPhone ||
        _requestingMerge) {
      return;
    }
    final user = ref.read(currentUserProvider);
    final phone = _phoneConflictPhone.trim();
    if (user == null || phone.isEmpty) return;

    setState(() {
      _requestingMerge = true;
      _error = null;
    });

    try {
      await ref
          .read(accountProfileServiceProvider)
          .requestAccountMerge(
            user: user,
            requestedPhone: phone,
            profile: AccountOwnerProfile(
              email: _confirmedEmailForSave(user),
              phone: _confirmedPhoneForSave(user),
              accountTag: _accountTagC.text,
              accountTagVisibility: _accountTagVisibility,
              avatarUrl: _avatarUrl,
              fullName: _fullNameC.text,
              companyName: _companyC.text,
              position: _positionC.text,
              city: _cityC.text,
              country: _countryC.text,
              website: _websiteC.text,
              socialUrl: _socialC.text,
              bio: _bioC.text,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isRussian
                  ? 'Объединение с номером $phone запрошено.'
                  : 'Merge with $phone has been requested.',
            ),
          ),
        );
      setState(() {
        _error = _isRussian
            ? 'Заявка на объединение отправлена. Мы проверим, что оба способа входа принадлежат вам.'
            : 'Merge request sent. We will verify that both sign-in methods belong to you.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isRussian
            ? 'Не удалось отправить заявку. Проверьте, что SQL account_merge_requests.sql применен в Supabase.\n$e'
            : 'Could not send the request. Check that account_merge_requests.sql has been applied in Supabase.\n$e';
      });
    } finally {
      if (mounted) setState(() => _requestingMerge = false);
    }
  }

  Future<void> _confirmPhoneLinkCode() async {
    if (_saving || _uploadingAvatar || _linkingEmail || _linkingPhone) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final phone = _pendingPhone.isNotEmpty ? _pendingPhone : _composePhone();
    final code = _phoneOtpC.text.trim();
    if (phone.isEmpty || code.isEmpty) {
      setState(() {
        _error = _isRussian ? 'Введите код из SMS.' : 'Enter the SMS code.';
      });
      return;
    }

    setState(() {
      _linkingPhone = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .verifyPhoneForLogin(phone: phone, token: code);

      final updatedUser = _sb.auth.currentUser ?? user;
      await ref
          .read(accountProfileServiceProvider)
          .saveOwnerProfile(
            updatedUser,
            AccountOwnerProfile(
              email: _confirmedEmailForSave(updatedUser),
              phone: phone,
              accountTag: _accountTagC.text,
              accountTagVisibility: _accountTagVisibility,
              avatarUrl: _avatarUrl,
              fullName: _fullNameC.text,
              companyName: _companyC.text,
              position: _positionC.text,
              city: _cityC.text,
              country: _countryC.text,
              website: _websiteC.text,
              socialUrl: _socialC.text,
              bio: _bioC.text,
            ),
          );
      ref.invalidate(accountOwnerProfileProvider);
      ref.invalidate(currentUserProvider);
      if (!mounted) return;
      _phoneResendTimer?.cancel();
      setState(() {
        _lastConfirmedPhone = phone;
        _phoneOtpSent = false;
        _pendingPhone = '';
        _phoneResendSeconds = 0;
        _phoneOtpC.clear();
        _error = _isRussian
            ? 'Телефон привязан. Теперь можно входить по SMS и email.'
            : 'Phone linked. You can now sign in with SMS and email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isRussian
            ? 'Не удалось привязать телефон. Возможно, номер уже используется другим аккаунтом.\n$e'
            : 'Could not link phone. It may already be used by another account.\n$e';
      });
    } finally {
      if (mounted) setState(() => _linkingPhone = false);
    }
  }

  Future<String?> _askPassword({
    required String title,
    required String actionLabel,
    String? email,
    String? phone,
  }) async {
    final controller = TextEditingController();
    var obscure = true;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: kDialogInsetPad,
          child: Container(
            padding: kLoginCardPad,
            decoration: catalogDialogDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: _accountEditCommandStyle(
                    size: 22,
                    spacing: 2.1,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: kGap16),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration:
                      profileFieldDecoration(
                        label: _isRussian ? 'Пароль' : 'Password',
                      ).copyWith(
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility,
                          ),
                        ),
                      ),
                ),
                const SizedBox(height: kGap10),
                PasswordStrengthMeter(
                  password: controller.text,
                  isRussian: _isRussian,
                  email: email,
                  phone: phone,
                  compact: true,
                ),
                const SizedBox(height: kGap16),
                Row(
                  children: [
                    Expanded(
                      child: BrandPillButton(
                        label: _isRussian ? 'ОТМЕНА' : 'CANCEL',
                        style: BrandPillStyle.light,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: kGap12),
                    Expanded(
                      child: BrandPillButton(
                        label: actionLabel.toUpperCase(),
                        style: BrandPillStyle.dark,
                        onTap: () => Navigator.of(context).pop(controller.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    return result?.trim();
  }

  ({String code, String number}) _splitPhone(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) return (code: '+7', number: '');
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (!text.startsWith('+') && digitsOnly.length == 11) {
      if (digitsOnly.startsWith('7') || digitsOnly.startsWith('8')) {
        return (code: '+7', number: digitsOnly.substring(1));
      }
    }
    final sortedCodes =
        _phoneCodes.map((e) => e.code).toSet().toList(growable: false)
          ..sort((a, b) => b.length.compareTo(a.length));
    for (final code in sortedCodes) {
      if (text.startsWith(code)) {
        return (code: code, number: text.substring(code.length));
      }
    }
    if (text.startsWith('8') && text.length > 1) {
      return (code: '+7', number: text.substring(1));
    }
    return (code: '+7', number: text.replaceAll(RegExp(r'^\+'), ''));
  }

  String _composePhone() {
    final number = _phoneNumberC.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.isEmpty) return '';
    return '$_phoneCode$number';
  }

  String _phoneDigits(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _contentType(String ext) {
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar || _saving) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1400,
    );
    if (image == null) return;
    final originalBytes = await image.readAsBytes();
    if (!mounted) return;

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AvatarCropPage(bytes: originalBytes),
      ),
    );
    if (croppedBytes == null || croppedBytes.isEmpty || !mounted) return;

    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      const ext = 'png';
      final path =
          '${user.id}/account_avatar/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _sb.storage
          .from(_kAccountAvatarBucket)
          .uploadBinary(
            path,
            croppedBytes,
            fileOptions: FileOptions(
              contentType: _contentType(ext),
              upsert: true,
            ),
          );
      final url = _sb.storage.from(_kAccountAvatarBucket).getPublicUrl(path);
      final profile = AccountOwnerProfile(
        email: _confirmedEmailForSave(user),
        phone: _confirmedPhoneForSave(user),
        accountTag: _accountTagC.text,
        accountTagVisibility: _accountTagVisibility,
        avatarUrl: url,
        fullName: _fullNameC.text,
        companyName: _companyC.text,
        position: _positionC.text,
        city: _cityC.text,
        country: _countryC.text,
        website: _websiteC.text,
        socialUrl: _socialC.text,
        bio: _bioC.text,
      );
      await ref
          .read(accountProfileServiceProvider)
          .saveOwnerProfile(user, profile);
      ref.invalidate(accountOwnerProfileProvider);
      if (mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isRussian
            ? 'Не удалось загрузить фото профиля.\n$e'
            : 'Could not upload profile photo.\n$e';
      });
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(accountOwnerProfileProvider);
    final title = _isRussian ? 'ПРОФИЛЬ АККАУНТА' : 'ACCOUNT PROFILE';

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: kProfileErrorPad,
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: _accountEditBodyStyle(
                      color: kTextDanger,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              data: (profile) {
                _hydrate(profile);
                return ListView(
                  padding: kMyProfilePagePad,
                  children: [
                    BrandAdminHeader(
                      title: title,
                      onBack: _saving
                          ? () {}
                          : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(height: kGap14),
                    Container(
                      padding: kLoginCardPad,
                      decoration: catalogCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: _accountEditBodyStyle(
                                color: kTextDanger,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: kGap12),
                          ],
                          _AvatarPicker(
                            avatarUrl: _avatarUrl,
                            uploading: _uploadingAvatar,
                            label: _isRussian
                                ? 'Фото профиля'
                                : 'Profile photo',
                            actionLabel: _isRussian
                                ? 'ВЫБРАТЬ ФОТО'
                                : 'CHOOSE PHOTO',
                            onTap: _pickAvatar,
                          ),
                          const SizedBox(height: kGap16),
                          _field(_fullNameC, _isRussian ? 'Имя / ФИО' : 'Name'),
                          _field(
                            _companyC,
                            _isRussian ? 'Компания / агентство' : 'Company',
                          ),
                          _field(
                            _positionC,
                            _isRussian ? 'Должность' : 'Position',
                          ),
                          _field(
                            _accountTagC,
                            _isRussian
                                ? 'Тэг аккаунта, например @artemkukhar'
                                : 'Account tag, e.g. @artemkukhar',
                            prefixText: '@',
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9._-]'),
                              ),
                              LengthLimitingTextInputFormatter(32),
                            ],
                          ),
                          const SizedBox(height: kGap8),
                          _AccountTagVisibilityPicker(
                            value: _accountTagVisibility,
                            isRussian: _isRussian,
                            onChanged: (value) =>
                                setState(() => _accountTagVisibility = value),
                          ),
                          const SizedBox(height: kGap12),
                          _EmailRecoveryHintCard(
                            user: ref.watch(currentUserProvider),
                            isRussian: _isRussian,
                          ),
                          _field(_emailC, 'Email'),
                          _EmailLoginLinkCard(
                            user: ref.watch(currentUserProvider),
                            emailController: _emailC,
                            isRussian: _isRussian,
                            busy: _saving || _uploadingAvatar || _linkingEmail,
                            linking: _linkingEmail,
                            onLink: _linkEmailForLogin,
                          ),
                          const SizedBox(height: kGap12),
                          _phoneField(),
                          _PhoneLoginLinkCard(
                            user: ref.watch(currentUserProvider),
                            savedPhone: _lastConfirmedPhone,
                            composedPhone: _composePhone(),
                            pendingPhone: _pendingPhone,
                            otpController: _phoneOtpC,
                            otpSent: _phoneOtpSent,
                            resendSeconds: _phoneResendSeconds,
                            conflictPhone: _phoneConflictPhone,
                            isRussian: _isRussian,
                            busy:
                                _saving ||
                                _uploadingAvatar ||
                                _linkingEmail ||
                                _linkingPhone ||
                                _requestingMerge,
                            linking: _linkingPhone,
                            requestingMerge: _requestingMerge,
                            onSendCode: () => _sendPhoneLinkCode(),
                            onConfirmCode: _confirmPhoneLinkCode,
                            onResendCode: _phoneResendSeconds == 0
                                ? () => _sendPhoneLinkCode(resend: true)
                                : null,
                            onRequestMerge: _requestAccountMerge,
                          ),
                          const SizedBox(height: kGap12),
                          _PasswordLoginCard(
                            isRussian: _isRussian,
                            busy:
                                _saving ||
                                _uploadingAvatar ||
                                _linkingEmail ||
                                _linkingPhone ||
                                _changingPassword,
                            changing: _changingPassword,
                            onChange: _changePasswordForLogin,
                          ),
                          const SizedBox(height: kGap12),
                          _field(_cityC, _isRussian ? 'Город' : 'City'),
                          _field(_countryC, _isRussian ? 'Страна' : 'Country'),
                          _field(_websiteC, _isRussian ? 'Сайт' : 'Website'),
                          _field(_socialC, 'Instagram / Telegram / WhatsApp'),
                          _field(
                            _bioC,
                            _isRussian ? 'О себе' : 'About',
                            maxLines: 4,
                          ),
                          const SizedBox(height: kGap16),
                          SizedBox(
                            height: kRegisterButtonH,
                            child: BrandPillButton(
                              label: _saving
                                  ? (_isRussian ? '...' : '...')
                                  : (_isRussian ? 'СОХРАНИТЬ' : 'SAVE'),
                              style: BrandPillStyle.dark,
                              onTap: (_saving || _uploadingAvatar)
                                  ? null
                                  : _save,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kGap12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        decoration: profileFieldDecoration(
          label: label,
        ).copyWith(prefixText: prefixText),
      ),
    );
  }

  Widget _phoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: kGap12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: DropdownButtonFormField<String>(
              initialValue: _phoneCode,
              isExpanded: true,
              decoration: profileFieldDecoration(
                label: _isRussian ? 'Код' : 'Code',
              ),
              items: [
                for (final item in _phoneCodes)
                  DropdownMenuItem(
                    value: item.code,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving || _uploadingAvatar
                  ? null
                  : (value) {
                      if (value == null) return;
                      if (value != _phoneCode) {
                        setState(() => _phoneCode = value);
                        _resetPendingPhoneLink();
                        if (_phoneConflictPhone.isNotEmpty) {
                          setState(() => _phoneConflictPhone = '');
                        }
                      }
                    },
            ),
          ),
          const SizedBox(width: kGap10),
          Expanded(
            child: TextField(
              controller: _phoneNumberC,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                if (_phoneOtpSent && _composePhone() != _pendingPhone) {
                  _resetPendingPhoneLink();
                }
                if (_phoneConflictPhone.isNotEmpty) {
                  setState(() => _phoneConflictPhone = '');
                }
              },
              decoration: profileFieldDecoration(
                label: _isRussian ? 'Телефон' : 'Phone',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTagVisibilityPicker extends StatelessWidget {
  const _AccountTagVisibilityPicker({
    required this.value,
    required this.isRussian,
    required this.onChanged,
  });

  final AccountTagVisibility value;
  final bool isRussian;
  final ValueChanged<AccountTagVisibility> onChanged;

  String _label(AccountTagVisibility visibility) {
    return switch (visibility) {
      AccountTagVisibility.public => isRussian ? 'Всем' : 'Everyone',
      AccountTagVisibility.conversations => isRussian ? 'Диалогам' : 'Chats',
      AccountTagVisibility.hidden => isRussian ? 'Скрыть' : 'Hide',
    };
  }

  String _description(AccountTagVisibility visibility) {
    return switch (visibility) {
      AccountTagVisibility.public =>
        isRussian
            ? 'Tag виден в каталоге и будущей публичной карточке.'
            : 'Tag is visible in catalog and future public profile.',
      AccountTagVisibility.conversations =>
        isRussian
            ? 'Tag видят только участники ваших диалогов.'
            : 'Only people in your chats can see the tag.',
      AccountTagVisibility.hidden =>
        isRussian
            ? 'Tag сохранен, но не показывается другим пользователям.'
            : 'Tag is saved but hidden from other users.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: kGap12),
      padding: const EdgeInsets.all(12),
      decoration: pillDecoration(
        isDark: false,
        radius: kCardRadius,
      ).copyWith(border: Border.all(color: kBorderColor, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRussian ? 'Кто видит @tag' : 'Who can see @tag',
            style: _accountEditCommandStyle(
              size: 13,
              spacing: 0.9,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in AccountTagVisibility.values)
                _AccountTagVisibilityPill(
                  label: _label(option),
                  selected: value == option,
                  onTap: () => onChanged(option),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            _description(value),
            style: _accountEditBodyStyle(size: 12, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _AccountTagVisibilityPill extends StatelessWidget {
  const _AccountTagVisibilityPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: pillDecoration(isDark: selected, radius: 999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: _accountEditCommandStyle(
                color: selected ? Colors.white : kTextDark,
                size: 12,
                spacing: 0.6,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailLoginLinkCard extends StatelessWidget {
  const _EmailLoginLinkCard({
    required this.user,
    required this.emailController,
    required this.isRussian,
    required this.busy,
    required this.linking,
    required this.onLink,
  });

  final User? user;
  final TextEditingController emailController;
  final bool isRussian;
  final bool busy;
  final bool linking;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final authEmail = user?.email?.trim() ?? '';
    final confirmed = user?.emailConfirmedAt?.trim().isNotEmpty ?? false;
    final hasAuthEmail = authEmail.isNotEmpty;
    final title = hasAuthEmail
        ? (isRussian ? 'Email для входа' : 'Sign-in email')
        : (isRussian ? 'Привязать email для входа' : 'Link sign-in email');
    final subtitle = hasAuthEmail
        ? confirmed
              ? authEmail
              : (isRussian
                    ? '$authEmail. Ожидает подтверждения'
                    : '$authEmail. Waiting for confirmation')
        : (isRussian
              ? 'После подтверждения можно будет входить по телефону и email.'
              : 'After confirmation, you can sign in with phone and email.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _accountEditCommandStyle(
              size: 15,
              spacing: 0.8,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: _accountEditBodyStyle()),
          if (!hasAuthEmail || !confirmed) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: BrandPillButton(
                label: linking
                    ? '...'
                    : (isRussian ? 'ПРИВЯЗАТЬ EMAIL' : 'LINK EMAIL'),
                style: BrandPillStyle.light,
                onTap: busy ? null : onLink,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmailRecoveryHintCard extends StatelessWidget {
  const _EmailRecoveryHintCard({required this.user, required this.isRussian});

  final User? user;
  final bool isRussian;

  @override
  Widget build(BuildContext context) {
    final isPhoneAccount = user?.phone?.trim().isNotEmpty ?? false;
    final hasEmail = user?.email?.trim().isNotEmpty ?? false;
    if (!isPhoneAccount || hasEmail) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: kGap12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: pillDecoration(isDark: false, radius: kCardRadius).copyWith(
          border: Border.all(color: BrandTheme.redTop.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.alternate_email_rounded,
              color: BrandTheme.redTop,
              size: 22,
            ),
            const SizedBox(width: kGap10),
            Expanded(
              child: Text(
                isRussian
                    ? 'Добавьте email, чтобы восстановить доступ к аккаунту и входить не только по SMS.'
                    : 'Add email to recover account access and sign in without SMS.',
                style: _accountEditBodyStyle(weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneLoginLinkCard extends StatelessWidget {
  const _PhoneLoginLinkCard({
    required this.user,
    required this.savedPhone,
    required this.composedPhone,
    required this.pendingPhone,
    required this.otpController,
    required this.otpSent,
    required this.resendSeconds,
    required this.conflictPhone,
    required this.isRussian,
    required this.busy,
    required this.linking,
    required this.requestingMerge,
    required this.onSendCode,
    required this.onConfirmCode,
    required this.onResendCode,
    required this.onRequestMerge,
  });

  final User? user;
  final String savedPhone;
  final String composedPhone;
  final String pendingPhone;
  final TextEditingController otpController;
  final bool otpSent;
  final int resendSeconds;
  final String conflictPhone;
  final bool isRussian;
  final bool busy;
  final bool linking;
  final bool requestingMerge;
  final VoidCallback onSendCode;
  final VoidCallback onConfirmCode;
  final VoidCallback? onResendCode;
  final VoidCallback onRequestMerge;

  @override
  Widget build(BuildContext context) {
    final authPhone = user?.phone?.trim() ?? '';
    final confirmedPhone = authPhone.isNotEmpty ? authPhone : savedPhone.trim();
    final phoneConfirmed = confirmedPhone.isNotEmpty;
    final hasDraftPhone = composedPhone.trim().isNotEmpty;
    final samePhone =
        _phoneDigits(confirmedPhone) == _phoneDigits(composedPhone);
    final targetPhone = pendingPhone.isNotEmpty ? pendingPhone : composedPhone;
    final hasConflict = conflictPhone.trim().isNotEmpty;
    final title = phoneConfirmed
        ? (isRussian ? 'Телефон для входа' : 'Sign-in phone')
        : (isRussian ? 'Привязать телефон для входа' : 'Link sign-in phone');
    final subtitle = phoneConfirmed
        ? (samePhone || !hasDraftPhone
              ? confirmedPhone
              : (isRussian
                    ? '$confirmedPhone. Чтобы сменить номер, подтвердите новый.'
                    : '$confirmedPhone. Confirm the new number to change it.'))
        : (otpSent
              ? (isRussian
                    ? 'Код отправлен на $targetPhone. Введите его ниже.'
                    : 'The code was sent to $targetPhone. Enter it below.')
              : hasDraftPhone
              ? (isRussian
                    ? 'На $composedPhone придёт SMS-код.'
                    : 'An SMS code will be sent to $composedPhone.')
              : (isRussian
                    ? 'Введите номер выше и подтвердите его по SMS.'
                    : 'Enter a number above and confirm it by SMS.'));
    final showButton =
        !hasConflict && (!phoneConfirmed || (hasDraftPhone && !samePhone));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _accountEditCommandStyle(
              size: 15,
              spacing: 0.8,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: _accountEditBodyStyle()),
          if (hasConflict) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: pillDecoration(isDark: false, radius: 22).copyWith(
                border: Border.all(
                  color: BrandTheme.redTop.withValues(alpha: 0.42),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.link_rounded,
                    color: BrandTheme.redTop,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRussian
                          ? 'Номер $conflictPhone уже привязан к другому аккаунту. Можно отправить заявку на объединение, но если там другая почта, решение примет админ.'
                          : '$conflictPhone is already linked to another account. You can request a merge, but if it has another email, an admin will review it.',
                      style: _accountEditBodyStyle(weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: BrandPillButton(
                label: requestingMerge
                    ? '...'
                    : (isRussian ? 'ЗАПРОСИТЬ ОБЪЕДИНЕНИЕ' : 'REQUEST MERGE'),
                style: BrandPillStyle.dark,
                onTap: busy ? null : onRequestMerge,
              ),
            ),
          ],
          if (showButton) ...[
            const SizedBox(height: 12),
            if (otpSent) ...[
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: 4,
                ),
                decoration: profileFieldDecoration(
                  label: isRussian ? 'Код из SMS' : 'SMS code',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: BrandPillButton(
                  label: linking
                      ? '...'
                      : (isRussian ? 'ПОДТВЕРДИТЬ КОД' : 'CONFIRM CODE'),
                  style: BrandPillStyle.dark,
                  onTap: busy ? null : onConfirmCode,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: busy ? null : onResendCode,
                  child: Text(
                    resendSeconds > 0
                        ? (isRussian
                              ? 'ПОВТОРНО ЧЕРЕЗ $resendSeconds'
                              : 'RESEND IN $resendSeconds')
                        : (isRussian ? 'ОТПРАВИТЬ ЕЩЕ РАЗ' : 'SEND AGAIN'),
                    style: TextStyle(
                      color: resendSeconds > 0 ? kTextMuted : BrandTheme.redTop,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ] else
              SizedBox(
                height: 42,
                child: BrandPillButton(
                  label: linking
                      ? '...'
                      : (phoneConfirmed
                            ? (isRussian ? 'СМЕНИТЬ ТЕЛЕФОН' : 'CHANGE PHONE')
                            : (isRussian ? 'ПРИВЯЗАТЬ ТЕЛЕФОН' : 'LINK PHONE')),
                  style: BrandPillStyle.light,
                  onTap: busy ? null : onSendCode,
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _phoneDigits(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

class _PasswordLoginCard extends StatelessWidget {
  const _PasswordLoginCard({
    required this.isRussian,
    required this.busy,
    required this.changing,
    required this.onChange,
  });

  final bool isRussian;
  final bool busy;
  final bool changing;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRussian ? 'Пароль для входа' : 'Sign-in password',
            style: _accountEditCommandStyle(
              size: 15,
              spacing: 0.8,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isRussian
                ? 'Используется для входа по email или телефону. SMS остается для регистрации и смены номера.'
                : 'Used for email or phone sign-in. SMS remains for sign-up and phone changes.',
            style: _accountEditBodyStyle(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: BrandPillButton(
              label: changing
                  ? '...'
                  : (isRussian ? 'СМЕНИТЬ ПАРОЛЬ' : 'CHANGE PASSWORD'),
              style: BrandPillStyle.light,
              onTap: busy ? null : onChange,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.avatarUrl,
    required this.uploading,
    required this.label,
    required this.actionLabel,
    required this.onTap,
  });

  final String avatarUrl;
  final bool uploading;
  final String label;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: uploading ? null : onTap,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: kTextDark,
              borderRadius: BorderRadius.circular(28),
              boxShadow: BrandTheme.basePillShadow(isDark: true),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (avatarUrl.trim().isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 220,
                    maxWidthDiskCache: 440,
                    errorWidget: (_, _, _) => const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  )
                else
                  const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                if (uploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: kGap14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: _accountEditCommandStyle(
                  size: 18,
                  spacing: 0.8,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: kGap8),
              SizedBox(
                height: 44,
                child: BrandPillButton(
                  label: uploading ? '...' : actionLabel,
                  style: BrandPillStyle.light,
                  onTap: uploading ? null : onTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarCropPage extends StatefulWidget {
  const _AvatarCropPage({required this.bytes});

  final Uint8List bytes;

  @override
  State<_AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<_AvatarCropPage> {
  final _boundaryKey = GlobalKey();
  final _controller = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted || data == null) return;
      Navigator.of(context).pop(data.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      isRussian ? 'ФОТО ПРОФИЛЯ' : 'PROFILE PHOTO',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: Container(
                          color: kTextDark,
                          child: InteractiveViewer(
                            transformationController: _controller,
                            minScale: 1,
                            maxScale: 5,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: Image.memory(
                              widget.bytes,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isRussian
                        ? 'Приблизьте и сдвиньте фото, чтобы лицо было в кадре.'
                        : 'Zoom and move the photo to frame the face.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: BrandTheme.pillHeight,
                    child: BrandPillButton(
                      label: _saving
                          ? '...'
                          : (isRussian ? 'СОХРАНИТЬ КАДР' : 'SAVE FRAME'),
                      style: BrandPillStyle.light,
                      onTap: _saving ? null : _confirm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
