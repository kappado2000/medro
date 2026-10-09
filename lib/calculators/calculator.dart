import 'package:flutter/material.dart';

sealed class Camp {
  final String id;
  final String eticheta;
  const Camp(this.id, this.eticheta);
}

/// Valoare numerica; in `valori` apare ca double.
class CampNumar extends Camp {
  final String unitate;
  const CampNumar(super.id, super.eticheta, this.unitate);
}

/// O singura optiune dintr-o lista; in `valori` apare ca indexul ales (int).
/// Daca `puncte` e dat, eticheta optiunii afiseaza si punctajul.
class CampAlegere extends Camp {
  final List<String> optiuni;
  final List<int>? puncte;

  /// Indexul optiunii selectate de la inceput, daca exista.
  final int? implicit;

  const CampAlegere(
    super.id,
    super.eticheta,
    this.optiuni, {
    this.puncte,
    this.implicit,
  });
}

/// Nota de la 0 la `maxim`; in `valori` apare ca int si se aduna la scor.
class CampScala extends Camp {
  final int maxim;
  final int minim;
  final String? detaliu;
  const CampScala(
    super.id,
    super.eticheta,
    this.maxim, {
    this.minim = 0,
    this.detaliu,
  });
}

/// Criteriu bifabil dintr-un scor; in `valori` apare ca bool.
class CampBifa extends Camp {
  final int puncte;
  final String? detaliu;
  const CampBifa(super.id, super.eticheta, this.puncte, {this.detaliu});
}

enum Nivel { normal, atentie, ridicat }

class Rezultat {
  final String valoare;
  final String unitate;
  final String interpretare;
  final Nivel nivel;

  const Rezultat(
    this.valoare,
    this.unitate,
    this.interpretare, [
    this.nivel = Nivel.normal,
  ]);
}

class Calculator {
  final String id;
  final String titlu;
  final String descriere;
  final String categorie;
  final IconData icon;
  final List<Camp> campuri;
  final String sursa;

  /// Intoarce null cat timp lipsesc valori obligatorii.
  final Rezultat? Function(Map<String, Object> valori) calculeaza;

  const Calculator({
    required this.id,
    required this.titlu,
    required this.descriere,
    required this.categorie,
    required this.icon,
    required this.campuri,
    required this.sursa,
    required this.calculeaza,
  });
}

/// Suma punctelor pentru campurile bifate si optiunile alese cu punctaj.
int sumaPuncte(List<Camp> campuri, Map<String, Object> valori) {
  var total = 0;
  for (final c in campuri) {
    final v = valori[c.id];
    if (c is CampBifa && v == true) total += c.puncte;
    if (c is CampScala && v is int) total += v;
    if (c is CampAlegere && c.puncte != null && v is int) total += c.puncte![v];
  }
  return total;
}

String formatNumar(double v, [int zecimale = 1]) {
  return v.toStringAsFixed(zecimale).replaceAll('.', ',');
}
