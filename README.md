# 🚀 SERVIDOR vanmanhgaming – RDP Premium vía GitHub Actions

## 📌 Introducción
**SERVIDOR vanmanhgaming** es un **GitHub Actions Workflow** que crea automáticamente una **máquina Windows con Remote Desktop (RDP)** ejecutándose en GitHub Runner (`windows-latest`).

Este workflow te ayuda a:
- Tener al instante un **RDP de Windows para uso temporal**
- No necesitas alquilar un VPS
- No necesitas abrir puertos públicos
- Conexión segura a través de **Tailscale**
- Se apaga y limpia automáticamente al finalizar el tiempo

Adecuado para:
- Probar software de Windows
- Ejecutar herramientas / scripts
- Aprendizaje – demo – desarrollo rápido
- Entorno temporal, sin almacenamiento a largo plazo

---

## ⚙️ ¿Qué hace este workflow?
Al ejecutarse, el workflow **realiza automáticamente y en secuencia** los siguientes pasos:

1. Iniciar Windows Runner
2. Activar Remote Desktop (RDP)
3. Abrir el firewall en el puerto 3389 (interno)
4. Crear el usuario **Administrator**
5. Generar o usar una contraseña personalizada
6. Instalar y conectar **Tailscale**
7. Obtener la IP privada
8. Verificar la conexión RDP
9. Mostrar la información de inicio de sesión
10. Mantener la sesión según el tiempo que elijas
11. Al finalizar el tiempo → limpieza automática y bloqueo del sistema

---

## 🧱 Requisitos antes de usar

### 1️⃣ Cuenta de GitHub
- GitHub Free / Pro funcionan
- Tener permiso para ejecutar **GitHub Actions**

### 2️⃣ Cuenta de Tailscale
- Regístrate en https://tailscale.com
- Crea una **Auth Key** (Reusable o Ephemeral, ambas sirven)

---

## 🔐 Configurar Secrets (OBLIGATORIO)

Ve al repo de GitHub → **Settings → Secrets and variables → Actions → New repository secret**

### 🔑 Secret obligatorio
| Nombre | Descripción |
|----|------|
| `TAILSCALE_AUTH_KEY` | Auth Key de Tailscale |

### 🔐 Secret opcional
| Nombre | Descripción |
|----|------|
| `CUSTOM_RDP_PASS` | Contraseña RDP que tú mismo defines |

> Si **no configuras `CUSTOM_RDP_PASS`**, el workflow **generará automáticamente una contraseña segura**.

---

## ▶️ Cómo ejecutar el Workflow

### Paso 1: Ir a Actions
- Abre el repo de GitHub
- Selecciona la pestaña **Actions**
- Selecciona el workflow: **🚀 SERVIDOR vanmanhgaming**

### Paso 2: Ejecutar workflow
- Presiona **Run workflow**
- Selecciona el **Tiempo de uso**
- Presiona **Run**

### ⏱️ Tiempos disponibles
- 30 minutos
- 1 hora
- 1 hora 30 minutos
- 2 → 6 horas

---

## 🧑‍💻 Información de inicio de sesión RDP

Después de que el workflow termine de ejecutarse, el log mostrará:

- 🌐 **IP (Tailscale)**
- 👤 **Usuario:** `vanmanhgaming`
- 🔐 **Contraseña**
- 📍 **Puerto:** `3389`

### 🔑 Ejemplo
```text
IP: 100.xxx.xxx.xxx
Usuario: vanmanhgaming
Contraseña: Según la versión aleatoria y la contraseña fija.
Puerto: 3389
```
