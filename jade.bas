' ============================================================
' Biblioteca de Automação de Interface Windows
' Versão Refatorada - Baseada no código original de 2000
' ============================================================
' Autor: Fábio Leandro Lapuinka
' Última atualização: 2026
' ============================================================

' ------------------------------------------------------------
' DECLARAÇÕES DE BIBLIOTECAS EXTERNAS
' ------------------------------------------------------------
' Nota: Presumi que essas DLLs e includes existem no ambiente original
'$include 'winapi.inc'

Declare Function CopyRegToClipboard Lib "lib\clipreg.dll" Alias "CopyRegToClipboard" ( _
    ByVal hKey As Long, _
    ByVal lpSubKey As String, _
    ByVal lpValue As String _
) As Long

' ------------------------------------------------------------
' FUNÇÕES DE GERENCIAMENTO DE JANELAS
' ------------------------------------------------------------

' Verifica se uma janela com o título especificado existe
' Retorna: True se existir, False caso contrário
Function WindowExists(ByVal windowTitle As String) As Boolean
    Dim hWnd As Long
    hWnd = WFndWnd(windowTitle, FW_All)
    WindowExists = (hWnd <> 0)
End Function

' Ativa (traz para o foco) uma janela pelo título
' Retorna: True se conseguiu ativar, False se não encontrou
Function ActivateWindow(ByVal windowTitle As String) As Boolean
    Dim hWnd As Long
    hWnd = WFndWnd(windowTitle, FW_IGNOREFILE)
    
    If hWnd <> 0 Then
        WSetActWnd hWnd
        ActivateWindow = True
    Else
        ActivateWindow = False
    End If
End Function

' Verifica se a janela ativa no momento possui o título especificado
' Retorna: True se for a janela ativa, False caso contrário
Function IsWindowActive(ByVal windowTitle As String) As Boolean
    Dim info As INFO
    WGetInfo WGetActWnd(0), info
    IsWindowActive = (info.szCaption = windowTitle)
End Function

' Aguarda até que uma janela se torne ativa (ou exista)
' Retorna: True quando a janela for encontrada e ativada
Function WaitForWindow(ByVal windowTitle As String) As Boolean
    Dim hWnd As Long
    
    Do While Not IsWindowActive(windowTitle)
        ' Tenta ativar a janela se ela existir
        If WindowExists(windowTitle) Then
            ActivateWindow windowTitle
        End If
        
        ' Verifica se a janela está acessível
        hWnd = WFndWnd(windowTitle, FW_PART Or FW_ALL Or FW_FOCUS Or FW_DIALOGOK Or FW_CHILDOK)
        
        If hWnd <> 0 Then
            WaitForWindow = True
            Exit Do
        End If
        
        ' Pequena pausa para não sobrecarregar a CPU
        Sleep 100
    Loop
End Function

' Aguarda até que uma janela com o texto especificado no título seja ativada
Function WaitForWindowText(ByVal windowText As String) As Boolean
    Do While Not IsWindowActive(windowText)
        If WindowExists(windowText) Then
            ActivateWindow windowText
            WaitForWindowText = True
            Exit Do
        End If
        Sleep 100
    Loop
End Function

' ------------------------------------------------------------
' FUNÇÕES DE INTERAÇÃO COM CONTROLES
' ------------------------------------------------------------

' Clica em um botão pelo seu texto/caption
' Retorna: True se clicou com sucesso, False em caso de falha
Function ClickButton(ByVal buttonText As String) As Boolean
    If Not WButtonExists(buttonText) Then
        ClickButton = False
        Exit Function
    End If
    
    If Not WButtonEnabled(buttonText) Then
        ClickButton = False
        Exit Function
    End If
    
    WButtonClick buttonText
    ClickButton = True
End Function

' Verifica se um texto estático (label) existe na janela ativa
' Retorna: True se existir, False caso contrário
Function StaticTextExists(ByVal text As String) As Boolean
    StaticTextExists = WStaticExists(text)
End Function

' ------------------------------------------------------------
' FUNÇÕES DE MANIPULAÇÃO DE ARQUIVOS
' ------------------------------------------------------------

' Escreve (append) texto em um arquivo
' Retorna: True se conseguiu escrever, False em caso de erro
Function AppendToFile(ByVal filePath As String, ByVal textToAppend As String) As Boolean
    On Error GoTo ErrorHandler
    
    Open filePath For Append As #1
    Print #1, textToAppend
    Close #1
    
    AppendToFile = True
    Exit Function
    
