import 'dart:convert';

import 'package:iot_manager/core/config/shelly_telemetry_config.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';

class ShellyTelemetryScriptService {
  const ShellyTelemetryScriptService();

  Future<void> installOrUpdate({required String host, required String deviceId}) async {
    if (host.trim().isEmpty || deviceId.trim().isEmpty) {
      throw const ValidationAppException(
        'No se ha podido activar la telemetría automática del Shelly.',
      );
    }

    final rpc = ShellyRpcClient(host: host.trim());
    final scripts = await rpc.listScripts();

    int? scriptId;
    for (final script in scripts) {
      if ((script['name'] ?? '').toString() == ShellyTelemetryConfig.scriptName) {
        scriptId = (script['id'] as num?)?.toInt();
        break;
      }
    }

    scriptId ??= await rpc.createScript(name: ShellyTelemetryConfig.scriptName);

    try {
      await rpc.stopScript(scriptId);
    } catch (_) {}

    await rpc.putScriptCode(
      id: scriptId,
      code: _buildTelemetryScript(deviceId: deviceId.trim()),
    );
    await rpc.setScriptConfig(id: scriptId, enable: true);
    await rpc.startScript(scriptId);
  }

  String _buildTelemetryScript({required String deviceId}) {
    final url = jsonEncode(ShellyTelemetryConfig.ingestUrl);
    final auth = jsonEncode(ShellyTelemetryConfig.authorizationHeader);
    final scriptName = jsonEncode(ShellyTelemetryConfig.scriptName);
    final interval = ShellyTelemetryConfig.intervalSeconds * 1000;
    final did = jsonEncode(deviceId);

    return '''
let DEVICE_ID = $did;
let INGEST_URL = $url;
let AUTH_HEADER = $auth;
let SCRIPT_NAME = $scriptName;
let PERIOD_MS = $interval;
let DEVICE_INFO = Shelly.getDeviceInfo();
let DEVICE_MODEL = DEVICE_INFO && DEVICE_INFO.model ? DEVICE_INFO.model : '';
let DEVICE_IDENTITY = DEVICE_INFO && DEVICE_INFO.id ? DEVICE_INFO.id : '';

function buildPayload() {
  let sw = Shelly.getComponentStatus('switch', 0);
  if (!sw) return null;

  let payload = {
    device_id: DEVICE_ID,
    source: 'shelly_script',
    script_name: SCRIPT_NAME,
    device_model: DEVICE_MODEL,
    shelly_id: DEVICE_IDENTITY,
    is_on: sw.output === true,
    power_w: typeof sw.apower === 'number' ? sw.apower : 0,
    voltage_v: typeof sw.voltage === 'number' ? sw.voltage : 0,
    current_a: typeof sw.current === 'number' ? sw.current : 0,
    energy_wh: sw.aenergy && typeof sw.aenergy.total === 'number' ? sw.aenergy.total : 0,
    meta: {
      has_timer: sw.has_timer === true,
      timer_remaining: typeof sw.timer_remaining === 'number' ? sw.timer_remaining : null,
      overpower: sw.overpower === true,
      overtemperature: sw.overtemperature === true,
      temperature: typeof sw.temperature === 'number' ? sw.temperature : null,
      freq: typeof sw.freq === 'number' ? sw.freq : null,
      pf: typeof sw.pf === 'number' ? sw.pf : null
    }
  };

  return JSON.stringify(payload);
}

function onPostDone(result, error_code, error_message) {
  if (error_code !== 0) {
    print('telemetry post failed', error_code, error_message);
    return;
  }

  if (result && typeof result.code === 'number' && result.code >= 400) {
    print('telemetry endpoint error', JSON.stringify(result));
  }
}

function pushTelemetry() {
  let body = buildPayload();
  if (body === null) {
    print('telemetry skipped: switch status unavailable');
    return;
  }

  Shelly.call('HTTP.Request', {
    method: 'POST',
    url: INGEST_URL,
    headers: {
      'Authorization': AUTH_HEADER,
      'Content-Type': 'application/json'
    },
    body: body,
    timeout: 15
  }, onPostDone);
}

pushTelemetry();
Timer.set(PERIOD_MS, true, pushTelemetry);
''';
  }
}
