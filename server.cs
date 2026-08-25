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


// ================================================================
// ARQUIVO: UnitySocketServer.cs
// DESCRIÇÃO: Código completo para comunicação TCP com Unity,
// incluindo servidor, cliente, utilitários e gerenciador de rede.
// AUTOR: Fábio Lapuinka
// DATA: 2024
// ================================================================

using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

// ================================================================
// 1. GERENCIADOR DE REDE UNITY (LEGADO)
// ================================================================

/// <summary>
/// Gerencia conexões de rede usando o sistema legado do Unity (NetworkPeerType).
/// Útil para jogos multiplayer simples com MasterServer.
/// </summary>
public class UnityNetworkManager : MonoBehaviour
{
    [Header("Server Settings")]
    [SerializeField] private int serverPort = 1433;
    [SerializeField] private bool useNat = false;
    [SerializeField] private string gameName = "testeunity";
    [SerializeField] private string gameComment = "l33t game for all";
    [SerializeField] private int maxPlayers = 32;

    private float lastHostListRequest;
    private float hostListRefreshTimeout = 10f;
    private int playerCount;

    private void OnGUI()
    {
        GUILayout.BeginArea(new Rect(10, 10, 200, 300));
        
        if (Network.peerType == NetworkPeerType.Disconnected)
        {
            if (GUILayout.Button("Start Server"))
            {
                StartServer();
            }
            
            if (GUILayout.Button("Refresh Hosts"))
            {
                RefreshHosts();
            }
        }
        else if (Network.peerType == NetworkPeerType.Server)
        {
            GUILayout.Label($"Server running. Players: {playerCount}");
            if (GUILayout.Button("Stop Server"))
            {
                StopServer();
            }
        }
        else if (Network.peerType == NetworkPeerType.Client)
        {
            GUILayout.Label("Connected as client");
            if (GUILayout.Button("Disconnect"))
            {
                Disconnect();
            }
        }
        
        GUILayout.EndArea();
    }

    public void StartServer()
    {
        if (Network.peerType == NetworkPeerType.Disconnected)
        {
            Network.InitializeServer(maxPlayers, serverPort, useNat);
            MasterServer.RegisterHost(gameName, gameComment);
            Debug.Log($"Server started on port {serverPort}");
        }
    }

    public void StopServer()
    {
        Network.Disconnect();
        MasterServer.UnregisterHost();
        Debug.Log("Server stopped");
    }

    public void RefreshHosts()
    {
        if (Time.realtimeSinceStartup > lastHostListRequest + hostListRefreshTimeout)
        {
            MasterServer.RequestHostList(gameName);
            lastHostListRequest = Time.realtimeSinceStartup;
            Debug.Log("Refreshing host list...");
        }
    }

    public void Disconnect()
    {
        Network.Disconnect();
        Debug.Log("Disconnected");
    }

    #region Unity Network Callbacks

    private void OnFailedToConnectToMasterServer(NetworkConnectionError info)
    {
        Debug.LogError($"Failed to connect to MasterServer: {info}");
    }

    private void OnFailedToConnect(NetworkConnectionError info)
    {
        Debug.LogError($"Failed to connect: {info}");
    }

    private void OnConnectedToServer()
    {
        Debug.Log("Connected to server");
    }

    private void OnDisconnectedFromServer(NetworkDisconnection info)
    {
        if (Network.isServer)
            Debug.Log("Local server connection disconnected");
        else if (info == NetworkDisconnection.LostConnection)
            Debug.Log("Lost connection to the server");
        else
            Debug.Log("Successfully disconnected from the server");
    }

    private void OnPlayerConnected(NetworkPlayer player)
    {
        playerCount++;
        Debug.Log($"Player {playerCount} connected from {player.ipAddress}:{player.port}");
    }

    private void OnPlayerDisconnected(NetworkPlayer player)
    {
        playerCount--;
        Debug.Log($"Clean up after player {player}");
        Network.RemoveRPCs(player);
        Network.DestroyPlayerObjects(player);
    }

