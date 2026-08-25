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

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.widget.ArrayAdapter;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Classe para gerenciar conexão Bluetooth com Arduino
 * @author Fábio Lapuinka
 */
public class BluetoothConnection {

    // Interface de Callback
    public interface BluetoothConnectionListener {
        void onConnect(String deviceName);
        void onMessageReceive(String message);
        void onConnectionError(String error);
        void onDisconnect();
    }

    // Constantes
    private static final UUID SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");
    public static final int REQUEST_BLUETOOTH_PERMISSION = 1000;

    // Códigos de mensagem do Handler
    private static final int MSG_CONNECT_SUCCESS = 1001;
    private static final int MSG_CONNECT_ERROR = 1002;
    private static final int MSG_MESSAGE_RECEIVED = 1003;
    private static final int MSG_DISCONNECT = 1004;

    // Variáveis
    private Activity context;
    private BluetoothConnectionListener listener;
    private BluetoothAdapter bluetoothAdapter;
    private BluetoothSocket bluetoothSocket;
    private OutputStream outputStream;
    private InputStream inputStream;
    private boolean connected;
    private ProgressDialog progressDialog;
    private String receivedMessageBuffer = "";
    private String currentDeviceName = "";

    // Handler para sincronizar com a UI Thread
    private Handler handler = new Handler(Looper.getMainLooper()) {
        @Override
        public void handleMessage(Message msg) {
            if (progressDialog != null && progressDialog.isShowing()) {
                progressDialog.dismiss();
            }

            switch (msg.what) {
                case MSG_CONNECT_SUCCESS:
                    if (listener != null) {
                        listener.onConnect(currentDeviceName);
                    }
                    break;
                case MSG_CONNECT_ERROR:
                    if (listener != null) {
                        listener.onConnectionError((String) msg.obj);
                    }
                    break;
                case MSG_MESSAGE_RECEIVED:
                    if (listener != null) {
                        listener.onMessageReceive((String) msg.obj);
                    }
                    break;
                case MSG_DISCONNECT:
                    if (listener != null) {
                        listener.onDisconnect();
                    }
                    break;
            }
        }
    };

    public BluetoothConnection(Activity context, BluetoothConnectionListener listener) {
        this.context = context;
        this.listener = listener;
        this.bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
    }