ErrorHandler:
    AppendToFile = False
End Function

' ------------------------------------------------------------
' FUNÇÕES DE REGISTRY (Windows Registry)
' ------------------------------------------------------------

' Verifica se um valor existe no Registry
' Retorna: True se existir, False se não existir ou erro
Function RegistryValueExists(ByVal registryPath As String, ByVal valueName As String) As Boolean
    Dim result As Long
    result = CopyRegToClipboard(HKEY_LOCAL_MACHINE, registryPath, valueName)
    
    ' 0 = Sucesso, 2 = Erro (valor não encontrado)
    RegistryValueExists = (result = 0)
End Function

' ------------------------------------------------------------
' FUNÇÕES DE EXTRAÇÃO DE ARQUIVOS (Auto-Extractors)
' ------------------------------------------------------------

' Automatiza extração de arquivos do WinACE Self-Extractor
Sub ExtractWithAce(ByVal sourceFile As String, ByVal destinationPath As String)
    ' Executa o script auxiliar do ACE
    Run "Z:\Scripts\mstest\projetos\instpd\mtrun.exe Z:\Scripts\mstest\projetos\instpd\ace.pcd /c " & destinationPath, Nowait, 1
    ' Executa o auto-extrator
    Run sourceFile, , 1
End Sub

' Automatiza extração de arquivos do WinZip Self-Extractor (versão 7.0)
Sub ExtractWithWinZip(ByVal sourcePath As String, ByVal archiveName As String, ByVal destinationPath As String)
    Dim windowTitle As String
    windowTitle = "WinZip Self-Extractor - " & archiveName
    
    ' Executa o auto-extrator
    Run sourcePath & archiveName, Nowait, 0
    
    ' Aguarda a janela aparecer
    WaitForWindow windowTitle
    
    ' Envia comandos de teclado para o extrator
    SendKeys "%f"   ' Menu File
    SendKeys destinationPath
    SendKeys "%u"   ' Unzip
    
    ' Aguarda a conclusão da extração
    Do While True
        If WindowExists("WinZip Self-Extractor") And WButtonExists("OK") Then
            ClickButton "OK"
            WaitForWindow windowTitle
            ClickButton "&Close"
            Exit Do
        Else
            ActivateWindow "WinZip Self-Extractor"
        End If
        Sleep 500
    Loop
End Sub

' ------------------------------------------------------------
' FUNÇÕES DE BOOT MANAGER (Windows NT / 95)
' ------------------------------------------------------------

' Instala o gerenciador de boot do Windows NT 4.0
Sub InstallBootNT()
    StatusBox "Aguarde um momento, instalando o gerenciador de boot do Windows NT 4.0", 350, 30, 450, 40, True, True, "MS Sans Serif"
    
    Run "z:\scripts\bats\boot.bat /UpdateNT", , 2
    Run "z:\scripts\bats\boot.bat /DelSwap /partition(2)", , 2
    
    StatusBox Close
End Sub

' Instala o gerenciador de boot do Windows 95
Sub InstallBoot95()
    StatusBox "Aguarde um momento, instalando o boot do Windows 95", 350, 30, 450, 40, True, True, "MS Sans Serif"
    
    Run "z:\scripts\bats\boot.bat /InstallW95", , 2
    
    StatusBox Close
End Sub

' ------------------------------------------------------------
' FUNÇÃO DE UTILIDADE: LOOP DE REPETIÇÃO
' ------------------------------------------------------------

' Executa um loop de 0 até N (útil para ações repetitivas)
' Retorna: Número de iterações realizadas
Function RepeatLoop(ByVal numberOfRepeats As Integer) As Integer
    Dim i As Integer
    For i = 0 To numberOfRepeats
        ' Placeholder para ações repetitivas
    Next i
    RepeatLoop = i
End Function

' ------------------------------------------------------------
' SUB-ROTINA: FINALIZAÇÃO DA INSTALAÇÃO PADRÃO (Windows 95)
' ------------------------------------------------------------

