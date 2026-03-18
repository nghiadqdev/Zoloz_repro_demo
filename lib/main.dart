import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:zolozkit_for_flutter/zolozkit_for_flutter.dart';

const String kZolozApiBaseUrl = 'https://id-production-api.zoloz.com';
const String kZolozInitPath = '/api/v1/zoloz/idrecognition/initialize';
const String kZolozAccessKey = '';
const String kZolozSecretKey = '';
const String kZolozClientId = '';
const String kZolozNamespace = '';
const String kZolozBizId = '';
const Uuid _uuid = Uuid();

const String kZolozUserAddress = '';
const String kZolozDocType = '00840000001';
const String kZolozCountryCode = 'VNM';
const String kZolozLocale = 'en';

void main() {
  runZonedGuarded(
    () {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint(
          '[Repro][FlutterError] ${details.exceptionAsString()}\n${details.stack}',
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('[Repro][PlatformError] $error\n$stack');
        return false;
      };

      runApp(const ReproApp());
    },
    (error, stack) {
      debugPrint('[Repro][ZoneError] $error\n$stack');
    },
  );
}

class ReproApp extends StatelessWidget {
  const ReproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZOLOZ Repro Demo',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const ReproHomePage(),
    );
  }
}

class ReproHomePage extends StatefulWidget {
  const ReproHomePage({super.key});

  @override
  State<ReproHomePage> createState() => _ReproHomePageState();
}

class _ReproHomePageState extends State<ReproHomePage> {
  final TextEditingController _transactionIdController =
      TextEditingController();
  final List<String> _logs = <String>[];

