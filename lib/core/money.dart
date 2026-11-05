
String rupiah(int value) {
  final bool negative = value < 0;
  final String digits = value.abs().toString();

  final output = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      output.write('.');
    }

    output.write(digits[i]);
  }

  return '${negative ? '-' : ''}Rp${output.toString()}';
}

/// Mengubah tulisan nominal menjadi angka.
///
/// Contoh:
/// parseRupiah('Rp1.500.000') -> 1500000
/// parseRupiah('500.000')     -> 500000
/// parseRupiah('25000')       -> 25000
///
/// Fungsi ini digunakan untuk input nominal nonnegatif.
int parseRupiah(String text) {
  final String digits = text.replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );

  return int.tryParse(digits) ?? 0;
}
