import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cat de gros este scrisul obisnuit din aplicatie.
enum GrosimeText {
  subtire('Subțire', FontWeight.w300),
  normal('Normal', FontWeight.w400),
  ingrosat('Îngroșat', FontWeight.w600);

  final String eticheta;
  final FontWeight grosime;
  const GrosimeText(this.eticheta, this.grosime);
}

/// Felul in care arata scrisul din aplicatie, ales de utilizator: marimea si
/// grosimea. Inlocuiesc setarile de text ale telefonului, pe care aplicatia
/// nu le urmeaza.
class SetariTextProvider extends ChangeNotifier {
  static const _cheieScara = 'text_scara';
  static const _cheieGrosime = 'text_grosime';

  static const scaraMinima = 0.8;
  static const scaraMaxima = 1.4;
  static const pas = 0.05;

  /// 1 = marimile stabilite in aplicatie.
  double scara = 1;
  GrosimeText grosime = GrosimeText.normal;

  bool get implicite => scara == 1 && grosime == GrosimeText.normal;

  Future<void> incarca() async {
    final prefs = await SharedPreferences.getInstance();
    scara = _inLimite(prefs.getDouble(_cheieScara) ?? 1);
    final salvata = prefs.getString(_cheieGrosime);
    grosime = GrosimeText.values.firstWhere(
      (g) => g.name == salvata,
      orElse: () => GrosimeText.normal,
    );
    notifyListeners();
  }

  /// Aduce valoarea in intervalul permis si pe un pas intreg.
  static double _inLimite(double v) {
    final pasi = (v.clamp(scaraMinima, scaraMaxima) / pas).round();
    return double.parse((pasi * pas).toStringAsFixed(2));
  }

  Future<void> seteazaScara(double valoare) async {
    final noua = _inLimite(valoare);
    if (noua == scara) return;
    scara = noua;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cheieScara, scara);
  }

  Future<void> seteazaGrosime(GrosimeText valoare) async {
    if (valoare == grosime) return;
    grosime = valoare;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cheieGrosime, valoare.name);
  }

  Future<void> reseteaza() async {
    scara = 1;
    grosime = GrosimeText.normal;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cheieScara);
    await prefs.remove(_cheieGrosime);
  }
}
