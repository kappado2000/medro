import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notificarea de sambata dimineata care anunta editia noua a Sintezei.
///
/// Este o notificare locala, programata de telefon: nu are nevoie de server
/// si functioneaza si la aplicatia instalata fara semnatura de dezvoltator.
/// Telefonul nu stie daca editia a aparut cu adevarat; ora este aleasa dupa
/// publicarea obisnuita (rutina porneste la 04:00 UTC).
class NotificariSinteza {
  NotificariSinteza();

  /// Se poate inlocui in teste.
  static NotificariSinteza instance = NotificariSinteza();

  static const _cheie = 'sinteza_notificare';
  static const _id = 4101;

  /// Ziua si ora locala la care apare notificarea.
  static const zi = DateTime.saturday;
  static const ora = 9;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initializat = false;

  /// Apelata cand utilizatorul atinge notificarea.
  VoidCallback? laAtingere;

  // in teste si in browser nu exista notificari locale
  static bool get _indisponibil =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  /// Pregateste notificarile si afla daca aplicatia a fost deschisa dintr-una.
  Future<void> init() async {
    if (_indisponibil || _initializat) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // permisiunea se cere abia cand utilizatorul porneste notificarea
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => laAtingere?.call(),
      );
      _initializat = true;
      final pornire = await _plugin.getNotificationAppLaunchDetails();
      if (pornire?.didNotificationLaunchApp ?? false) laAtingere?.call();
    } catch (_) {
      // fara notificari, restul aplicatiei merge la fel
    }
  }

  /// Alegerea utilizatorului: true, false sau null daca nu a fost intrebat.
  Future<bool?> alegere() async {
    if (_indisponibil) return false;
    return (await SharedPreferences.getInstance()).getBool(_cheie);
  }

  /// Porneste sau opreste notificarea saptamanala. Intoarce starea reala:
  /// false si daca utilizatorul a refuzat permisiunea in telefon.
  Future<bool> seteaza(bool pornita) async {
    if (_indisponibil) return false;
    final prefs = await SharedPreferences.getInstance();
    var reusit = false;
    try {
      await init();
      if (pornita && await _permisiune()) {
        await _programeaza();
        reusit = true;
      } else {
        await _plugin.cancel(id: _id);
      }
    } catch (_) {
      reusit = false;
    }
    await prefs.setBool(_cheie, reusit);
    return reusit;
  }

  Future<bool> _permisiune() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  Future<void> _programeaza() async {
    tzdata.initializeTimeZones();
    try {
      final fus = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(fus.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Bucharest'));
    }
    await _plugin.zonedSchedule(
      id: _id,
      title: 'Sinteza săptămânii',
      body:
          'A apărut ediția nouă: psihiatrie, medicină, științe, artă și '
          'arhitectură.',
      scheduledDate: urmatoareaAparitie(tz.TZDateTime.now(tz.local)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sinteza',
          'Sinteza săptămânii',
          channelDescription: 'Anunță ediția nouă, sâmbătă dimineața',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // ora nu trebuie sa fie exacta la minut, deci nu se cere permisiunea
      // de alarme exacte
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // se repeta in fiecare saptamana, in aceeasi zi si la aceeasi ora
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Prima sambata, ora 9, de dupa momentul dat.
  static tz.TZDateTime urmatoareaAparitie(tz.TZDateTime acum) {
    // ziua se construieste din componente, nu prin adunare de 24 de ore, ca
    // trecerea la ora de vara sau de iarna sa nu mute ora
    for (var i = 0; ; i++) {
      final t = tz.TZDateTime(
        acum.location,
        acum.year,
        acum.month,
        acum.day + i,
        ora,
      );
      if (t.weekday == zi && t.isAfter(acum)) return t;
    }
  }
}