    #endregion
}

// ================================================================
// 2. DISPATCHER PARA THREAD PRINCIPAL
// ================================================================

/// <summary>
/// Permite executar ações na thread principal do Unity a partir de threads secundárias.
/// </summary>
public class UnityMainThreadDispatcher : MonoBehaviour
{
    private static UnityMainThreadDispatcher instance;
    private readonly Queue<Action> actions = new Queue<Action>();
    private readonly object lockObject = new object();

    public static UnityMainThreadDispatcher Instance
    {
        get
        {
            if (instance == null)
            {
                GameObject go = new GameObject("UnityMainThreadDispatcher");
                instance = go.AddComponent<UnityMainThreadDispatcher>();
                DontDestroyOnLoad(go);
            }
            return instance;
        }
    }

    private void Update()
    {
        lock (lockObject)
        {
            while (actions.Count > 0)
            {
                actions.Dequeue()?.Invoke();
            }
        }
    }

    public void Enqueue(Action action)
    {
        lock (lockObject)
        {
            actions.Enqueue(action);
        }
    }
}

// ================================================================
// 3. SERVIDOR TCP
// ================================================================

/// <summary>
/// Servidor TCP que aceita múltiplas conexões e cria uma thread para cada cliente.
/// </summary>
public class TcpSocketServer : MonoBehaviour
{
    [Header("Server Settings")]
    [SerializeField] private int port = 13000;
    [SerializeField] private string ipAddress = "127.0.0.1";

    private TcpListener server;
    private Thread serverThread;
    private bool isRunning;

    private void Start()
    {
        StartServer();
    }

    private void OnDestroy()
    {
        StopServer();
    }

    public void StartServer()
    {
        if (isRunning) return;

        serverThread = new Thread(RunServer);
        serverThread.IsBackground = true;
        serverThread.Start();
        isRunning = true;
        
        Debug.Log($"TCP Server started on {ipAddress}:{port}");
    }

    public void StopServer()
    {
        isRunning = false;
        server?.Stop();
        serverThread?.Join(1000);
        Debug.Log("TCP Server stopped");
    }

    private void RunServer()
    {
        try
        {
            IPAddress localAddr = IPAddress.Parse(ipAddress);
            server = new TcpListener(localAddr, port);
            server.Start();

            while (isRunning)
            {
                Debug.Log("Waiting for a connection...");
                TcpClient client = server.AcceptTcpClient();
                Debug.Log($"Client connected from {client.Client.RemoteEndPoint}");

                TcpClientHandler handler = new TcpClientHandler(client);
                Thread clientThread = new Thread(handler.HandleClient);
                clientThread.IsBackground = true;
                clientThread.Start();
            }
        }
        catch (SocketException e)
        {
            Debug.LogError($"SocketException: {e.Message}");
        }
        finally
        {
            server?.Stop();
        }
    }
}

// ================================================================
// 4. HANDLER DE CLIENTE TCP
// ================================================================

/// <summary>
/// Gerencia a comunicação com um único cliente TCP.
/// </summary>
public class TcpClientHandler
{
    private readonly TcpClient client;
    private NetworkStream stream;
    private bool isConnected;

    public TcpClientHandler(TcpClient client)
    {
        this.client = client;
        this.stream = client.GetStream();
        this.isConnected = true;
    }

    public void HandleClient()
    {
        byte[] buffer = new byte[256];
        string data = string.Empty;

        try
        {
            while (isConnected && client.Connected)
            {
                int bytesRead = stream.Read(buffer, 0, buffer.Length);
                
                if (bytesRead == 0) break;

                string received = Encoding.ASCII.GetString(buffer, 0, bytesRead);
                data += received;

                while (data.Contains("\n"))
                {
                    int newlineIndex = data.IndexOf("\n");
                    string line = data.Substring(0, newlineIndex);
                    data = data.Substring(newlineIndex + 1);

                    ProcessMessage(line);
                }
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"Client handler error: {e.Message}");
        }
        finally
        {
            Close();
        }
    }

