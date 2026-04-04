class DevicesStrings {
  static const ssid = 'SSID';
  static const password = 'Contraseña Wi-Fi';
  static const devices = 'Dispositivos';
  static const active = 'Activos';

  static const on = 'ON';
  static const off = 'OFF';

  static const deviceName = 'Nombre del dispositivo';
  static const notDeviceName = 'El nombre del dispositivo no puede estar vacío';
  static const notDeviceIdentifier = 'La IP o identificador del dispositivo no puede estar vacío';
  static const notShellyinLAN = 'No se han encontrado dispositivos Shelly en la red';
  static const notBluetoothActivated = 'El Bluetooth no está activado. Por favor, actívalo para descubrir dispositivos';
  static const selectDevice = 'Selecciona primero un dispositivo';

  static const macDevice = 'Obteniendo dirección MAC del dispositivo...';
  static const credentialsDevices = 'Enviando credenciales Wi-Fi al dispositivo...';
  static const rebootDevice = 'Reiniciando dispositivo...';
  static const runDevice = 'Esperando a que el dispositivo se conecte a la red...';
  static const notFoundDevice = 'No se ha encontrado el dispositivo en la red';
  static const errorProvisioningBLE = 'Error durante el proceso de provisión por Bluetooth';
  static const errorProvisioningAp = 'Error durante el proceso de provisión por modo AP';

  static const notNameBLE = 'Dispositivo BLE sin nombre';

  static const addShellyDevice = 'Vincular dispositivo Shelly';
  static const foundDevices = 'Dispositivos encontrados';
  static const searchShellyDevices = 'Buscando dispositivos Shelly en la red...';
  static const searchShellyApDevices = 'Buscando redes Wi-Fi de dispositivos Shelly...';
  static const notFoundBluetoothDevices = 'No se han encontrado dispositivos por bluetooth';
  static const notFoundShellyApNetworks = 'No se han encontrado redes Wi-Fi Shelly cercanas';

  static const connectingDevice = 'Conectando al dispositivo...';
  static const connectionBLE = 'Conectando por BLE...';
  static const vindicatingDevice = 'Vincular dispositivo';
  static const errorConnectingBLE = 'Error al inciar el escaneo por Bluetooth';

  static const stopEscanning = 'Parar escaneo';
  static const scanningBle = 'Escanear dispositivos';

  static const configurationBluetooth = 'Configurar por Bluetooth';
  static const configurationManual = 'Configurar manualmente';
  static const configurationAp = 'Configurar modo AP';
  static const scanningLan = 'Escanear en la red';
  static const configurationBluetoothSubtitle = 'Configurar un dispositivo nuevo usando Bluetooth';
  static const configurationManualSubtitle = 'Configurar un dispositivo nuevo introduciendo su información manualmente';
  static const configurationApSubtitle = 'Configurar un dispositivo nuevo conectándose a la red Wi-Fi temporal del Shelly';
  static const scanningLanSubtitle = 'Configurar un dispositivo nuevo buscando en la red';
  static const notDevicesAdd = 'No se han añadido dispositivos aún. ¡Añade tu primer dispositivo!';

  static const addDeviceSucesful = 'Dispositivo añadido correctamente';
  static const completeConfiguration = 'Completa el nombre y la IP/host';
  static const addDevice = 'Añadir dispositivo';

  static const tipesDevices = 'Tipo de dispositivo';
  static const plug = 'Enchufe';
  static const light = 'Luz';

  static const ejTipesDevices = 'Ej: Enchufe salón';
  static const ejIP = 'Ej: 192.168.1.70';

  static const apModeTitle = 'Configuración por modo AP';
  static const apModeDescription = 'Con este método la app se conecta a la red Wi-Fi temporal del Shelly, le envía las credenciales de tu red doméstica y después lo localiza en la LAN.';
  static const apInitialStatus = 'Introduce la contraseña de tu Wi-Fi, busca el Shelly y conéctate a su red AP.';
  static const apReadyToStart = 'Ya puedes buscar redes Shelly y comenzar el proceso.';
  static const homeWifiConfiguration = 'Wi-Fi de casa';
  static const apModeHomeWifiHint = 'El SSID se rellena con la red actual. Solo necesitas revisar el nombre e introducir la contraseña.';
  static const searchShellyApTitle = 'Buscar redes Shelly';
  static const searchShellyApButton = 'Buscar redes Shelly';
  static const selectShellyApNetwork = 'Selecciona la red Wi-Fi del Shelly que quieres configurar.';
  static const selectShellyApFirst = 'Selecciona primero una red Wi-Fi Shelly.';
  static const connectShellyApTitle = 'Conectar al Shelly';
  static const selectedShellyAp = 'Red seleccionada';
  static const noShellyApSelected = 'Aún no has seleccionado ninguna red Shelly';
  static const connectShellyApAutomaticallyButton = 'Conectar automáticamente';
  static const iAmAlreadyConnectedToShellyAp = 'Ya estoy conectado manualmente';
  static const apManualFallbackHint = 'Si la conexión automática falla en tu móvil, conéctate manualmente en los ajustes Wi-Fi a la red del Shelly y vuelve aquí para continuar.';
  static const connectingShellyAp = 'Conectando automáticamente a la red del Shelly...';
  static const validatingManualShellyApConnection = 'Comprobando la conexión manual con la red del Shelly...';
  static const connectedShellyAp = 'Conexión con el Shelly completada. Ya puedes enviar las credenciales de tu Wi-Fi.';
  static const connectShellyApBeforeProvision = 'Conéctate antes a la red Wi-Fi del Shelly.';
  static const provisionShellyApTitle = 'Enviar credenciales';
  static const sendHomeWifiCredentialsButton = 'Enviar credenciales al dispositivo';
  static const finishApProvisionTitle = 'Finalizar configuración';
  static const findProvisionedDeviceButton = 'Buscar dispositivo en mi red';
  static const apReconnectToHomeWifiMessage = 'Cuando el Shelly reinicie, vuelve a conectar el móvil a tu Wi-Fi de casa y pulsa el botón para localizar el dispositivo ya provisionado.';
  static const notConnectedYetToShellyAp = 'Todavía no estás conectado a ningún Shelly en modo AP.';
  static const shellyApDetected = 'Dispositivo Shelly detectado';
  static const detectedModel = 'Modelo detectado';
}