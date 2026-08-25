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
package com.iot.lpk.projetoiot;

import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.view.View;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends AppCompatActivity 
        implements SeekBar.OnSeekBarChangeListener {

    // UI Components
    private TextView lblStatus, txtTemperatura, txtLuminosidade;
    private TextView txtValor1, txtValor2, txtValor3;
    private SeekBar bar1, bar2, bar3;
    private ProgressBar progressLuminosidade;
    private Button btnConectar, btnDesconectar, btnToggleAll;

    // Bluetooth
    private BluetoothConnection bluetoothConnection;
    private boolean isConnected = false;
    private boolean allLedsOn = false;

    // Valores atuais das lâmpadas
    private int ledValue1 = 0, ledValue2 = 0, ledValue3 = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        initUI();
        initBluetooth();
    }

    private void initUI() {
        // TextViews
        lblStatus = findViewById(R.id.lblStatus);
        txtTemperatura = findViewById(R.id.txtTemperatura);
        txtLuminosidade = findViewById(R.id.txtLuminosidade);
        txtValor1 = findViewById(R.id.txtValor1);
        txtValor2 = findViewById(R.id.txtValor2);
        txtValor3 = findViewById(R.id.txtValor3);

        // SeekBars
        bar1 = findViewById(R.id.bar1);
        bar2 = findViewById(R.id.bar2);
        bar3 = findViewById(R.id.bar3);
        
        bar1.setMax(255);
        bar2.setMax(255);
        bar3.setMax(255);
        
        bar1.setOnSeekBarChangeListener(this);
        bar2.setOnSeekBarChangeListener(this);
        bar3.setOnSeekBarChangeListener(this);

        // ProgressBar
        progressLuminosidade = findViewById(R.id.progressLuminosidade);
        progressLuminosidade.setMax(1023);

        // Buttons
        btnConectar = findViewById(R.id.btnConectar);
        btnDesconectar = findViewById(R.id.btnDesconectar);
        btnToggleAll = findViewById(R.id.btnToggleAll);

        btnConectar.setOnClickListener(v -> {
            if (bluetoothConnection != null) {
                bluetoothConnection.connect();
            }
        });

        btnDesconectar.setOnClickListener(v -> {
            if (bluetoothConnection != null) {
                bluetoothConnection.disconnect();
                updateConnectionStatus(false);
            }
        });

        btnToggleAll.setOnClickListener(v -> toggleAllLeds());
    }

    private void initBluetooth() {
        bluetoothConnection = new BluetoothConnection(this, 
            new BluetoothConnection.BluetoothConnectionListener() {
                @Override
                public void onConnect(String deviceName) {
                    runOnUiThread(() -> {
                        updateConnectionStatus(true);
                        Toast.makeText(MainActivity.this, 
                            "Conectado a: " + deviceName, Toast.LENGTH_SHORT).show();
                    });
                }

                @Override
                public void onMessageReceive(String message) {
                    runOnUiThread(() -> processReceivedData(message));
                }

                @Override
                public void onConnectionError(String error) {
                    runOnUiThread(() -> {
                        updateConnectionStatus(false);
                        Toast.makeText(MainActivity.this, 
                            "Erro: " + error, Toast.LENGTH_LONG).show();
                    });
                }

                @Override
                public void onDisconnect() {
                    runOnUiThread(() -> {
                        updateConnectionStatus(false);
                        Toast.makeText(MainActivity.this, 
                            "Desconectado", Toast.LENGTH_SHORT).show();
                    });
                }
            });
    }

    private void processReceivedData(String message) {
        if (message.startsWith("ldr:")) {
            try {
                int value = Integer.parseInt(message.substring(4));
                progressLuminosidade.setProgress(value);
                txtLuminosidade.setText(String.valueOf(value));
            } catch (NumberFormatException e) {
                // Ignora
            }
        } else if (message.startsWith("temp:")) {
            try {
                int value = Integer.parseInt(message.substring(5));
                txtTemperatura.setText(value + " °C");
            } catch (NumberFormatException e) {
                // Ignora
            }
        } else {
            // Mensagem desconhecida
            // Toast.makeText(this, "Recebido: " + message, Toast.LENGTH_SHORT).show();
        }
    }

    private void updateConnectionStatus(boolean connected) {
        isConnected = connected;
        if (connected) {
            lblStatus.setText("✅ Conectado");
            lblStatus.setTextColor(getResources().getColor(android.R.color.holo_green_dark));
            btnConectar.setEnabled(false);
            btnDesconectar.setEnabled(true);
            bar1.setEnabled(true);
            bar2.setEnabled(true);
            bar3.setEnabled(true);
            btnToggleAll.setEnabled(true);
        } else {
            lblStatus.setText("❌ Desconectado");
            lblStatus.setTextColor(getResources().getColor(android.R.color.holo_red_dark));
            btnConectar.setEnabled(true);
            btnDesconectar.setEnabled(false);
            bar1.setEnabled(false);
            bar2.setEnabled(false);
            bar3.setEnabled(false);
            btnToggleAll.setEnabled(false);
        }
    }

    @Override
    public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
        if (!isConnected || !fromUser) return;

        int id = seekBar.getId();
        int ledNumber;
        String label;

        if (id == R.id.bar1) {
            ledNumber = 1;
            label = "L1: ";
            txtValor1.setText(progress + " (" + (progress * 100 / 255) + "%)");
            ledValue1 = progress;
        } else if (id == R.id.bar2) {
            ledNumber = 2;
            label = "L2: ";
            txtValor2.setText(progress + " (" + (progress * 100 / 255) + "%)");
            ledValue2 = progress;
        } else if (id == R.id.bar3) {
            ledNumber = 3;
            label = "L3: ";
            txtValor3.setText(progress + " (" + (progress * 100 / 255) + "%)");
            ledValue3 = progress;
        } else {
            return;
        }

        bluetoothConnection.sendLedCommand(ledNumber, progress);
    }

    @Override
    public void onStartTrackingTouch(SeekBar seekBar) {
        // Não necessário
    }

    @Override
    public void onStopTrackingTouch(SeekBar seekBar) {
        // Não necessário - mantido para compatibilidade
    }

    private void toggleAllLeds() {
        if (!isConnected) return;

        allLedsOn = !allLedsOn;
        int targetValue = allLedsOn ? 255 : 0;

        // Atualiza UI
        bar1.setProgress(targetValue);
        bar2.setProgress(targetValue);
        bar3.setProgress(targetValue);
        
        txtValor1.setText(targetValue + " (100%)");
        txtValor2.setText(targetValue + " (100%)");
        txtValor3.setText(targetValue + " (100%)");

        // Envia comandos
        bluetoothConnection.sendLedCommand(1, targetValue);
        bluetoothConnection.sendLedCommand(2, targetValue);
        bluetoothConnection.sendLedCommand(3, targetValue);

        btnToggleAll.setText(allLedsOn ? "💡 Desligar Todos" : "💡 Ligar Todos");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (bluetoothConnection != null) {
            bluetoothConnection.disconnect();
        }
    }
}
