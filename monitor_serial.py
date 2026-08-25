#!/usr/bin/env python3
# ============================================================
# Monitor Serial para debug do Arduino via Bluetooth (RFCOMM)
# Autor: Fábio Lapuinka
# ============================================================

import serial
import time
import sys
import threading

# Configurações
BLUETOOTH_PORT = "/dev/rfcomm0"  # ou "/dev/ttyUSB0" para USB
BAUDRATE = 9600
TIMEOUT = 1

class ArduinoMonitor:
    def __init__(self, port=BLUETOOTH_PORT, baudrate=BAUDRATE):
        self.port = port
        self.baudrate = baudrate
        self.serial = None
        self.running = False
        
    def connect(self):
        """Conecta ao Arduino via Bluetooth"""
        try:
            self.serial = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=TIMEOUT
            )
            self.running = True
            print(f"✅ Conectado a {self.port}")
            return True
        except Exception as e:
            print(f"❌ Erro ao conectar: {e}")
            return False
    
    def disconnect(self):
        """Desconecta"""
        self.running = False
        if self.serial and self.serial.is_open:
            self.serial.close()
            print("🔌 Desconectado")
    
    def send_command(self, command):
        """Envia comando para o Arduino"""
        if not self.serial or not self.serial