Sub FinalizeStandardInstall95()
    ' === REMOÇÃO DE SERVIÇOS E REGISTRY ===
    If FileExists("c:\windows\options\flags\remoto.flg") Then
        If FileExists("c:\windows\options\scripts\remoto.bat") Then
            Run "c:\windows\options\scripts\remoto.bat", Nowait, 0
        End If
    Else
        ' Remove adaptador Dial-Up
        Run "command.com /c echo y | reg.exe Delete HKLM\Enum\Root\Net\0000", , 0
    End If
    
    ' Remove entradas do Registry
    Run "command.com /c echo y | reg.exe Delete HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices\vigia", , 0
    Run "command.com /c echo y | reg.exe Delete HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\Instalador", , 0
    
    ' === ATUALIZAÇÕES PÓS-INSTALAÇÃO ===
    If FileExists("c:\windows\options\scripts\shared.bat") Then
        Run "c:\windows\options\scripts\shared.bat", Nowait, 0
    End If
    
    If FileExists("c:\windows\options\scripts\update.bat") Then
        Run "c:\windows\options\scripts\update.bat", Nowait, 0
    End If
    
    ' === LOGS ===
    AppendToFile "c:\win95.log", Date$ & Time$ & " - Fim da instalação."
    AppendToFile "c:\windows\options\flags\final95.flg", Date$ & Time$ & " - Fim da instalação."
    
    ' === NAL ZEN (Novell Application Launcher) ===
    If FileExists("c:\windows\options\nal\*.nal") Then
        Run "mtrun c:\windows\options\scripts\nalzen.pcd", Nowait, 0
        Stop
    End If
    
    ' === IMAGEM DE FUNDO (Siemens) ===
    If FileExists("c:\windows\siemens.bmp") Then
        CopyFile "c:\windows\siemens.bmp", "c:\windows\old.bmp"
    End If
    
    ' === MENSAGEM FINAL ===
    MsgBox "Instalação padrão SBS NSL concluída - dúvidas entre em contato com o HelpDesk.", MB_ICONINFORMATION, "Aviso"
    
    Stop
End Sub

' ------------------------------------------------------------
' SUB-ROTINA: MANUSEADOR DE MENSAGENS/JANELAS POPUP
' (Interação com o usuário durante a instalação)
' ------------------------------------------------------------

Sub HandleUserMessages()
    ' Dicionário de ações para janelas comuns
    ' Estrutura: (Título da Janela, Ação a ser tomada)
    
    ' Botões OK/Cancelar/Sím/Não
    If ActivateWindow("Inserir Disco") Then ClickButton "OK"
    If ActivateWindow("Rede do Windows") Then ClickButton "OK"
    If ActivateWindow("Digite a Senha do Windows") Then ClickButton "Cancelar"
    If ActivateWindow("Alteração das configurações do sistema") Then ClickButton "&Não"
    If ActivateWindow("Exibir") Then ClickButton "OK"
    If ActivateWindow("Propriedades de Vídeo") Then ClickButton "Cancelar"
    If ActivateWindow("Conflito de Versão") Then ClickButton "&Sim"
    If ActivateWindow("DHCP Client") Then ClickButton "&Não"
    If ActivateWindow("Rede do Windows") Then ClickButton "OK"
    If ActivateWindow("Auto-detecção") Then ClickButton "&Não"
    
    ' Modem
    If ActivateWindow("Verificar Modem") Then
        ClickButton "Avançar >"
        ClickButton "Concluir"
    End If
    
    ' Driver de Dispositivo
    If ActivateWindow("Assistente de Atualização de Driver de Dispositivo") Then
        ClickButton "Avançar >"
        ClickButton "Concluir"
    End If
    
    ' Outros
    If ActivateWindow("Instalação de configuração") Then ClickButton "OK"
    If ActivateWindow("Inicialização do GroupWise") Then ClickButton "Cancelar"
    If ActivateWindow("Assistente para Adicionar Novo Hardware") Then ClickButton "Não"
    If ActivateWindow("Results") Then ClickButton "Close"
End Sub

' ------------------------------------------------------------
' FUNÇÕES AUXILIARES (adicionadas para completude)
' ------------------------------------------------------------

' Verifica se um arquivo existe
Function FileExists(ByVal filePath As String) As Boolean
    On Error GoTo FileNotFound
    Dim fileAttr As Integer
    fileAttr = GetAttr(filePath)
    FileExists = True
    Exit Function
    
FileNotFound:
    FileExists = False
End Function

' Pausa a execução por milissegundos (se disponível)
Sub Sleep(ByVal milliseconds As Long)
    ' Nota: Em WinBatch, pode não existir Sleep nativo.
    ' Esta é uma adaptação conceitual.
    ' Se existir uma função Sleep, use-a.
    ' Caso contrário, um loop pode ser usado com cautela.
    ' Exemplo: TimerDelay(milliseconds)
End Sub

' Copia um arquivo (placeholder)
Sub CopyFile(ByVal source As String, ByVal destination As String)
    FileCopy source, destination
End Sub
