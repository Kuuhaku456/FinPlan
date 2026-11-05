import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kProfileKey = 'finplan.profile.v1';

// =====================================================
// FOTO PROFIL
// =====================================================

String? _compressProfilePhoto(Uint8List bytes) {
  final original = img.decodeImage(bytes);

  if (original == null) return null;

  final oriented = img.bakeOrientation(original);

  final square = img.copyResizeCropSquare(
    oriented,
    size: 320,
    interpolation: img.Interpolation.linear,
  );

  return base64Encode(
    img.encodeJpg(square, quality: 78),
  );
}

Uint8List? _profilePhotoBytes(String value) {
  if (value.isEmpty) return null;

  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

// =====================================================
// MODEL PROFIL
// =====================================================

class FinPlanProfile {
  const FinPlanProfile({
    this.name = '',
    this.email = '',
    this.occupation = '',
    this.bio = '',
    this.emoji = '🌱',
    this.photoBase64 = '',
  });

  final String name;
  final String email;
  final String occupation;
  final String bio;
  final String emoji;
  final String photoBase64;

  String get displayName {
    return name.trim().isEmpty
        ? 'Pengguna FinPlan'
        : name;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'occupation': occupation,
      'bio': bio,
      'emoji': emoji,
      'photoBase64': photoBase64,
    };
  }

  factory FinPlanProfile.fromJson(
    Map<String, dynamic> json,
  ) {
    String read(
      String key, [
      String fallback = '',
    ]) {
      final value = json[key];

      return value is String ? value : fallback;
    }

    return FinPlanProfile(
      name: read('name'),
      email: read('email'),
      occupation: read('occupation'),
      bio: read('bio'),
      emoji: read('emoji', '🌱'),
      photoBase64: read('photoBase64'),
    );
  }
}

// =====================================================
// PENYIMPANAN PROFIL
// =====================================================

class ProfileStore {
  ProfileStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  Future<FinPlanProfile> load() async {
    try {
      final raw = await _preferences.getString(
        kProfileKey,
      );

      if (raw == null || raw.isEmpty) {
        return const FinPlanProfile();
      }

      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return FinPlanProfile.fromJson(decoded);
      }
    } catch (_) {
      // Jika data rusak, gunakan profil default.
    }

    return const FinPlanProfile();
  }

  Future<void> save(FinPlanProfile profile) {
    return _preferences.setString(
      kProfileKey,
      jsonEncode(profile.toJson()),
    );
  }
}