    private void ProcessMessage(string message)
    {
        Debug.Log($"Received: {message}");

        // Exemplo: echo com uppercase
        string response = message.ToUpper();
        SendMessage(response);
    }

    public void SendMessage(string message)
    {
        try
        {
            if (!isConnected || !client.Connected) return;

            byte[] data = Encoding.ASCII.GetBytes(message + "\n");
            stream.Write(data, 0, data.Length);
            Debug.Log($"Sent: {message}");
        }
        catch (Exception e)
        {
            Debug.LogError($"Send error: {e.Message}");
        }
    }

    public void Close()
    {
        isConnected = false;
        stream?.Close();
        client?.Close();
        Debug.Log("Client connection closed");
    }
}

// ================================================================
// 5. CLIENTE TCP
// ================================================================

/// <summary>
/// Cliente TCP que se conecta a um servidor e envia/recebe mensagens.
/// </summary>
public class TcpSocketClient : MonoBehaviour
{
    [Header("Connection Settings")]
    [SerializeField] private string serverIp = "127.0.0.1";
    [SerializeField] private int serverPort = 13000;

    private TcpClient client;
    private NetworkStream stream;
    private Thread receiveThread;
    private bool isConnected;

    public event Action<string> OnMessageReceived;

    private void Start()
    {
        Connect();
    }

    private void OnDestroy()
    {
        Disconnect();
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space))
        {
            SendMessage($"Hello from Unity! Time: {Time.time}");
        }
    }

    public void Connect()
    {
        if (isConnected) return;

        try
        {
            client = new TcpClient(serverIp, serverPort);
            stream = client.GetStream();
            isConnected = true;

            receiveThread = new Thread(ReceiveMessages);
            receiveThread.IsBackground = true;
            receiveThread.Start();

            Debug.Log($"Connected to {serverIp}:{serverPort}");
        }
        catch (Exception e)
        {
            Debug.LogError($"Connection failed: {e.Message}");
        }
    }

    public void Disconnect()
    {
        isConnected = false;
        receiveThread?.Join(500);
        stream?.Close();
        client?.Close();
        Debug.Log("Disconnected");
    }

    public void SendMessage(string message)
    {
        if (!isConnected || !client.Connected)
        {
            Debug.LogWarning("Not connected");
            return;
        }

        try
        {
            byte[] data = Encoding.ASCII.GetBytes(message + "\n");
            stream.Write(data, 0, data.Length);
            Debug.Log($"Sent: {message}");
        }
        catch (Exception e)
        {
            Debug.LogError($"Send error: {e.Message}");
        }
    }

    private void ReceiveMessages()
    {
        byte[] buffer = new byte[256];
        string data = string.Empty;

        try
        {
            while (isConnected && client.Connected)
            {
                int bytesRead = stream.Read(buffer, 0, buffer.Length);
                
                if (bytesRead == 0) break;

                string received = Encoding.ASCII.GetString(buffer, 0, bytesRead);
                data += received;

                while (data.Contains("\n"))
                {
                    int newlineIndex = data.IndexOf("\n");
                    string line = data.Substring(0, newlineIndex);
                    data = data.Substring(newlineIndex + 1);

                    UnityMainThreadDispatcher.Instance?.Enqueue(() =>
                    {
                        Debug.Log($"Received: {line}");
                        OnMessageReceived?.Invoke(line);
                    });
                }
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"Receive error: {e.Message}");
        }
        finally
        {
            if (isConnected)
            {
                UnityMainThreadDispatcher.Instance?.Enqueue(Disconnect);
            }
        }
    }
}

// ================================================================
// 6. UTILITÁRIOS DE CENA
// ================================================================

