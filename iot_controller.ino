/*
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
  You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
/*
 * Projeto IoT - Controle de Lâmpadas com Bluetooth
 * Autor: Fábio Leandro Lapuinka
 * Descrição: Controla 3 lâmpadas via Bluetooth (PWM)
 *           Envia dados de luminosidade e temperatura
 */

// ============================================================
// DEFINIÇÕES DOS PINOS
// ============================================================

// Lâmpadas (PWM)
const int LED_PIN_1 = 6;
const int LED_PIN_2 = 5;
const int LED_PIN_3 = 3;

// Ground dos LEDs (transistores)
const int LED_GRID_1 = 7;
const int LED_GRID_2 = 4;
const int LED_GRID_3 = 2;

// Sensores
const int SENSOR_LDR = A0;   // Luminosidade
const int SENSOR_TEMP = A1;  // Temperatura (LM35)

// ============================================================
// VARIÁVEIS GLOBAIS
// ============================================================

unsigned long lastSensorRead = 0;
const unsigned long SENSOR_INTERVAL = 1000; // 1 segundo entre leituras

// Valores atuais das lâmpadas (0-255)
int ledValues[3] = {0, 0, 0};

// ============================================================
// SETUP
// ============================================================

void setup() {
  // Configura pinos dos LEDs como saída
  pinMode(LED_PIN_1, OUTPUT);
  pinMode(LED_PIN_2, OUTPUT);
  pinMode(LED_PIN_3, OUTPUT);
  
  pinMode(LED_GRID_1, OUTPUT);
  pinMode(LED_GRID_2, OUTPUT);
  pinMode(LED_GRID_3, OUTPUT);
  
  // Inicializa grids com LOW (transistores desligados)
  digitalWrite(LED_GRID_1, LOW);
  digitalWrite(LED_GRID_2, LOW);
  digitalWrite(LED_GRID_3, LOW);

  // Configura sensores
  pinMode(SENSOR_LDR, INPUT);
  pinMode(SENSOR_TEMP, INPUT);
  
  // Inicializa Serial para comunicação Bluetooth (HC-05/HC-06)
  Serial.begin(9600);
  
  // Mensagem inicial
  Serial.println("Sistema IoT Inicializado");
  Serial.println("Aguardando conexão...");
}

// ============================================================
// LOOP PRINCIPAL
// ============================================================

void loop() {
  // 1. Verifica se há dados da Serial (Bluetooth)
  if (Serial.available() > 0) {
    processSerialCommand();
  }
  
  // 2. Lê sensores periodicamente
  unsigned long currentTime = millis();
  if (currentTime - lastSensorRead >= SENSOR_INTERVAL) {
    readAndSendSensors();
    lastSensorRead = currentTime;
  }
  
  // 3. Pequeno delay para estabilidade
  delay(10);
}

// ============================================================
// PROCESSAMENTO DE COMANDOS SERIAL
// ============================================================

void processSerialCommand() {
  String command = Serial.readStringUntil('\n');
  command.trim();
  
  if (command.length() == 0) return;
  
  // Comando: "1:255" -> Lâmpada 1 com intensidade 255
  // Comando: "2:128" -> Lâmpada 2 com intensidade 128
  // Comando: "3:0"   -> Lâmpada 3 desligada
  
  int colonIndex = command.indexOf(':');
  if (colonIndex > 0) {
    int ledNumber = command.substring(0, colonIndex).toInt();
    int value = command.substring(colonIndex + 1).toInt();
    
    // Valida número do LED (1-3)
    if (ledNumber >= 1 && ledNumber <= 3) {
      // Garante valor entre 0 e 255
      value = constrain(value, 0, 255);
      
      // Atualiza array de valores
      ledValues[ledNumber - 1] = value;
      
      // Aplica ao LED correspondente
      setLed(ledNumber, value);
    }
  }
}

// ============================================================
// CONTROLE DE LEDS
// ============================================================

void setLed(int ledNumber, int value) {
  // Mapeia valor de 0-255 para melhor resposta visual
  // (Ajuste aqui se os LEDs tiverem resposta não-linear)
  int pwmValue = value;
  
  switch (ledNumber) {
    case 1:
      analogWrite(LED_PIN_1, pwmValue);
      digitalWrite(LED_GRID_1, value > 0 ? HIGH : LOW);
      break;
    case 2:
      analogWrite(LED_PIN_2, pwmValue);
      digitalWrite(LED_GRID_2, value > 0 ? HIGH : LOW);
      break;
    case 3:
      analogWrite(LED_PIN_3, pwmValue);
      digitalWrite(LED_GRID_3, value > 0 ? HIGH : LOW);
      break;
  }
}

// ============================================================
// LEITURA E ENVIO DE DADOS DOS SENSORES
// ============================================================

void readAndSendSensors() {
  // Lê luminosidade (0-1023)
  int ldrValue = analogRead(SENSOR_LDR);
  
  // Lê temperatura (LM35: 10mV/°C)
  int tempRaw = analogRead(SENSOR_TEMP);
  float voltage = (tempRaw / 1023.0) * 5000.0; // 5000mV = 5V
  float temperatureC = voltage / 10.0; // 10mV por grau Celsius
  
  // Envia dados formatados
  Serial.print("ldr:");
  Serial.println(ldrValue);
  
  Serial.print("temp:");
  Serial.println((int)temperatureC);
}

// ============================================================
// COMANDO ESPECIAL: DESLIGAR TUDO (via Serial)
// ============================================================

// Função auxiliar para desligar todos os LEDs
void turnOffAllLeds() {
  for (int i = 1; i <= 3; i++) {
    ledValues[i - 1] = 0;
    setLed(i, 0);
  }
  Serial.println("Todos os LEDs desligados");
}