// =====================================================
// AVATAR PROFIL
// =====================================================

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.emoji,
    required this.photoBase64,
    required this.radius,
  });

  final String emoji;
  final String photoBase64;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = _profilePhotoBytes(photoBase64);

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(
        alpha: 0.18,
      ),
      child: ClipOval(
        child: bytes == null
            ? Center(
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: radius,
                  ),
                ),
              )
            : Image.memory(
                bytes,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Center(
                    child: Text(
                      emoji,
                      style: TextStyle(
                        fontSize: radius,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// =====================================================
// HALAMAN UTAMA PROFIL
// =====================================================

class FinPlanProfileTab extends StatelessWidget {
  const FinPlanProfileTab({
    super.key,
    required this.profile,
    required this.onEditProfile,
    required this.onOpenSettings,
  });

  final FinPlanProfile profile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        28,
      ),
      children: [
        Text(
          'Profil',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 16),

        // KARTU PROFIL

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF064E3B),
                Color(0xFF059669),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              _ProfileAvatar(
                emoji: profile.emoji,
                photoBase64: profile.photoBase64,
                radius: 32,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      profile.occupation.trim().isNotEmpty
                          ? profile.occupation
                          : 'Pengguna FinPlan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: onEditProfile,
                tooltip: 'Edit profil',
                style: IconButton.styleFrom(
                  backgroundColor:
                      Colors.white.withValues(
                    alpha: 0.16,
                  ),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        // JUDUL MENU

        Text(
          'Akun & Pengaturan',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 10),

        // MENU AKUN

        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      scheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                title: const Text(
                  'Informasi Profil',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                ),
                onTap: onEditProfile,
              ),

              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
              ),

              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      scheme.primaryContainer,
                  child: Icon(
                    Icons.settings_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                title: const Text(
                  'Pengaturan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                ),
                onTap: onOpenSettings,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // INFORMASI PRIVASI

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: scheme.onSurfaceVariant,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'Data profil tersimpan secara lokal '
                  'di perangkat ini.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
// HALAMAN EDIT PROFIL
// =====================================================

class FinPlanProfilePage extends StatefulWidget {
  const FinPlanProfilePage({
    super.key,
    required this.initialProfile,
    required this.onSave,
  });

  final FinPlanProfile initialProfile;

  final Future<void> Function(
    FinPlanProfile,
  ) onSave;

  @override
  State<FinPlanProfilePage> createState() {
    return _FinPlanProfilePageState();
  }
}

class _FinPlanProfilePageState
    extends State<FinPlanProfilePage> {
  static const _avatars = [
    '🌱',
    '😊',
    '😎',
    '👩',
    '👨',
    '🌻',
    '🚀',
    '💚',
    '🐼',
    '🦊',
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _occupation;
  late final TextEditingController _bio;

  late String _emoji;
  late String _photoBase64;

  final ImagePicker _picker = ImagePicker();

  bool _choosingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final profile = widget.initialProfile;

    _name = TextEditingController(
      text: profile.name,
    );

    _email = TextEditingController(
      text: profile.email,
    );

    _occupation = TextEditingController(
      text: profile.occupation,
    );

    _bio = TextEditingController(
      text: profile.bio,
    );

    _emoji = profile.emoji;
    _photoBase64 = profile.photoBase64;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _occupation.dispose();
    _bio.dispose();

    super.dispose();
  }

  // ===================================================
  // PILIH FOTO
  // ===================================================

  Future<void> _selectPhoto() async {
    if (_saving || _choosingPhoto) return;

    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _choosingPhoto = true;
      });

      final bytes = await photo.readAsBytes();

      if (bytes.lengthInBytes >
          15 * 1024 * 1024) {
        throw const FormatException(
          'Ukuran foto maksimal 15 MB.',
        );
      }

      final encoded = await compute(
        _compressProfilePhoto,
        bytes,
      );

      if (encoded == null) {
        throw const FormatException(
          'Format foto tidak didukung. '
          'Silakan pilih JPG atau PNG.',
        );
      }

      if (!mounted) return;

      setState(() {
        _photoBase64 = encoded;
      });
    } catch (error) {
      if (!mounted) return;

      final message = error is FormatException
          ? error.message
          : 'Gagal mengambil foto. Coba lagi.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _choosingPhoto = false;
        });
      }
    }
  }

  // ===================================================
  // SIMPAN PROFIL
  // ===================================================

  Future<void> _save() async {
    if (_saving ||
        _choosingPhoto ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final profile = FinPlanProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        occupation: _occupation.text.trim(),
        bio: _bio.text.trim(),
        emoji: _emoji,
        photoBase64: _photoBase64,
      );

      await widget.onSave(profile);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profil gagal disimpan. Coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ===================================================
  // TAMPILAN EDIT PROFIL
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profil',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              28,
            ),
            children: [
              // HEADER FOTO

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF064E3B),
                      Color(0xFF059669),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ProfileAvatar(
                          emoji: _emoji,
                          photoBase64:
                              _photoBase64,
                          radius: 46,
                        ),

                        Positioned(
                          right: -5,
                          bottom: -3,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder:
                                  const CircleBorder(),
                              onTap: _saving ||
                                      _choosingPhoto
                                  ? null
                                  : _selectPhoto,
                              child: const Padding(
                                padding:
                                    EdgeInsets.all(9),
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 20,
                                  color:
                                      Color(0xFF064E3B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      'Personalize Your Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // PILIH FOTO

              OutlinedButton.icon(
                onPressed:
                    _saving || _choosingPhoto
                        ? null
                        : _selectPhoto,
                icon: _choosingPhoto
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.photo_library_outlined,
                      ),
                label: Text(
                  _choosingPhoto
                      ? 'Memproses foto...'
                      : 'Pilih Foto',
                ),
              ),

              // HAPUS FOTO

              if (_photoBase64.isNotEmpty)
                TextButton.icon(
                  onPressed:
                      _saving || _choosingPhoto
                          ? null
                          : () {
                              setState(() {
                                _photoBase64 = '';
                              });
                            },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                  ),
                  label: const Text(
                    'Hapus Foto',
                  ),
                ),

              const SizedBox(height: 20),

              // AVATAR

              Text(
                'Pilih Avatar',
                style:
                    theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: _avatars.map((avatar) {
                  return ChoiceChip(
                    label: Text(
                      avatar,
                      style: const TextStyle(
                        fontSize: 22,
                      ),
                    ),
                    selected: _emoji == avatar,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _emoji = avatar;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // INFORMASI PERSONAL

              Text(
                'Informasi Personal',
                style:
                    theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 14),

              // NAMA

              TextFormField(
                controller: _name,
                textCapitalization:
                    TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                  ),
                ),
                validator: (text) {
                  if (text == null ||
                      text.trim().isEmpty) {
                    return 'Nama wajib diisi.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              // EMAIL

              TextFormField(
                controller: _email,
                keyboardType:
                    TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (Opsional)',
                  prefixIcon: Icon(
                    Icons.mail_outline_rounded,
                  ),
                ),
                validator: (text) {
                  final email = text?.trim() ?? '';

                  if (email.isEmpty) return null;

                  if (!RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch(email)) {
                    return 'Format email belum tepat.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              // PEKERJAAN

              TextFormField(
                controller: _occupation,
                textCapitalization:
                    TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Pekerjaan (Opsional)',
                  prefixIcon: Icon(
                    Icons.work_outline_rounded,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // BIO

              TextFormField(
                controller: _bio,
                maxLines: 3,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Tentang Saya',
                  hintText:
                      'Contoh: Menabung untuk rumah impian',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(
                    Icons.edit_note_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // PRIVASI

              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'Informasi profil disimpan '
                      'di perangkat ini.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // TOMBOL SIMPAN

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      _saving || _choosingPhoto
                          ? null
                          : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                        ),
                  label: Text(
                    _saving
                        ? 'Menyimpan...'
                        : 'Simpan Perubahan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}