/// <summary>
/// Utilitários para manipulação de cenas, objetos 3D, câmera e meshes.
/// </summary>
public static class SceneUtils
{
    private static Camera activeCamera;
    public static float HorzFOV { get; private set; }
    public static float VertFOV { get; private set; }
    public static float NearClipPlane { get; private set; }
    public static float FarClipPlane { get; private set; }
    public static float Aspect { get; private set; }

    #region Bounds

    public static Vector3[] GetMinMaxBounds(Transform root)
    {
        bool first = true;
        Vector3 min = Vector3.zero;
        Vector3 max = Vector3.zero;

        Renderer[] renderers = root.GetComponentsInChildren<Renderer>();
        
        foreach (Renderer renderer in renderers)
        {
            Vector3 localMin, localMax;

            if (renderer is SkinnedMeshRenderer smr)
            {
                localMin = root.InverseTransformPoint(smr.bounds.min);
                localMax = root.InverseTransformPoint(smr.bounds.max);
            }
            else if (renderer is MeshRenderer)
            {
                TextMesh textMesh = renderer.GetComponent<TextMesh>();
                if (textMesh != null)
                {
                    Quaternion savedRotation = textMesh.transform.localRotation;
                    textMesh.transform.localRotation = Quaternion.identity;
                    
                    localMin = root.InverseTransformPoint(renderer.bounds.min);
                    localMax = root.InverseTransformPoint(renderer.bounds.max);
                    
                    textMesh.transform.localRotation = savedRotation;
                }
                else
                {
                    MeshFilter mf = renderer.GetComponent<MeshFilter>();
                    if (mf != null && mf.sharedMesh != null)
                    {
                        localMin = Vector3.positiveInfinity;
                        localMax = Vector3.negativeInfinity;

                        foreach (Vector3 vertex in mf.sharedMesh.vertices)
                        {
                            Vector3 worldPos = renderer.transform.TransformPoint(vertex);
                            Vector3 localPos = root.InverseTransformPoint(worldPos);
                            
                            localMin = Vector3.Min(localMin, localPos);
                            localMax = Vector3.Max(localMax, localPos);
                        }
                    }
                    else continue;
                }
            }
            else continue;

            if (first)
            {
                min = localMin;
                max = localMax;
                first = false;
            }
            else
            {
                min = Vector3.Min(min, localMin);
                max = Vector3.Max(max, localMax);
            }
        }

        return new[] { min, max };
    }

    #endregion

    #region Mesh Creation

    public static Mesh CreatePlaneMesh(float height)
    {
        Mesh mesh = new Mesh
        {
            vertices = new Vector3[]
            {
                new Vector3(1, 0, height),
                new Vector3(1, 0, 0),
                new Vector3(0, 0, height),
                new Vector3(0, 0, 0)
            },
            uv = new Vector2[]
            {
                new Vector2(1, 1),
                new Vector2(1, 0),
                new Vector2(0, 1),
                new Vector2(0, 0)
            },
            triangles = new int[] { 0, 1, 2, 2, 1, 3 }
        };
        
        mesh.RecalculateNormals();
        return mesh;
    }

    public static Mesh CreatePlaneMeshCentered(float halfSize = 0.5f)
    {
        Mesh mesh = new Mesh
        {
            vertices = new Vector3[]
            {
                new Vector3(halfSize, 0, halfSize),
                new Vector3(halfSize, 0, -halfSize),
                new Vector3(-halfSize, 0, halfSize),
                new Vector3(-halfSize, 0, -halfSize)
            },
            uv = new Vector2[]
            {
                new Vector2(1, 1),
                new Vector2(1, 0),
                new Vector2(0, 1),
                new Vector2(0, 0)
            },
            triangles = new int[] { 0, 1, 2, 2, 1, 3 }
        };
        
        mesh.RecalculateNormals();
        return mesh;
    }

