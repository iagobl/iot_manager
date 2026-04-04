class IoTStrings {
  static const ssidRequiredWifi = 'La red Wi-Fi seleccionada requiere un SSID. Por favor, ingresa el SSID para continuar';
  static const passwordRequiredWIFI = 'La red Wi-Fi seleccionada requiere contraseña. Por favor, ingresa la contraseña para continuar';

  static const blockPermissions = 'Permisos BLE bloqueados. Ve a Ajustes > Apps > tu app > Permisos y habilita Bluetooth y Ubicación.';
  static const permissionsError = 'Permisos BLE no concedidos. Se requieren Bluetooth y Ubicación para descubrir dispositivos';

  static const blockApPermissions = 'Los permisos de Wi-Fi o ubicación están bloqueados. Ve a Ajustes y habilítalos para buscar y conectar redes Shelly.';
  static const permissionsApError = 'La app necesita permisos de Wi-Fi y ubicación para trabajar con el modo AP.';
  static const errorScanningShellyApNetworks = 'No se pudieron escanear las redes Wi-Fi Shelly cercanas.';
  static const errorGettingCurrentWifi = 'No se pudo obtener la red Wi-Fi actual del móvil.';
  static const notConnectedToShellyApAutomatically = 'No se pudo conectar automáticamente a la red del Shelly.';
  static const timeoutConnectingShellyAp = 'Se agotó el tiempo al intentar conectarse a la red del Shelly.';
  static const notConnectedToExpectedShellyAp = 'El móvil no está conectado a la red del Shelly seleccionado.';
  static const errorSendingWifiCredentialsByAp = 'No se pudieron enviar las credenciales Wi-Fi al Shelly usando el modo AP.';

  static const notConnectingBLE = 'BLE no conectado';

  static const notConnectingWiFi = 'No se pudo obtener la subred local. Comprueba que estás conectado a una Wi-Fi';
  static const notFoundErrorWiFi = 'Error inesperado al buscar en la red local';
  static const notFoundInSubnetDevice = 'No se pudo obtener la subred local. Comprueba que estás conectado a una Wi-Fi';
  static const notFoundDeviceinWiFi = 'No se pudieron descubrir dispositivos en la red';

  static const permissionWiFi = 'Debes conceder permiso de ubicación para obtener la red Wi-Fi actual.';
  static const permissionLocation = 'Debes conceder permiso de ubicación para obtener la IP Wi-FI';
  static const notValidIP = 'La IP de la red Wi-Fi no tiene un formato válido.';

  static const notValidRequest = 'La respuesta HTTP del Shelly no es valida';
  static const cannotConnectLocalNetwork = 'No se pudo conectar con el dispositivo por red local';
  static const tooLongResponseTime = 'El dispositivo tardó demasiado en responder';
  static const notValidResponseFormat = 'La respuesta del dispositivo no tiene un formato válido';
  static const notFoundErrorWithDevice = 'Error inesperado al comunicarse con el dispositivo';

  static const notConnectingWithBluetooth = 'No se pudo conectar por Bluetooth al dispositivo';
  static const notFoundRPC = 'No se encontró el servicio RPC en el dispositivo por Bluetooth';
  static const notFoundCharacteristicRPC = 'No se encontró la característica RPC en el dispositivo';
  static const notFoundTXCTL = 'No se encontró la característica TXCTL en el dispositivo';
  static const notFoundRXCTL = 'No se encontró la característica RXCTL en el dispositivo';
  static const timeOutConnectingBLE = 'Se agotó el tiempo al intentar conectar por Bluetooth con el dispositivo';
  static const errorCommunicatingBLE = 'Error inesperado al comunicarse por Bluetooth con el dispositivo';
  static const notRebootingDevice = 'No se pudo reiniciar el dispositivo tras el provisionamiento por Bluetooth';
  static const errorGettingMac = 'No se pudo obtener la MAC real del Shelly por BLE';
  static const timeOutRedingData = 'Se agotó el tiempo al leer datos por Bluetooth del dispositivo';
  static const notCompletedOperationBLE = 'No se pudo completar la operación por Bluetooth con el dispositivo';
  static const timeOutConnectingBluetooth = 'Se agotó el tiempo al intentar conectar por Bluetooth con el dispositivo';
  static const errorReceivedBLE = 'La respuesta de bluetooth no coincide con la petición enviada';
  static const invalidRequestBLE = 'La respuesta RPC por Bluetooth es inválida';
  static const waitingResponseRXCTL = 'Timeout esperando notificación RXCTL para ';
  static const errorRPCBLE = 'Error RPC por Bluetooth: ';
  static const errorRPCDevice = 'Error RPC del dispositivo: ';
}