
'Biblioteca pessoal de Fábio Leandro Lapuinka 'Última atualização em 27/07/2000

'$include 'winapi.inc'

 Declare Function JanelaExiste         (Nome_da_Janela$)                                                                     ' Retorna True (Janela existe) or False (Janela não existe)
 Declare Function Espere_a_Janela (Nome_da_Janela$)                                                                     '  Espera pela Janela que você mandou
 Declare Function JanelaAtiva          (Nome_da_Janela$)                                                                      ' Retorna True (Janela está em foco) or False(Janela não está em foco)
 Declare Function botao (Nome_do_Botao$)                                                                       ' Dá um clique em um botão, volta True (Clicou) or False(Não conseguiu)
 Declare Function EscrevaArquivo (caminho_e_nome_do_arquivo$,texto_$)                                         ' Cria um arquivo de texto ASCII
 Declare Function  AceSelf(origem$,destino$)                                                                                       ' Automatiza o processo de extração de arquivos do seft-Extractor do compactador WinACE
 Declare Function  WinzipSelf(origem$,arquivo$,destino$)                                                                    ' Automatiza o processo de extração de arquivos do seft-Extractor do compactador WinZip 7.0
 Declare Function Selecione_a_Janela(Nome_da_Janela$)                                                                   ' Ativa o foco em um janela e retorna True (Janela foi selecionada) or False (Janela nao foi selecionada)
 Declare Function Repete(numero_de_repeticoes%)                                                                              ' Repete o um laço que vai de 0  até o numero de vezes que você passou, retorna o numero de vezes
 Declare Function Letreiro(Mensagem$,Alinhamento$)                                                                            ' Escreve uma mensagem na tela, um status, sem interromper a execução do programa
 Declare Function  AtiveJanela (Nome_da_Janela$)                                                                               'Ativa o foco do nome da janela
 Declare Function ExisteReg (Path_Registry$,Value_Registry$)                                                              'Verifica se um valor existe no registry
 Declare Function CopyRegToClipboard lib "lib\clipreg.dll" alias "CopyRegToClipboard" (hKey, lpSubKey$, lpValue$) as long ' Funcao externa da DLL
 Declare Function bootnt ()                                                                                                                      'Instala o gerenciador de boot do Windows NT
 Declare Function boot95 ()                                                                                                                     'Instala o boot do windows 95
 Declare Function texto(palavra$)                                                                                                                 'retorna verdadeiro se o texto existir na janela ativa
Declare  Function ActiveWindow(NameWindow$)
Declare  Function SleepW(NameWindow$)
Declare Sub FimInstpd95()
Declare sub sub_user_messages()                                                                                                           ' Interação do script com o Windows







'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function ExisteReg (Path_Registry$,Value_Registry$)


 'Obter o nome do computador.


                                                                                                   'Copiar os valores para a Clipboard
  GetValueRegistry=CopyRegToClipboard(HKEY_LOCAL_MACHINE,Path_Registry$,Value_Registry$) 'Copiar os valores para a Clipboard           'Copiar os valores para a Clipboard           'Copiar os valores para a Clipboard


  If GetValueRegistry=2 Then

     ' msgbox  "Error 2 "

     ExisteReg=False

     Else

      'msgbox  "Deu Certo 0 "
      ExisteReg=True

  Endif

End Function





'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


 Function JanelaAtiva(Nome_da_Janela$)
     Dim info AS INFO
     WGetInfo WGetActWnd(0),info

     'verifica se as informações da janela ativa correspondem a janela pedida
     If Nome_da_Janela$=info.szCaption then
          JanelaAtiva=true
          else
          JanelaAtiva=false
      Endif

 End Function





'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Function Espere_a_Janela (Nome_da_Janela$)

    Do While  JanelaAtiva(Nome_da_Janela$)

       'coloca em foco a janela
       Selecione_a_Janela (Nome_da_Janela$)

      ' flags que indicam que os estados da janela
       wFlags = FW_PART or FW_ALL or FW_FOCUS or FW_DIALOGOK or FW_CHILDOK
       hWnd = WFndWnd(Nome_da_Janela$, wFlags)

        If hWnd <> 0 then
              ' esta rotina indica que janela está em foco
                 Espere_a_Janela=True
                  Exit Do
             Else
             'esta rotina indica que janela não está mais em foco
                Espere_a_Janela=False
        Endif
     Loop

