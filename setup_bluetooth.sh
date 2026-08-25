#!/bin/bash
# ============================================================
# Script para configurar Bluetooth no Linux (Ubuntu/Debian)
# Autor: Fábio Lapuinka
# ============================================================

echo "=========================================="
echo "  Configuração Bluetooth para IoT"
echo "=========================================="

# Verifica se é root
if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute como root: sudo $0"
    exit 1
fi

# Instala pacotes necessários
echo "[1/5] Instalando pacotes..."
apt-get update
apt-get install -y bluetooth bluez bluez-tools rfkill

# Ativa Bluetooth
echo "[2/5] Ativando Bluetooth..."
rfkill unblock bluetooth
systemctl enable bluetooth
systemctl start bluetooth

# Configura HC-05 (baudrate 9600, nome "ArduinoIoT")
echo "[3/5] Configurando HC-05 (se conectado)..."
hciconfig hci0 up
hciconfig hci0 name "ArduinoIoT"
hciconfig hci0 class 0x200000

# Lista dispositivos
echo "[4/5] Dispositivos Bluetooth disponíveis:"
hcitool dev

# Mostra status
echo "[5/5] Status do Bluetooth:"
systemctl status bluetooth --no-pager

echo ""
echo "=========================================="
echo "  Bluetooth configurado!"
echo "  Para parear um dispositivo:"
echo "  bluetoothctl"
echo "    -> power on"
echo "    -> agent on"
echo "    -> scan on"
echo "    -> pair [MAC_ADDRESS]"
echo "=========================================="