    /**
     * Inicia o processo de conexão Bluetooth
     */
    public void connect() {
        if (listener == null) return;

        // Verifica permissões (Android 6.0+)
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH)
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(context,
                    new String[]{Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN},
                    REQUEST_BLUETOOTH_PERMISSION);
            listener.onConnectionError("Permissão Bluetooth não concedida");
            return;
        }

        // Verifica se o adaptador Bluetooth existe e está ativo
        if (bluetoothAdapter == null) {
            listener.onConnectionError("Dispositivo não suporta Bluetooth");
            return;
        }

        if (!bluetoothAdapter.isEnabled()) {
            listener.onConnectionError("Bluetooth desativado. Ative o Bluetooth nas configurações.");
            return;
        }

        // Lista dispositivos pareados
        showDeviceListDialog();
    }

    /**
     * Exibe diálogo com dispositivos Bluetooth pareados
     */
    private void showDeviceListDialog() {
        Set<BluetoothDevice> pairedDevices = bluetoothAdapter.getBondedDevices();
        
        if (pairedDevices == null || pairedDevices.isEmpty()) {
            listener.onConnectionError("Nenhum dispositivo Bluetooth pareado encontrado");
            return;
        }

        List<String> deviceNames = new ArrayList<>();
        final List<BluetoothDevice> deviceList = new ArrayList<>();

        for (BluetoothDevice device : pairedDevices) {
            deviceNames.add(device.getName() + "\n" + device.getAddress());
            deviceList.add(device);
        }

        ArrayAdapter<String> adapter = new ArrayAdapter<>(
                context, android.R.layout.select_dialog_item, deviceNames);

        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setTitle("Selecione o dispositivo Bluetooth");
        builder.setCancelable(false);
        builder.setAdapter(adapter, (dialog, which) -> {
            BluetoothDevice selectedDevice = deviceList.get(which);
            connectToDevice(selectedDevice);
            dialog.dismiss();
        });
        builder.setNegativeButton("Cancelar", (dialog, which) -> dialog.dismiss());
        builder.create().show();
    }

    /**
     * Conecta a um dispositivo Bluetooth específico
     */
    private void connectToDevice(BluetoothDevice device) {
        currentDeviceName = device.getName();
        progressDialog = ProgressDialog.show(context, 
                "Conectando", 
                "Conectando ao dispositivo " + device.getName() + "...", 
                true, false);

        new Thread(() -> {
            try {
                bluetoothSocket = device.createRfcommSocketToServiceRecord(SPP_UUID);
                bluetoothSocket.connect();
                connected = true;

                outputStream = bluetoothSocket.getOutputStream();
                inputStream = bluetoothSocket.getInputStream();

                handler.sendEmptyMessage(MSG_CONNECT_SUCCESS);

                // Inicia thread para receber dados
                receiveData();

            } catch (Exception e) {
                connected = false;
                Message msg = handler.obtainMessage(MSG_CONNECT_ERROR, e.getMessage());
                handler.sendMessage(msg);
            }
        }).start();
    }

    /**
     * Thread para receber dados do Arduino
     */
    private void receiveData() {
        new Thread(() -> {
            byte[] buffer = new byte[1024];
            int bytesRead;

            try {
                while (connected) {
                    if (inputStream.available() > 0) {
                        bytesRead = inputStream.read(buffer);
                        String message = new String(buffer, 0, bytesRead);
                        processReceivedMessage(message);
                    }
                }
            } catch (Exception e) {
                if (connected) {
                    connected = false;
                    handler.sendEmptyMessage(MSG_DISCONNECT);
                }
            }
        }).start();
    }

    /**
     * Processa mensagens recebidas (separadas por \n)
     */
    private void processReceivedMessage(String message) {
        receivedMessageBuffer += message;

        while (receivedMessageBuffer.contains("\n")) {
            int newlineIndex = receivedMessageBuffer.indexOf("\n");
            String line = receivedMessageBuffer.substring(0, newlineIndex).trim();
            receivedMessageBuffer = receivedMessageBuffer.substring(newlineIndex + 1);

            if (!line.isEmpty()) {
                Message msg = handler.obtainMessage(MSG_MESSAGE_RECEIVED, line);
                handler.sendMessage(msg);
            }
        }
    }

    /**
     * Envia dados para o Arduino
     */
    public boolean sendData(String message) {
        if (!connected || outputStream == null) {
            return false;
        }

        try {
            outputStream.write((message + "\n").getBytes());
            outputStream.flush();
            return true;
        } catch (Exception e) {
            connected = false;
            handler.sendEmptyMessage(MSG_DISCONNECT);
            return false;
        }
    }

    /**
     * Envia comando para controlar uma lâmpada
     */
    public boolean sendLedCommand(int ledNumber, int value) {
        // Garante que o valor está entre 0 e 255
        int clampedValue = Math.max(0, Math.min(255, value));
        return sendData(ledNumber + ":" + clampedValue);
    }

    /**
     * Verifica se está conectado
     */
    public boolean isConnected() {
        return connected && bluetoothSocket != null && bluetoothSocket.isConnected();
    }

    /**
     * Desconecta
     */
    public void disconnect() {
        connected = false;
        try {
            if (outputStream != null) outputStream.close();
            if (inputStream != null) inputStream.close();
            if (bluetoothSocket != null) bluetoothSocket.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
        handler.sendEmptyMessage(MSG_DISCONNECT);
    }

    /**
     * Obtém o nome do dispositivo conectado
     */
    public String getCurrentDeviceName() {
        return currentDeviceName;
    }
}
