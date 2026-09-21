import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:addisyon_backend/api.dart';
import 'package:addisyon_backend/database.dart';
import 'package:addisyon_backend/native_sqlite.dart';

Future<void> main(List<String> args) async {
  configureSqliteNativeLibrary();

  final backendDir = p.dirname(p.dirname(Platform.script.toFilePath()));
  final dbPath = p.join(backendDir, 'addisyon.db');
  final db = RestaurantDb.open(dbPath);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final handler = buildApiHandler(db);
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  final lanIp = await _findLanAddress();
  stdout.writeln('Limon & Zeytin backend çalışıyor:');
  stdout.writeln('  Yerel:  http://localhost:${server.port}');
  if (lanIp != null) {
    stdout.writeln('  Ağda:   http://$lanIp:${server.port}  (aynı Wi-Fi\'daki cihazlar için)');
  }
  stdout.writeln('  Veritabanı: $dbPath');
  stdout.writeln('Durdurmak için Ctrl+C.');

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    db.close();
    exit(0);
  });
}

Future<String?> _findLanAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    // VPN/tünel adaptörleri (Cloudflare WARP 172.16.x, vb.) ilk sıraya
    // geçip telefona yanlış adres verebiliyor; ev/ofis ağı adreslerini
    // (192.168.x, 10.x) öne al.
    int rank(String ip) {
      if (ip.startsWith('192.168.')) return 0;
      if (ip.startsWith('10.')) return 1;
      return 2;
    }

    final addresses = [
      for (final iface in interfaces)
        for (final addr in iface.addresses)
          if (!addr.isLoopback) addr.address,
    ]..sort((a, b) => rank(a).compareTo(rank(b)));
    return addresses.isEmpty ? null : addresses.first;
  } catch (_) {
    // Ağ arayüzleri okunamazsa sessizce yerel adresle devam et.
  }
  return null;
}