    public static GameObject CreatePlaneObject(Material material, bool centered = false)
    {
        GameObject go = new GameObject("PlaneObject");
        MeshFilter mf = go.AddComponent<MeshFilter>();
        MeshRenderer mr = go.AddComponent<MeshRenderer>();

        mf.mesh = centered ? CreatePlaneMeshCentered() : CreatePlaneMesh(1f);
        mr.material = material;

        return go;
    }

    #endregion

    #region Camera Utils

    public static void UpdateCameraFOV(Camera cam)
    {
        activeCamera = cam;
        NearClipPlane = cam.nearClipPlane;
        FarClipPlane = cam.farClipPlane;
        Aspect = cam.aspect;

        Vector3 bottom = cam.ScreenToWorldPoint(new Vector3(0, 0, 1));
        Vector3 top = cam.ScreenToWorldPoint(new Vector3(0, Screen.height - 1, 1));
        VertFOV = Mathf.Rad2Deg * 2 * Mathf.Atan((top - bottom).magnitude / 2);

        Vector3 left = cam.ScreenToWorldPoint(new Vector3(0, 0, 1));
        Vector3 right = cam.ScreenToWorldPoint(new Vector3(Screen.width - 1, 0, 1));
        HorzFOV = Mathf.Rad2Deg * 2 * Mathf.Atan((right - left).magnitude / 2);
    }

    public static float GetWorldSizeX(float distanceZ)
    {
        return 2f * distanceZ * Mathf.Tan((HorzFOV / 2f) * Mathf.Deg2Rad);
    }

    public static float GetWorldSizeY(float distanceZ)
    {
        return 2f * distanceZ * Mathf.Tan((VertFOV / 2f) * Mathf.Deg2Rad);
    }

    public static float DistanceZToWorldX(float worldX)
    {
        return (worldX / 2f) / Mathf.Tan((HorzFOV / 2f) * Mathf.Deg2Rad);
    }

    public static float DistanceZToWorldY(float worldY)
    {
        return (worldY / 2f) / Mathf.Tan((VertFOV / 2f) * Mathf.Deg2Rad);
    }

    #endregion

    #region Object Manipulation

    public static void SetObjectVisibility(GameObject go, bool visible)
    {
        foreach (Renderer r in go.GetComponentsInChildren<Renderer>())
            r.enabled = visible;
        foreach (Collider c in go.GetComponentsInChildren<Collider>())
            c.enabled = visible;
    }

    public static void ScaleObjectToWidth(GameObject obj, float targetWidth)
    {
        Vector3[] bounds = GetMinMaxBounds(obj.transform);
        float currentWidth = bounds[1].x - bounds[0].x;
        
        if (currentWidth > 0)
        {
            float scale = targetWidth / currentWidth;
            obj.transform.localScale *= scale;
        }
    }

    public static void AdjustObjectWidthTo(GameObject mainobj, float finalWidth)
    {
        MeshFilter mf = mainobj.transform.GetComponent<MeshFilter>();
        if (mf == null)
        {
            Debug.Log("marcador nao tem meshFilter");
            return;
        }

        Vector3 leftbottom = mainobj.transform.position;
        Vector3 righttop = mainobj.transform.position;
        bool first = true;

        if (mf == null)
        {
            foreach (MeshFilter mf2 in mainobj.GetComponentsInChildren<MeshFilter>())
            {
                Bounds b = mf2.sharedMesh.bounds;
                Vector3 bc = b.center;
                Vector3 b1 = b.size / 2;

                Vector3 p1 = mf2.transform.TransformPoint(bc - b1);
                Vector3 p2 = mf2.transform.TransformPoint(bc + b1);
                Vector3 p3 = Vector3.Min(p1, p2);
                Vector3 p4 = Vector3.Max(p1, p2);
                
                if (first)
                {
                    first = false;
                    leftbottom = p3;
                    righttop = p4;
                }
                else
                {
                    leftbottom = Vector3.Min(leftbottom, p3);
                    righttop = Vector3.Max(righttop, p4);
                }
            }
        }
        else
        {
            Bounds b = mf.sharedMesh.bounds;
            Vector3 bc = b.center;
            Vector3 b1 = b.size / 2;

            leftbottom = mainobj.transform.TransformPoint(bc - b1);
            righttop = mainobj.transform.TransformPoint(bc + b1);
        }

        float oldx = (righttop - leftbottom).x;
        float scale = finalWidth / oldx;
        mainobj.transform.localScale = mainobj.transform.localScale * scale;
    }