End Function
'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function botao(Nome_do_Botao$)

 ' verifica se ele existe
 if  WButtonExists (Nome_do_Botao$)then

      ' se existir verifica se ele está habilitado
      if WButtonEnabled(Nome_do_Botao$)  then

         'se ele estiver habilitado, seleciona-o e dá um clique sobre ele
                       WButtonClick (Nome_do_Botao$)
                       ClickButton=true
             else

             botao=false
       endif

      else

     botao=false

 endif

End Function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function   EscrevaArquivo(caminho_e_nome_do_arquivo$,texto_$)

   'abre um arquivo
   open caminho_e_nome_do_arquivo$ FOR APPEND AS #1

   'escreve no arquivo o conteudo passado
   print #1, texto_$

   'fecha o arquivo aberto
   Close #1

End Function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function  AceSelf(origem$,destino$)

      'chama o arquivo

      run "Z:\Scripts\mstest\projetos\instpd\mtrun.exe    Z:\Scripts\mstest\projetos\instpd\ace.pcd /c  "+ destino$ ,nowait,1


      run origem$,,1


 End Function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

 Function  winzipself(origem$,arquivo$,destino$)
     dim janela$

      janela="WinZip Self-Extractor - " + arquivo$

      '  abre o arquivo
      run origem$ + arquivo$,nowait,0

      'espera ele aparecer
      Espere_a_Janela (janela$)

      'emula os comandos do teclado
      dokeys "%f"
      dokeys destino$
      dokeys "%u"

      'espera os arquivos serem descompactados


     do while  true
                    if  janelaexiste("WinZip Self-Extractor") and   WButtonExists ("OK") then

                            botao ("OK")
                            espere_a_janela (janela$)
                            botao ("&Close")
                            exit do

                            else

                            ativejanela ("WinZip Self-Extractor")

                    endif
      loop




 End Function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function Selecione_a_Janela(Nome_da_Janela$)

Dim hwndNP as Long
hwndNP = WFndWnd(Nome_da_Janela$, FW_IGNOREFILE)

'Procura pela janela no sistema
If hwndNP Then
   WSetActWnd hwndNP
   Selecione_a_Janela=True
   Else
   Selecione_a_Janela=False
Endif


End Function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function Repete(numero_de_repeticoes%)

 For i=0 to numero_de_repeticoes%

 Next

End Function
'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function Letreiro(Mensagem$,Alinhamento$)

     Dim x,y,z,w as integer

      if Alinhamento="" then

        else
         x=350
         y=30
        z=450
        w=40
      endif
      statusbox Mensagem$,x,y,z,w,true,true,"MS Sans Serif"

End Function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 Function JanelaExiste(Nome_da_Janela$)

   ' flags que indicam que os estados da janela

   wFlags = FW_All
   hWnd = WFndWnd(Nome_da_Janela$, wFlags)


    If hWnd  =  0 then
         ' esta rotina indica que janela não existe
             JanelaExiste = false
         Else
         'esta rotina indica que janela não existe mais
            JanelaExiste = true
    Endif


End Function


'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function AtiveJanela(Nome_da_Janela$)

  dim hwndNP as long

      ' flags que indicam que os estados da janela

            hwndNP = WFndWnd(Nome_da_Janela$, FW_IGNOREFILE)


       if hwndNP = 0   then
                 'se a janela existir no sistema deixa a mesma ativa

               AtiveJanela = false



           else

                 WSetActWnd hwndNP
                  AtiveJanela = true


       endif


End Function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function bootnt ()

       'iInstala o gerenciador de boot do Windows NT

        statusbox "Aguarde um momento, instalando o gerenciador de boot do Windows NT 4.0",,,,,true,true,"MS Sans Serif"


         'roda o setup do windows nt só que não copia nenhum arquivo
         run "z:\scripts\bats\boot.bat /UpdateNT",,2

         'apaga os arquivos temporários do setup do windows nt
         run "z:\scripts\bats\boot.bat /DelSwap /partition(2)",,2

       statusbox close

end function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function boot95 ()

       'iInstala o gerenciador de boot do Windows 95

        statusbox "Aguarde um momento, instalando o boot do Windows 95 ",,,,,true,true,"MS Sans Serif"


         'roda o setup do windows nt só que não copia nenhum arquivo
         run "z:\scripts\bats\boot.bat /InstallW95",,2

       statusbox close

