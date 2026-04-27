# IoT Manager

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter\&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart\&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase\&logoColor=white)
![Android](https://img.shields.io/badge/Android-Mobile_App-34A853?logo=android\&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow)

Sistema móbil avanzado para a xestión, control e monitorización enerxética de dispositivos IoT domésticos.

---

# Descrición

**IoT Manager** é unha aplicación móbil desenvolvida como Traballo Fin de Grao (TFG) orientada á administración intelixente do fogar mediante dispositivos IoT. O sistema permite rexistrar dispositivos, controlalos remotamente, analizar consumos eléctricos, detectar incidencias e centralizar a xestión de múltiples vivendas nunha única plataforma.

O proxecto nace coa finalidade de ofrecer unha alternativa moderna ás aplicacións propietarias tradicionais, incorporando maior control, analítica avanzada e unha experiencia de usuario profesional. 

---

# Obxectivos do proxecto

A aplicación foi deseñada para cumprir os seguintes obxectivos:

* Control total de dispositivos intelixentes.
* Rexistro e autenticación de usuarios.
* Visualización de consumo en tempo real.
* Estatísticas por dispositivo, habitación e período temporal.
* Exportación de informes PDF.
* Notificacións móbiles por incidencias.
* Configuración automática de dispositivos.
* Compartición entre usuarios.
* Sistema de seguridade con apagado preventivo.
* Xestión multi-vivenda. 

---

# Características principais

## Autenticación e usuarios

* Rexistro de contas.
* Inicio e peche de sesión.
* Perfil persoal editable.
* Avatar personalizado.
* Sesión persistente.

## Xestión de vivendas

* Creación de múltiples fogares.
* Cambio rápido entre vivendas.
* Organización independente por usuario.
* Estatísticas xerais por fogar.

## Xestión de dispositivos

* Alta manual ou automática.
* Renomeado de dispositivos.
* Asociación a habitacións.
* Eliminación segura.
* Estado en tempo real.
* Control ON/OFF instantáneo.

## Provisionamento intelixente

* Configuración vía Bluetooth Low Energy.
* Configuración mediante AP Mode.
* Descubrimento automático en LAN.
* Integración con dispositivos Shelly.

## Monitorización enerxética

* Potencia instantánea (W).
* Voltaxe (V).
* Corrente (A).
* Factor de potencia.
* Consumo acumulado.
* Datos históricos.

## Analíticas avanzadas

* Vista actual en tempo real.
* Consumo diario.
* Histórico semanal.
* Estatísticas agregadas.
* Picos máximos.
* Media de consumo.
* Exportación PDF.

## Sistema de incidencias

* Exceso de potencia.
* Sobretensión.
* Sobrecorrente.
* Alertas automáticas.
* Apagado preventivo.
* Rexistro histórico.

## Compartición entre usuarios

* Invitacións internas.
* Acceso compartido a dispositivos.
* Revogación de permisos.
* Sincronización automática.

## Notificacións

* Avisos dentro da aplicación.
* Badge de incidencias.
* Invitacións pendentes.
* Push notifications preparadas para integración futura.

---

# Tecnoloxías empregadas

| Tecnoloxía   | Uso                  |
| ------------ | -------------------- |
| Flutter      | Aplicación móbil     |
| Dart         | Linguaxe principal   |
| Supabase     | Backend              |
| PostgreSQL   | Base de datos        |
| Shelly       | Hardware IoT         |
| Bluetooth LE | Provisionamento      |
| HTTP RPC     | Comunicación local   |
| PDF          | Xeración de informes |

---

# Arquitectura do proxecto

O proxecto segue unha estrutura modular baseada en **Clean Architecture** e organización por funcionalidades.

```text
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── services/
│   ├── theme/
│   └── widgets/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── devices/
│   ├── analytics/
│   ├── notifications/
│   └── profile/
│
└── main.dart
```

## Capas

### Presentation

Pantallas, widgets, navegación e controladores.

### Domain

Entidades, casos de uso e contratos.

### Data

Repositorios, modelos, Supabase e comunicación IoT.

---

# Base de datos

Táboas principais utilizadas:

| Táboa              | Función                    |
| ------------------ | -------------------------- |
| profiles           | Usuarios                   |
| homes              | Vivendas                   |
| rooms              | Estancias                  |
| devices            | Dispositivos               |
| readings           | Medicións                  |
| incidents          | Incidencias                |
| device_shares      | Compartición               |
| device_automations | Horarios e automatizacións |

---

# Seguridade

O proxecto incorpora medidas reais de protección:

* Row Level Security (RLS).
* Control de acceso por propietario.
* Bucket privado para avatares.
* URLs asinadas.
* Validación de permisos.
* Compartición segura.
* Sesións autenticadas.

Tamén se inclúe documentación específica no repositorio:

* `SECURITY.md`
* `CODE_OF_CONDUCT.md`
* `CONTRIBUTING.md`
* `LICENSE`

---

# Dispositivos compatibles

Actualmente orientado a dispositivos intelixentes baseados en Wi-Fi, especialmente:

* Shelly Plug
* Shelly Plug S
* Shelly Gen2 / Gen3
* Bombillas conectadas compatibles

A arquitectura permite ampliar compatibilidade no futuro.

---

# Instalación

## Requisitos

* Flutter SDK
* Android Studio
* Android físico ou emulador
* Conta en Supabase

## Clonar repositorio

```bash
git clone https://github.com/usuario/iot_manager.git
cd iot_manager
```

## Instalar dependencias

```bash
flutter pub get
```

## Configurar entorno

Crear ficheiro `.env`

```env
SUPABASE_URL=YOUR_URL
SUPABASE_ANON_KEY=YOUR_KEY
```

## Executar

```bash
flutter run
```

---

# Fluxo de uso

1. Crear conta ou iniciar sesión.
2. Crear unha vivenda.
3. Engadir dispositivos IoT.
4. Configurar límites de seguridade.
5. Consultar consumo en tempo real.
6. Visualizar gráficas históricas.
7. Compartir dispositivos.
8. Recibir incidencias automáticas.

---

# Estado actual do proxecto

Desenvolvido como TFG funcional con integración real de dispositivos IoT, backend operativo e aplicación móbil completa.

Inclúe:

* Control real de dispositivos.
* Analíticas avanzadas.
* Sistema multiusuario.
* Compartición.
* Alertas.
* UI profesional.
* Estrutura escalable.

---

# Liñas futuras

* Compatibilidade Matter.
* Integración con asistentes de voz.
* Aplicación iOS.
* Dashboard web.
* IA aplicada ao consumo.
* Alertas predictivas.
* Automatización avanzada.

---

# Autor

**Iago Becerra López**
Universidade da Coruña

---

# Licenza

Distribuído baixo licenza MIT. Consultar ficheiro `LICENSE`.

---

# Resumo

**IoT Manager** é unha plataforma moderna orientada á domótica intelixente que combina:

* Control remoto
* Eficiencia enerxética
* Seguridade activa
* Monitorización avanzada
* Arquitectura profesional
* Escalabilidade futura

Un proxecto académico real desenvolvido cun enfoque profesional e tecnoloxías actuais.
