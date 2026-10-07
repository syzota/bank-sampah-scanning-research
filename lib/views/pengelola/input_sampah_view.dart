import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/themes/app_colors.dart';
import '../../app/themes/app_text_styles.dart';
import '../../controllers/pengelola/input_sampah_controller.dart';
import '../../core/utils/format_helper.dart';
import '../../core/utils/validator.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/wave_painter.dart';
import 'widgets/input_sampah_widgets.dart';
import 'widgets/waste_scan_card.dart';

class InputSampahView extends StatefulWidget {
  const InputSampahView({super.key});

  @override
  State<InputSampahView> createState() => _InputSampahViewState();
}

class _InputSampahViewState extends State<InputSampahView> {
  final controller = Get.find<InputSampahController>();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    if (controller.isEditMode) {
      _currentStep = 0;
    }
  }

  bool _validateStep1({bool showSnackbar = false}) {
    if (controller.selectedKategoriId.value.isEmpty) {
      if (showSnackbar) {
        AppSnackbar.info(
          'Silakan pilih kategori sampah.',
          title: 'Kategori Kosong',
        );
      }
      return false;
    }
    if (controller.listSubKategori.isNotEmpty &&
        controller.selectedSubKategoriId.value.isEmpty) {
      if (showSnackbar) {
        AppSnackbar.info(
          'Silakan pilih sub kategori sampah.',
          title: 'Sub Kategori Kosong',
        );
      }
      return false;
    }
    if (controller.listTipe.isNotEmpty &&
        controller.selectedTipeId.value.isEmpty) {
      if (showSnackbar) {
        AppSnackbar.info('Silakan pilih tipe material.', title: 'Tipe Kosong');
      }
      return false;
    }
    if (controller.listJenisSampah.isNotEmpty &&
        controller.selectedJenisId.value.isEmpty) {
      if (showSnackbar) {
        AppSnackbar.info(
          'Silakan pilih jenis sampah.',
          title: 'Jenis Sampah Kosong',
        );
      }
      return false;
    }
    return true;
  }

  bool _validateStep2({bool showSnackbar = false}) {
    final nasabahText = controller.nasabahController.text.trim();
    if (nasabahText.isEmpty) {
      if (showSnackbar) {
        AppSnackbar.info(
          'Silakan isi nama nasabah.',
          title: 'Nama Nasabah Kosong',
        );
      }
      return false;
    }
    final jumlahText = controller.jumlahController.text.trim();
    final parseJumlah = double.tryParse(jumlahText.replaceAll(',', '.'));
    if (jumlahText.isEmpty || parseJumlah == null || parseJumlah <= 0) {
      if (showSnackbar) {
        AppSnackbar.info(
          'Masukkan jumlah sampah yang valid (lebih dari 0).',
          title: 'Jumlah Tidak Valid',
        );
      }
      return false;
    }
    if (controller.selectedSatuanId.value.isEmpty) {
      if (showSnackbar) {
        AppSnackbar.info(
          'Silakan tentukan satuan sampah.',
          title: 'Satuan Kosong',
        );
      }
      return false;
    }
    final hargaText = controller.hargaPerSatuanController.text.trim();
    final parseHarga = double.tryParse(hargaText.replaceAll(',', '.'));
    if (hargaText.isEmpty || parseHarga == null || parseHarga < 0) {
      if (showSnackbar) {
        AppSnackbar.info(
          'Masukkan harga per satuan yang valid.',
          title: 'Harga Tidak Valid',
        );
      }
      return false;
    }
    if (controller.selectedTanggal.value == null) {
      if (showSnackbar) {
        AppSnackbar.info(
          'Silakan pilih tanggal pengelolaan.',
          title: 'Tanggal Kosong',
        );
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: !controller.isScanBusy && !controller.isLoading.value,
        child: AbsorbPointer(
          absorbing: controller.isScanBusy || controller.isLoading.value,
          child: _buildScaffold(context),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildStepIndicator(),
            Expanded(
              child: Form(
                key: controller.formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (_currentStep == 0) ...[
                      WasteScanCard(controller: controller),
                      const SizedBox(height: 16),
                      SectionCard(
                        icon: Icons.category_outlined,
                        iconColor: AppColors.purple,
                        iconBg: AppColors.purpleLight,
                        accentColor: AppColors.purple,
                        title: 'Jenis Sampah',
                        child: Column(
                          children: [
                            Obx(
                              () => DropdownField<String>(
                                label: 'Kategori *',
                                hint: 'Pilih kategori',
                                value:
                                    controller.selectedKategoriId.value.isEmpty
                                    ? null
                                    : controller.selectedKategoriId.value,
                                items: controller.listKategori
                                    .map(
                                      (k) => DropdownMenuItem(
                                        value: k.id,
                                        child: Text(k.nama),
                                      ),
                                    )
                                    .toList(),
                                validator: (v) => AppValidator.required(
                                  v,
                                  fieldName: 'Kategori',
                                ),
                                onChanged: controller.onKategoriChanged,
                              ),
                            ),

                            Obx(() {
                              if (controller.selectedKategoriId.value.isEmpty ||
                                  controller.listSubKategori.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                children: [
                                  const SizedBox(height: 14),
                                  DropdownField<String>(
                                    label: 'Sub Kategori *',
                                    hint: 'Pilih sub kategori',
                                    value:
                                        controller
                                            .selectedSubKategoriId
                                            .value
                                            .isEmpty
                                        ? null
                                        : controller
                                              .selectedSubKategoriId
                                              .value,
                                    items: controller.listSubKategori
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(s.nama),
                                          ),
                                        )
                                        .toList(),
                                    validator: (v) => AppValidator.required(
                                      v,
                                      fieldName: 'Sub Kategori',
                                    ),
                                    onChanged: controller.onSubKategoriChanged,
                                  ),
                                ],
                              );
                            }),

                            Obx(() {
                              if (controller
                                      .selectedSubKategoriId
                                      .value
                                      .isEmpty ||
                                  controller.listTipe.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                children: [
                                  const SizedBox(height: 14),
                                  DropdownField<String>(
                                    label: 'Tipe *',
                                    hint: 'Pilih tipe material',
                                    value:
                                        controller.selectedTipeId.value.isEmpty
                                        ? null
                                        : controller.selectedTipeId.value,
                                    items: controller.listTipe
                                        .map(
                                          (t) => DropdownMenuItem(
                                            value: t.id,
                                            child: Text(t.nama),
                                          ),
                                        )
                                        .toList(),
                                    validator: (v) => AppValidator.required(
                                      v,
                                      fieldName: 'Tipe',
                                    ),
                                    onChanged: controller.onTipeChanged,
                                  ),
                                ],
                              );
                            }),

                            Obx(() {
                              if (controller.listJenisSampah.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              if (controller.listTipe.isNotEmpty &&
                                  controller.selectedTipeId.value.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                children: [
                                  const SizedBox(height: 14),
                                  DropdownField<String>(
                                    label: 'Jenis Sampah *',
                                    hint: 'Pilih jenis sampah',
                                    value:
                                        controller.selectedJenisId.value.isEmpty
                                        ? null
                                        : controller.selectedJenisId.value,
                                    items: controller.listJenisSampah
                                        .map(
                                          (j) => DropdownMenuItem(
                                            value: j.id,
                                            child: Text(j.nama),
                                          ),
                                        )
                                        .toList(),
                                    validator: (v) => AppValidator.required(
                                      v,
                                      fieldName: 'Jenis Sampah',
                                    ),
                                    onChanged: controller.onJenisChanged,
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ] else if (_currentStep == 1) ...[
                      SectionCard(
                        icon: Icons.person_outline_rounded,
                        iconColor: const Color(0xFF0D47A1),
                        iconBg: AppColors.kelurahanLight,
                        accentColor: AppColors.blueDeep,
                        title: 'Data Nasabah',
                        child: RawAutocomplete<String>(
                          textEditingController: controller.nasabahController,
                          focusNode: FocusNode(),
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            final currentText = textEditingValue.text.trim();
                            final matches = controller.listNamaNasabah.where((
                              String option,
                            ) {
                              return option.toLowerCase().contains(
                                currentText.toLowerCase(),
                              );
                            }).toList();

                            if (currentText.isNotEmpty &&
                                !controller.listNamaNasabah.contains(
                                  currentText,
                                )) {
                              matches.add('Tambah: "$currentText"');
                            }
                            return matches;
                          },
                          onSelected: (String selection) {
                            if (selection.startsWith('Tambah: "') &&
                                selection.endsWith('"')) {
                              final name = selection.substring(
                                9,
                                selection.length - 1,
                              );
                              controller.nasabahController.text = name;
                            } else {
                              controller.nasabahController.text = selection;
                            }
                          },
                          fieldViewBuilder:
                              (
                                BuildContext context,
                                TextEditingController textEditingController,
                                FocusNode focusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Roboto',
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Nasabah *',
                                    hintText: 'Ketik nama nasabah...',
                                    prefixIcon: Icon(
                                      Icons.person_search_rounded,
                                      size: 20,
                                      color: AppColors.outline,
                                    ),
                                  ),
                                  validator: (v) => AppValidator.required(
                                    v,
                                    fieldName: 'Nama nasabah',
                                  ),
                                );
                              },
                          optionsViewBuilder:
                              (
                                BuildContext context,
                                AutocompleteOnSelected<String> onSelected,
                                Iterable<String> options,
                              ) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white,
                                    child: Container(
                                      width: 320,
                                      constraints: const BoxConstraints(
                                        maxHeight: 200,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.outlineVariant
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                              final String option = options
                                                  .elementAt(index);
                                              return ListTile(
                                                title: Text(
                                                  option,
                                                  style: AppTextStyles.bodyMd,
                                                ),
                                                onTap: () => onSelected(option),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                );
                              },
                        ),
                      ),
                      const SizedBox(height: 14),

                      SectionCard(
                        icon: Icons.scale_outlined,
                        iconColor: AppColors.blueDeep,
                        iconBg: AppColors.kelurahanLight,
                        accentColor: AppColors.blueDeep,
                        title: 'Jumlah, Satuan & Harga',
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: AppTextField(
                                    controller: controller.jumlahController,
                                    label: 'Jumlah *',
                                    hint: 'Contoh: 12.5',
                                    prefixIcon: Icons.scale_outlined,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: AppValidator.jumlah,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Obx(
                                    () => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        DropdownField<String>(
                                          label: 'Satuan *',
                                          hint: 'Satuan',
                                          value:
                                              controller
                                                  .selectedSatuanId
                                                  .value
                                                  .isEmpty
                                              ? null
                                              : controller
                                                    .selectedSatuanId
                                                    .value,
                                          items: controller.listSatuan
                                              .map(
                                                (s) => DropdownMenuItem(
                                                  value: s.id,
                                                  child: Text(s.singkatan),
                                                ),
                                              )
                                              .toList(),
                                          validator: (v) =>
                                              AppValidator.required(
                                                v,
                                                fieldName: 'Satuan',
                                              ),
                                          onChanged: (v) =>
                                              controller
                                                      .selectedSatuanId
                                                      .value =
                                                  v ?? '',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: controller.hargaPerSatuanController,
                              label: 'Harga per Satuan (Rp) *',
                              hint: 'Masukkan harga per satuan...',
                              prefixIcon: Icons.attach_money_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: false,
                                  ),
                              inputFormatters: [
                                ThousandsSeparatorInputFormatter(),
                              ],
                              validator: AppValidator.harga,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      SectionCard(
                        icon: Icons.calendar_today_outlined,
                        iconColor: AppColors.teal,
                        iconBg: AppColors.tealLight,
                        accentColor: AppColors.teal,
                        title: 'Tanggal Pengelolaan',
                        child: Obx(
                          () => AppTextField(
                            controller: controller.tanggalController,
                            label: 'Tanggal *',
                            hint: 'Pilih tanggal',
                            prefixIcon: Icons.calendar_today_outlined,
                            readOnly: true,
                            onTap: () => controller.pickTanggal(context),
                            validator: (_) => AppValidator.tanggal(
                              controller.selectedTanggal.value,
                            ),
                            suffixIcon: controller.selectedTanggal.value != null
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: AppColors.outline,
                                      size: 18,
                                    ),
                                    onPressed: controller.clearTanggal,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      CollapsibleCatatanSection(controller: controller),
                    ] else ...[
                      Obx(() {
                        if (controller.hargaSnapshot.value == null) {
                          return const SizedBox.shrink();
                        }
                        return _buildHargaSnapshot();
                      }),

                      SummaryCard(controller: controller),
                    ],
                  ],
                ),
              ),
            ),

            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Stack(
      children: [
        CustomPaint(
          size: Size(MediaQuery.of(context).size.width, 210),
          painter: WavePainter.green(),
        ),
        Positioned(
          top: -15,
          right: -10,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Row(
            children: [
              if (canPop)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.isEditMode
                          ? 'Edit Data Sampah'
                          : 'Input Data Sampah',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.isEditMode
                          ? 'Perbarui data pengelolaan bank sampah'
                          : 'Tambah pencatatan pengelolaan baru',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  controller.isEditMode
                      ? Icons.edit_note_rounded
                      : Icons.add_circle_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step Indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepNode(0, 'Pilih Jenis', Icons.category_outlined),
          _buildStepLine(0),
          _buildStepNode(1, 'Isi Detail', Icons.edit_note_rounded),
          _buildStepLine(1),
          _buildStepNode(2, 'Konfirmasi', Icons.fact_check_outlined),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String label, IconData icon) {
    final isCompleted = _currentStep > index;
    final isActive = _currentStep == index;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: isCompleted || isActive
                  ? const LinearGradient(
                      colors: [AppColors.pengelolaMain, AppColors.secondary],
                    )
                  : null,
              color: isCompleted || isActive ? null : Colors.grey.shade50,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive || isCompleted
                    ? AppColors.pengelolaMain
                    : Colors.grey.shade200,
                width: 2,
              ),
              boxShadow: (isCompleted || isActive)
                  ? [
                      BoxShadow(
                        color: AppColors.pengelolaMain.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              size: 16,
              color: (isCompleted || isActive)
                  ? Colors.white
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive || isCompleted
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isActive
                  ? AppColors.pengelolaMain
                  : isCompleted
                  ? AppColors.textPrimary
                  : Colors.grey.shade400,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int index) {
    final isPassed = _currentStep > index;
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isPassed ? AppColors.pengelolaMain : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Bottom Action Bar ─────────────────────────────────────────────────────

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep == 0) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(
                      color: AppColors.pengelolaMain,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: GradientButton(
                  label: 'Selanjutnya',
                  icon: Icons.arrow_forward_rounded,
                  onTap: () {
                    if (_validateStep1(showSnackbar: true)) {
                      setState(() {
                        _currentStep = 1;
                      });
                    }
                  },
                ),
              ),
            ] else if (_currentStep == 1) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(
                      color: AppColors.pengelolaMain,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: GradientButton(
                  label: 'Selanjutnya',
                  icon: Icons.arrow_forward_rounded,
                  onTap: () {
                    if (_validateStep2(showSnackbar: true)) {
                      setState(() {
                        _currentStep = 2;
                      });
                    }
                  },
                ),
              ),
            ] else ...[
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(
                      color: AppColors.pengelolaMain,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Obx(() {
                  final isSaving = controller.isLoading.value;
                  return GradientButton(
                    label: controller.isEditMode ? 'Simpan' : 'Simpan Data',
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: isSaving,
                    onTap: isSaving ? null : controller.simpan,
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Harga Snapshot ────────────────────────────────────────────────────────

  Widget _buildHargaSnapshot() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border(
            top: BorderSide(color: AppColors.pengelolaMain, width: 2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.pengelolaMain.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.pengelolaLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sell_outlined,
                    color: AppColors.pengelolaMain,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Harga Terdaftar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Roboto',
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pengelolaLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${FormatHelper.currency(controller.hargaSnapshot.value!.hargaPerSatuan)} / ${controller.hargaSnapshot.value!.satuan?.singkatan ?? ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.pengelolaMain,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
            if (controller.jumlahController.text.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimasi Nilai Transaksi',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  Text(
                    FormatHelper.currency(
                      (double.tryParse(
                                controller.jumlahController.text.replaceAll(
                                  ',',
                                  '.',
                                ),
                              ) ??
                              0) *
                          controller.hargaSnapshot.value!.hargaPerSatuan,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