end function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'anexa um texto no fim do arquivo

  function texto(palavra$)


             if wstaticexists (palavra$) then   'verifica se o texto existe

                                  texto=true

                                             else

                                  texto=false

              endif

end function

'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

 Function ActiveWindow(NameWindow$)
     Dim info AS INFO
     WGetInfo WGetActWnd(0),info
     If NameWindow=info.szCaption then ActiveWindow=true else ActiveWindow=false
 End Function



'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function SleepW(NameWindow$)
'encontra uma janela que possua o texto no titulo

  Do While not ActiveWindow(NameWindow$)
   wFlags = FW_PART or FW_ALL or FW_FOCUS or FW_DIALOGOK or FW_CHILDOK
   hWnd = WFndWnd(NameWindow$, wFlags)
    If hWnd <> 0 then
        SleepW=True
        Exit Do
    Endif
  Loop
End Function


'//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Sub FimInstpd95()





  if exists("c:\windows\options\flags\remoto.flg") then

        if exists ("c:\windows\options\scripts\remoto.bat") then run "c:\windows\options\scripts\remoto.bat",nowait,0 ' Executa o Script para máquina Dial_up

        else
        run "command.com /c echo y | reg.exe Delete  HKLM\Enum\Root\Net\0000",,0 'Remove o Adaptador Dial-Up

  endif

  run "command.com /c echo y | reg.exe Delete  HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices\vigia",,0 'Remove os serviços do registry
  run "command.com /c echo y | reg.exe Delete  HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\Instalador",,0      'Remove os serviços do registry


'Atualizações da instalação padrão

if exists ("c:\windows\options\scripts\shared.bat") then run (" c:\windows\options\scripts\shared.bat"),nowait,0 'Inicia o Call Update minimizado para as seções de compartilhamento das localidades
if exists ("c:\windows\options\scripts\update.bat") then run (" c:\windows\options\scripts\update.bat"),nowait,0 'Específico localidades




                    escrevaarquivo "c:\win95.log", date$ + time$ + " - Fim da instalação."
                   escrevaarquivo "c:\windows\options\flags\final95.flg", date$ + time$ + " -Fim da instalação."


                   if  exists("c:\windows\options\nal\*.nal") then
                         run "mtrun c:\windows\options\scripts\nalzen.pcd",nowait,0 'Chama o script do Nal Zen
                         stop
                   endif
if exists("c:\windows\siemens.bmp") then
 copy "c:\windows\siemens.bmp" to "c:\windows\old.bmp"
endif
msgbox "Instalação padrão SBS NSL concluída - dúvidas entre em contato com o HelpDesk.", MB_ICONINFORMATION , "Aviso"
''                                    run "c:\windows\atualiza.exe",nowait,0             'reinicia a máquina
stop
End Sub

'////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

 sub sub_user_messages()

           if ativejanela ("Inserir Disco")                                                           then botao "OK"
           if ativejanela ("Rede do Windows")                                                 then botao "OK"
           if ativejanela ("Digite a Senha do Windows")                                   then botao "Cancelar"
           if ativejanela ("Alteração das configurações do sistema")                 then botao "&Não"
           if ativejanela ("Exibir")                                                                       then botao "OK"
           if ativejanela ("Propriedades de Vídeo")                                           then botao "Cancelar"
           if ativejanela ("Conflito de Versão")                                                  then botao "&Sim"
           if ativejanela ("DHCP Client")                                                           then botao "&Não"
           if ativejanela ("Rede do Windows")                                                  then botao "OK"
           if ativejanela ("Auto-detecção")                                                        then botao "&Não"
           if ativejanela ("Verificar Modem")                                                      then botao "Avançar >"
           if ativejanela ("Verificar Modem")                                                      then botao "Concluir"
           if ativejanela ("Assistente de Atualização de Driver de Dispositivo") then botao "Avançar >"
           if ativejanela ("Assistente de Atualização de Driver de Dispositivo") then botao "Concluir"
           if ativejanela ("Instalação de configuração")                                     then botao "OK"
           if ativejanela ("Inicialização do GroupWise")                                     then botao "Cancelar"
           if ativejanela ("Assistente para Adicionar Novo Hardware")             then botao "Não"
            if ativejanela ("Results")                                                                   then botao "Close"


 end sub
