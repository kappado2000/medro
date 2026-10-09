import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../tools/plan_doze.dart';

/// Titlul mic, albastru, al unui grup de campuri.
class TitluGrup extends StatelessWidget {
  final String text;
  const TitluGrup(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

/// Un rand care arata o data si deschide calendarul la atingere.
class RandData extends StatelessWidget {
  final String eticheta;
  final DateTime data;
  final ValueChanged<DateTime> onSchimbat;

  const RandData({
    super.key,
    required this.eticheta,
    required this.data,
    required this.onSchimbat,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.event, color: AppColors.blue),
      title: Text(
        eticheta,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      subtitle: Text(
        formatData(data),
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(Icons.edit_calendar, color: AppColors.muted),
      onTap: () async {
        final aleasa = await showDatePicker(
          context: context,
          initialDate: data,
          firstDate: DateTime(data.year - 3),
          lastDate: DateTime(data.year + 3),
        );
        if (aleasa != null) onSchimbat(aleasa);
      },
    );
  }
}

/// Camp numeric cu unitate, care accepta si virgula.
class CampValoare extends StatelessWidget {
  final String eticheta;
  final String unitate;
  final TextEditingController controller;
  final VoidCallback onSchimbat;
  final bool intreg;

  const CampValoare({
    super.key,
    required this.eticheta,
    required this.unitate,
    required this.controller,
    required this.onSchimbat,
    this.intreg = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: (_) => onSchimbat(),
        keyboardType: TextInputType.numberWithOptions(decimal: !intreg),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(intreg ? r'[0-9]' : r'[0-9.,]'),
          ),
        ],
        decoration: InputDecoration(
          labelText: eticheta,
          suffixText: unitate,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
      ),
    );
  }
}

double? citesteNumar(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(',', '.'));

class NotaInstrument extends StatelessWidget {
  final String text;
  const NotaInstrument(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12.5,
          height: 1.45,
        ),
      ),
    );
  }
}

Future<void> copiazaText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Copiat.')));
}

/// Buton lat pentru copierea rezultatului.
class ButonCopiaza extends StatelessWidget {
  final String text;
  const ButonCopiaza(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => copiazaText(context, text),
        icon: const Icon(Icons.copy, size: 18),
        label: const Text('Copiază'),
      ),
    );
  }
}