    #endregion

    #region UV Adjustment

    public static void SetPlaneUV(GameObject plane, float x1, float y1, float x2, float y2)
    {
        Mesh mesh = plane.GetComponent<MeshFilter>()?.sharedMesh;
        if (mesh == null) return;

        mesh.uv = new Vector2[]
        {
            new Vector2(x2, y2),
            new Vector2(x2, y1),
            new Vector2(x1, y2),
            new Vector2(x1, y1)
        };
        mesh.RecalculateBounds();
    }

    public static void AdjustPlaneUV(GameObject go, float x1, float y1, float x2, float y2)
    {
        Mesh mesh = go.GetComponent<MeshFilter>()?.sharedMesh;
        if (mesh == null) return;

        mesh.uv = new Vector2[]
        {
            new Vector2(x2, y2),
            new Vector2(x2, y1),
            new Vector2(x1, y2),
            new Vector2(x1, y1)
        };
        mesh.RecalculateBounds();
    }

    #endregion

    #region Border Creation

    public static void CreateBorderObjects(GameObject mainobj, Material material)
    {
        MeshFilter mf = mainobj.transform.GetComponent<MeshFilter>();
        Vector3 leftbottom = mainobj.transform.position;
        Vector3 righttop = mainobj.transform.position;
        bool first = true;

        if (mf == null)
        {
            foreach (MeshFilter mf2 in mainobj.GetComponentsInChildren<MeshFilter>())
            {
                Bounds b = mf2.sharedMesh.bounds;
                Vector3 bc = b.center;
                Vector3 b1 = b.size / 2;

                Vector3 p1 = mf2.transform.TransformPoint(bc - b1);
                Vector3 p2 = mf2.transform.TransformPoint(bc + b1);
                Vector3 p3 = Vector3.Min(p1, p2);
                Vector3 p4 = Vector3.Max(p1, p2);
                
                if (first)
                {
                    first = false;
                    leftbottom = p3;
                    righttop = p4;
                }
                else
                {
                    leftbottom = Vector3.Min(leftbottom, p3);
                    righttop = Vector3.Max(righttop, p4);
                }
            }
        }
        else
        {
            Bounds b = mf.sharedMesh.bounds;
            Vector3 bc = b.center;
            Vector3 b1 = b.size / 2;

            leftbottom = mainobj.transform.TransformPoint(bc - b1);
            righttop = mainobj.transform.TransformPoint(bc + b1);
        }

        CreateBorderObjects(mainobj, material, leftbottom, righttop);
    }