  bool _isStarting = false;
  String _resolvedClientCfg = '';
  String _resolvedTransactionId = '';
  String _metaInfo = 'Tap "Load MetaInfo" to fetch from SDK.';

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
  }

  void _appendLog(String message) {
    final stamp = DateTime.now().toIso8601String();
    setState(() {
      _logs.insert(0, '[$stamp] $message');
    });
    debugPrint('--------------------------[$stamp] $message');
  }

  Future<void> _loadMetaInfo() async {
    try {
      final metaInfo = await ZolozkitForFlutter.metaInfo;
      setState(() {
        _metaInfo = metaInfo ?? 'metaInfo is null';
      });
      _appendLog('metaInfo loaded: ${_metaInfo.length} chars');
    } catch (e) {
      _appendLog('load metaInfo failed: $e');
    }
  }

  Future<void> _startScan() async {
    if (!_hasValidConstConfig()) {
      _appendLog(
        'start blocked: please set API const values in lib/main.dart first',
      );
      return;
    }

    setState(() {
      _isStarting = true;
    });

    try {
      final metaInfo = await ZolozkitForFlutter.metaInfo;
      if (metaInfo == null || metaInfo.isEmpty) {
        _appendLog('start blocked: metaInfo is empty');
        setState(() {
          _isStarting = false;
        });
        return;
      }

      final initResult = await _callZolozInitApi(metaInfo: metaInfo);
      final clientCfg = (initResult['clientCfg'] ?? '').toString();
      final initTransactionId = (initResult['transactionId'] ?? '').toString();
      if (clientCfg.isEmpty || initTransactionId.isEmpty) {
        _appendLog('start blocked: init API missing clientCfg/transactionId');
        setState(() {
          _isStarting = false;
        });
        return;
      }

      _resolvedClientCfg = clientCfg;
      _resolvedTransactionId = initTransactionId;

      final localeKey = await ZolozkitForFlutter.zolozLocale ?? 'hummerLocale';
      final chameleonKey =
          await ZolozkitForFlutter.zolozChameleonConfigPath ??
          'chameleonConfigPath';
      final pubKey = await ZolozkitForFlutter.zolozPublicKey ?? 'publicKey';
      final manualTransactionId = _transactionIdController.text.trim();
      final transactionId = manualTransactionId.isNotEmpty
          ? manualTransactionId
          : initTransactionId;

      final bizCfg = <String, dynamic>{
        localeKey: kZolozLocale,
        'transactionId': transactionId,
        chameleonKey: chameleonKey,
        pubKey: pubKey,
      };

      _appendLog(
        'start context platform=${Platform.operatingSystem} metaInfoChars=${metaInfo.length} clientCfgChars=${clientCfg.length} txChars=${transactionId.length}',
      );
      _appendLog(
        'start context keys localeKey=$localeKey chameleonKey=$chameleonKey pubKey=$pubKey',
      );
      _appendLog(
        'start called tx=$transactionId bizCfg keys=${bizCfg.keys.toList()}',
      );

      _appendLog('start invoke begin');
      await ZolozkitForFlutter.start(
        clientCfg,
        bizCfg,
        (retCode, extInfo) {
          _appendLog('onInterrupted retCode=$retCode extInfo=$extInfo');
          setState(() {
            _isStarting = false;
          });
        },
        (retCode, extInfo) {
          _appendLog('onCompleted retCode=$retCode extInfo=$extInfo');
          setState(() {
            _isStarting = false;
          });
        },
      );
      _appendLog('start invoke returned normally');
    } catch (e, st) {
      _appendLog('start failed with exception: $e');
      debugPrint('[Repro][StartException] $e\n$st');
      setState(() {
        _isStarting = false;
      });
    }
  }

  bool _hasValidConstConfig() {
    if (kZolozApiBaseUrl.contains('YOUR_API_HOST')) {
      return false;
    }
    if (kZolozAccessKey.startsWith('PASTE_') ||
        kZolozSecretKey.startsWith('PASTE_') ||
        kZolozClientId.startsWith('PASTE_')) {
      return false;
    }
    if (kZolozUserAddress.contains('YOUR_WALLET_ADDRESS')) {
      return false;
    }
    return true;
  }

  Future<Map<String, dynamic>> _callZolozInitApi({
    required String metaInfo,
  }) async {
    final uri = Uri.parse('$kZolozApiBaseUrl$kZolozInitPath');
    final bizId = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = <String, dynamic>{
      'bizId': bizId,
      'metaInfo': metaInfo,
      'userId': kZolozUserAddress,
      'docType': kZolozDocType,
      "serviceLevel": "IDRECOGNITION0003",
      "productConfig": {
        "cropDocImage": "Y",
        "cropFaceImageFromDoc": "Y",
        "enableOCR": "Y",
        "spoofMode": "STANDARD",
        // "deeperMode": "STANDARD", // The SDK flow crashes only when this field is enabled on IOS device
        "consistencyCheck": [],
      },
    };

    _appendLog('init API request => $uri');

    final client = HttpClient();
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      final body = jsonEncode(payload);
      _appendLog('init API payload => $body');
      final now = _formatRequestTime(DateTime.now());
      final method = 'POST';
      final requestUri = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
      final stringToSign = _toPayload(
        method,
        requestUri,
        kZolozClientId,
        now,
        body,
      );
      _logLongText('init API stringToSign', stringToSign);
      final signature = _sign(kZolozSecretKey, stringToSign);
      _appendLog('init API signature => $signature');
      final requestId = _uuid.v4();

      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('Request-Time', now);
      request.headers.set('Client-Id', kZolozClientId);
      request.headers.set('Auth-Type', 'AKSK');
      request.headers.set('Access-Key', kZolozAccessKey);
      request.headers.set('Signature', signature);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json;charset=UTF-8',
      );
      request.headers.set('X-Request-Id', requestId);
      request.headers.set(
        'X-Request-Ref',
        _uuid.v5(kZolozNamespace, requestId),
      );
      _logRequestHeaders(request.headers);

      try {
        request.write(body);
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        final responseBody = await utf8.decoder.bind(response).join();
        _appendLog('init API response status=${response.statusCode}');

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'init API failed status=${response.statusCode} body=$responseBody',
            uri: uri,
          );
        }

        final decoded = jsonDecode(responseBody);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('init API response is not a JSON object');
        }

        final normalized = _extractInitPayload(decoded);
        _appendLog('-------------------------- ${jsonEncode(normalized)}');
        final clientCfg = (normalized['clientCfg'] ?? '').toString();
        if (clientCfg.isEmpty) {
          _appendLog('init API clientCfg => <empty>');
        } else {
          _logLongText('init API clientCfg----------', clientCfg);
        }
        _appendLog(
          'init API parsed tx=${normalized['transactionId']} clientCfgChars=${(normalized['clientCfg'] ?? '').toString().length}',
        );
        return normalized;
      } catch (e) {
        _appendLog('init API call failed: $e');
        rethrow;
      }
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _extractInitPayload(Map<String, dynamic> raw) {
    if (raw.containsKey('clientCfg') && raw.containsKey('transactionId')) {
      return raw;
    }

    final data = raw['data'];
    if (data is Map<String, dynamic> &&
        data.containsKey('clientCfg') &&
        data.containsKey('transactionId')) {
      return data;
    }

    final result = raw['result'];
    if (result is Map<String, dynamic> &&
        result.containsKey('clientCfg') &&
        result.containsKey('transactionId')) {
      return result;
    }

    return raw;
  }

  String _formatRequestTime(DateTime time) {
    final localTime = time.toLocal();
    final offset = localTime.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absMinutes = offset.inMinutes.abs();
    final hours = (absMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (absMinutes % 60).toString().padLeft(2, '0');
    final dateTimePart = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(localTime);
    return '$dateTimePart$sign$hours$minutes';
  }

  String _toPayload(
    String method,
    String requestUri,
    String clientId,
    String requestTime,
    String body,
  ) {
    return '$method $requestUri\n$clientId.$requestTime.$body';
  }

  String _sign(String secret, String payload) {
    final normalizedSecret = base64.normalize(
      secret.replaceAll('-', '+').replaceAll('_', '/'),
    );
    final keyBytes = base64.decode(normalizedSecret);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(utf8.encode(payload));
    return base64Url
        .encode(Uint8List.fromList(digest.bytes))
        .replaceAll('=', '');
  }

  void _logRequestHeaders(HttpHeaders headers) {
    final flattened = <String, String>{};
    headers.forEach((name, values) {
      flattened[name] = values.join(', ');
    });

    final masked = <String, String>{};
    for (final entry in flattened.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'signature' || key == 'access-key') {
        masked[entry.key] = _mask(entry.value);
      } else {
        masked[entry.key] = entry.value;
      }
    }
    _appendLog('init API request headers => ${jsonEncode(masked)}');
  }

  String _mask(String value) {
    if (value.length <= 8) {
      return '***';
    }
    return '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
  }

  void _logLongText(String label, String value, {int chunkSize = 800}) {
    if (value.length <= chunkSize) {
      _appendLog('$label => $value');
      return;
    }

    final total = (value.length / chunkSize).ceil();
    for (var i = 0; i < total; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > value.length)
          ? value.length
          : start + chunkSize;
      _appendLog('$label [${i + 1}/$total] => ${value.substring(start, end)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZOLOZ Flutter Repro')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _loadMetaInfo,
                      child: const Text('Load MetaInfo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_metaInfo, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Text(
                'Resolved tx: ${_resolvedTransactionId.isEmpty ? '-' : _resolvedTransactionId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('Resolved clientCfg chars: ${_resolvedClientCfg.length}'),
              const SizedBox(height: 12),
              TextField(
                controller: _transactionIdController,
                decoration: const InputDecoration(
                  labelText: 'Override transactionId (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Init endpoint: $kZolozApiBaseUrl$kZolozInitPath\n'
                    'userAddress: $kZolozUserAddress\n'
                    'docTypes: $kZolozDocType\n'
                    'countryCode: $kZolozCountryCode',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _isStarting ? null : _startScan,
                      child: Text(_isStarting ? 'Starting...' : 'Start ZOLOZ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Logs',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    reverse: false,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(_logs[index]),
                      );
                    },
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
