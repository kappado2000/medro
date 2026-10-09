import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calculators/calculator.dart';
import '../help/ajutor.dart';
import '../theme/app_theme.dart';

class CalculatorScreen extends StatefulWidget {
  final Calculator calculator;
  const CalculatorScreen({super.key, required this.calculator});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final Map<String, Object> _valori = {};
  final Map<String, TextEditingController> _controllere = {};

  @override
  void initState() {
    super.initState();
    for (final c in widget.calculator.campuri) {
      if (c is CampNumar) _controllere[c.id] = TextEditingController();
    }
    _aplicaImplicite();
  }

  void _aplicaImplicite() {
    for (final c in widget.calculator.campuri) {
      if (c is CampAlegere && c.implicit != null) _valori[c.id] = c.implicit!;
    }
  }

  @override
  void dispose() {
    for (final c in _controllere.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _reseteaza() {
    for (final c in _controllere.values) {
      c.clear();
    }
    setState(() {
      _valori.clear();
      _aplicaImplicite();
    });
  }

  void _seteazaNumar(String id, String text) {
    final v = double.tryParse(text.replaceAll(',', '.'));
    setState(() {
      if (v == null) {
        _valori.remove(id);
      } else {
        _valori[id] = v;
      }
    });
  }

  /// Unitatea creatininei depinde de alegerea facuta in campul "unitate".
  String _unitate(CampNumar c) {
    if (c.unitate.isNotEmpty) return c.unitate;
    return _valori['unitate'] == 1 ? 'µmol/l' : 'mg/dl';
  }

  @override
  Widget build(BuildContext context) {
    final calc = widget.calculator;
    final rezultat = calc.calculeaza(_valori);
    return Scaffold(
      appBar: AppBar(
        title: Text(calc.titlu),
        actions: [
          const ButonAjutor(ajutorCalculatoare),
          IconButton(
            tooltip: 'Resetează',
            icon: const Icon(Icons.refresh),
            onPressed: _reseteaza,
          ),
        ],
      ),
      // rezultatul ramane vizibil in timp ce se deruleaza un chestionar lung
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _RezultatCard(rezultat),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, c) in calc.campuri.indexed) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16),
                          _buildCamp(c),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Sursă: ${calc.sursa}\n\nInstrument orientativ. Nu înlocuiește judecata clinică.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCamp(Camp c) {
    switch (c) {
      case CampNumar():
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.eticheta,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      _unitate(c),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _controllere[c.id],
                  onChanged: (t) => _seteazaNumar(c.id, t),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case CampAlegere():
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.eticheta,
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
              ),
              if (c.detaliu != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    c.detaliu!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, optiune) in c.optiuni.indexed)
                    ChoiceChip(
                      label: Text(
                        c.puncte == null
                            ? optiune
                            : '$optiune  ·  ${c.puncte![i]}',
                      ),
                      selected: _valori[c.id] == i,
                      showCheckmark: false,
                      selectedColor: AppColors.blue,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _valori[c.id] == i
                            ? AppColors.blue
                            : AppColors.line,
                      ),
                      labelStyle: TextStyle(
                        color: _valori[c.id] == i
                            ? Colors.white
                            : AppColors.ink,
                      ),
                      onSelected: (_) => setState(() => _valori[c.id] = i),
                    ),
                ],
              ),
            ],
          ),
        );
      case CampScala():
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.eticheta,
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
              ),
              if (c.detaliu != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    c.detaliu!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = c.minim; i <= c.maxim; i++)
                    ChoiceChip(
                      label: Text('$i'),
                      selected: _valori[c.id] == i,
                      showCheckmark: false,
                      selectedColor: AppColors.blue,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _valori[c.id] == i
                            ? AppColors.blue
                            : AppColors.line,
                      ),
                      labelStyle: TextStyle(
                        color: _valori[c.id] == i
                            ? Colors.white
                            : AppColors.ink,
                      ),
                      onSelected: (_) => setState(() => _valori[c.id] = i),
                    ),
                ],
              ),
            ],
          ),
        );
      case CampBifa():
        final bifat = _valori[c.id] == true;
        return CheckboxListTile(
          value: bifat,
          onChanged: (v) => setState(() => _valori[c.id] = v ?? false),
          activeColor: AppColors.blue,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            c.eticheta,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
          ),
          subtitle: c.detaliu == null
              ? null
              : Text(
                  c.detaliu!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
          secondary: c.puncte == 0
              ? null
              : Text(
                  '+${c.puncte}',
                  style: TextStyle(
                    color: bifat ? AppColors.blue : AppColors.muted,
                  ),
                ),
        );
    }
  }
}

class _RezultatCard extends StatelessWidget {
  final Rezultat? rezultat;
  const _RezultatCard(this.rezultat);

  @override
  Widget build(BuildContext context) {
    final r = rezultat;
    final ridicat = r?.nivel == Nivel.ridicat;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ridicat
            ? const LinearGradient(colors: [AppColors.red, Color(0xFFA81426)])
            : AppColors.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: r == null
          ? Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Completează datele pentru a vedea rezultatul',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      r.valoare,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 43,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        r.unitate,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (r.nivel != Nivel.normal)
                      Icon(
                        ridicat
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        color: Colors.white,
                        size: 26,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  r.interpretare,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }
}