    public static void CreateBorderObjects(GameObject mainobj, Material material, Vector3 leftbottom, Vector3 righttop)
    {
        float margem = (righttop - leftbottom).magnitude / 20f;

        // Borda 1
        GameObject borda = CreatePlaneObject(material);
        borda.transform.position = righttop;
        borda.transform.parent = mainobj.transform;

        Mesh mesh = borda.GetComponent<MeshFilter>().sharedMesh;
        Vector3[] vertices = mesh.vertices;
        vertices[0] = borda.transform.InverseTransformPoint(new Vector3(righttop.x + margem, 0, righttop.z + margem));
        vertices[1] = borda.transform.InverseTransformPoint(new Vector3(righttop.x, 0, righttop.z));
        vertices[2] = borda.transform.InverseTransformPoint(new Vector3(leftbottom.x - margem, 0, righttop.z + margem));
        vertices[3] = borda.transform.InverseTransformPoint(new Vector3(leftbottom.x, 0, righttop.z));
        mesh.vertices = vertices;
        mesh.uv = new Vector2[]
        {
            new Vector2(0.98f, 0.98f),
            new Vector2(0.9217975937f, 0.02f),
            new Vector2(0.02f, 0.98f),
            new Vector2(0.0782024062f, 0.02f),
        };
        mesh.RecalculateBounds();

        // Borda 2
        borda = CreatePlaneObject(material);
        borda.transform.position = righttop;
        borda.transform.parent = mainobj.transform;

        mesh = borda.GetComponent<MeshFilter>().sharedMesh;
        vertices = mesh.vertices;
        vertices[0] = borda.transform.InverseTransformPoint(new Vector3(righttop.x + margem, 0, leftbottom.z - margem));
        vertices[1] = borda.transform.InverseTransformPoint(new Vector3(righttop.x, 0, leftbottom.z));
        vertices[2] = borda.transform.InverseTransformPoint(new Vector3(righttop.x + margem, 0, righttop.z + margem));
        vertices[3] = borda.transform.InverseTransformPoint(new Vector3(righttop.x, 0, righttop.z));
        mesh.vertices = vertices;
        mesh.uv = new Vector2[]
        {
            new Vector2(0.98f, 0.98f),
            new Vector2(0.9217975937f, 0.02f),
            new Vector2(0.02f, 0.98f),
            new Vector2(0.0782024062f, 0.02f),
        };
        mesh.RecalculateBounds();

        // Borda 3
        borda = CreatePlaneObject(material);
        borda.transform.position = leftbottom;
        borda.transform.parent = mainobj.transform;

        mesh = borda.GetComponent<MeshFilter>().sharedMesh;
        vertices = mesh.vertices;
        vertices[0] = borda.transform.InverseTransformPoint(new Vector3(leftbottom.x - margem, 0, leftbottom.z - margem));
        vertices[1] = borda.transform.InverseTransformPoint(new Vector3(leftbottom.x, 0, leftbottom.z));
        vertices[2] = borda.transform.InverseTransformPoint(new Vector3(righttop.x + margem, 0, leftbottom.z - margem));
        vertices[3] = borda.transform.InverseTransformPoint(new Vector3(righttop.x, 0, leftbottom.z));
        mesh.vertices = vertices;
        mesh.uv = new Vector2[]
        {
            new Vector2(0.98f, 0.98f),
            new Vector2(0.9217975937f, 0.02f),
            new Vector2(0.02f, 0.98f),
            new Vector2(0.0782024062f, 0.02f),
        };
        mesh.RecalculateBounds();

        // Borda 4
        borda = CreatePlaneObject(material);
        borda.transform.position = leftbottom;
        borda.transform.parent = mainobj.transform;

        mesh = borda.GetComponent<MeshFilter>().sharedMesh;
        vertices = mesh.vertices;
        vertices[0] = borda.transform.InverseTransformPoint(new Vector3(leftbottom.x - margem, 0, righttop.z + margem));
        vertices[1] = borda.transform.InverseTransformPoint(new Vector3(leftbottom.x, 0, righttop.z));
        vertices[2] = borda.transform.InverseTransformPoint(new Vector3(leftbottom.x - margem, 0, leftbottom.z - margem));
        vertices[3] = borda.transform.InverseTransformPoint(new Vector3(leftbottom.x, 0, leftbottom.z));
        mesh.vertices = vertices;
        mesh.uv = new Vector2[]
        {
            new Vector2(0.98f, 0.98f),
            new Vector2(0.9217975937f, 0.02f),
            new Vector2(0.02f, 0.98f),
            new Vector2(0.0782024062f, 0.02f),
        };
        mesh.RecalculateBounds();
    }

    #endregion
}
