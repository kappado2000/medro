import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/icd_provider.dart';
import '../providers/interactiuni_provider.dart';
import '../providers/medicamente_provider.dart';
import '../services/data_store.dart';
import '../theme/app_theme.dart';

/// Reincarca toate datele dupa ce [DataStore] a descarcat o versiune noua.
Future<void> reincarcaDatele(BuildContext context) async {
  final med = context.read<MedicamenteProvider>();
  final icd = context.read<IcdProvider>();
  final inter = context.read<InteractiuniProvider>();
  RcpStore.instance.goleste();
  await Future.wait([med.incarca(), icd.incarca(), inter.incarca()]);
}

/// Verifica o data pe zi, la pornire, daca exista date mai noi. Nu deranjeaza
/// utilizatorul decat daca s-a descarcat ceva.
Future<void> verificaActualizariZilnic(BuildContext context) async {
  const cheie = 'ultima_verificare_date';
  final prefs = await SharedPreferences.getInstance();
  final azi = DateTime.now().toIso8601String().substring(0, 10);
  if (prefs.getString(cheie) == azi) return;
  final stare = await DataStore.instance.actualizeaza();
  // o verificare esuata (fara internet) se reia la urmatoarea pornire
  if (stare.eroare == null) await prefs.setString(cheie, azi);
  if (!stare.actualizat || !context.mounted) return;
  await reincarcaDatele(context);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Datele au fost actualizate (${stare.versiune}).')),
  );
}

/// Fereastra cu versiunea datelor si butonul de verificare a actualizarilor.
Future<void> arataDateleAplicatiei(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _DateAplicatie(),
  );
}

class _DateAplicatie extends StatefulWidget {
  const _DateAplicatie();

  @override
  State<_DateAplicatie> createState() => _DateAplicatieState();
}

class _DateAplicatieState extends State<_DateAplicatie> {
  bool _verifica = false;
  String? _mesaj;
  bool _eroare = false;

  Future<void> _actualizeaza() async {
    setState(() {
      _verifica = true;
      _mesaj = null;
    });
    final stare = await DataStore.instance.actualizeaza();
    if (stare.actualizat && mounted) await reincarcaDatele(context);
    if (!mounted) return;
    setState(() {
      _verifica = false;
      _eroare = stare.eroare != null;
      _mesaj =
          stare.eroare ??
          (stare.actualizat
              ? 'Am descărcat ${stare.descarcate} fișiere noi. Datele sunt la zi.'
              : 'Datele sunt deja la zi.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final date = DataStore.instance;
    final med = context.watch<MedicamenteProvider>();
    final vechime = med.zileVechime();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datele aplicației',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date.versiune.isEmpty
                  ? 'Versiune necunoscută'
                  : 'Generate la ${date.versiune} (UTC)',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            for (final e in date.surse.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Text(
                      e.value,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (vechime != null) ...[
              const SizedBox(height: 8),
              Text(
                vechime > MedicamenteProvider.pragVechimeZile
                    ? 'Nomenclatorul are $vechime de zile. Verifică actualizările.'
                    : vechime <= 0
                    ? 'Nomenclatorul este de azi.'
                    : vechime == 1
                    ? 'Nomenclatorul este de ieri.'
                    : 'Nomenclatorul este de acum $vechime ${vechime % 100 >= 20 || vechime % 100 == 0 ? 'de zile' : 'zile'}.',
                style: TextStyle(
                  color: vechime > MedicamenteProvider.pragVechimeZile
                      ? AppColors.red
                      : AppColors.muted,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _verifica ? null : _actualizeaza,
                icon: _verifica
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  _verifica ? 'Se verifică…' : 'Verifică actualizările',
                ),
              ),
            ),
            if (_mesaj != null) ...[
              const SizedBox(height: 10),
              Text(
                _mesaj!,
                style: TextStyle(
                  color: _eroare ? AppColors.red : AppColors.ink,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Aplicația caută singură date noi o dată pe zi, la pornire, dacă există '
              'conexiune la internet.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
