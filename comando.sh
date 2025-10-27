#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "========================================================================"
echo "            INSTALACAO DE DESKTOP VNC NO TERMUX"
echo "========================================================================"
echo ""
echo "Este script ira:"
echo "  - Atualizar o sistema"
echo "  - Instalar TigerVNC, Fluxbox, Firefox e ferramentas"
echo "  - Configurar ambiente desktop"
echo "  - Criar comandos personalizados (iniciar, parar)"
echo ""
echo "Tempo estimado: 5-15 minutos (depende da internet)"
echo ""
read -p "Pressione ENTER para continuar ou Ctrl+C para cancelar..."
echo ""
echo "========================================================================"
echo "  [1/6] ATUALIZANDO SISTEMA..."
echo "========================================================================"
echo ""
pkg update -y && pkg upgrade -y
echo ""
echo "[OK] Sistema atualizado com sucesso!"
sleep 2
echo ""
echo "========================================================================"
echo "  [2/6] INSTALANDO REPOSITORIO X11..."
echo "========================================================================"
echo ""
pkg install x11-repo -y
pkg update -y
echo ""
echo "[OK] Repositorio X11 instalado!"
sleep 2
echo ""
echo "========================================================================"
echo "  [3/6] INSTALANDO PACOTES PRINCIPAIS..."
echo "========================================================================"
echo ""
echo "Instalando:"
echo "  - TigerVNC Server"
echo "  - Fluxbox"
echo "  - Firefox"
echo "  - Geany"
echo "  - XTerm"
echo "  - D-Bus"
echo ""
pkg install tigervnc fluxbox xterm firefox geany xorg-xhost dbus -y
echo ""
echo "[OK] Todos os pacotes instalados!"
sleep 2
echo ""
echo "========================================================================"
echo "  [4/6] PREPARANDO AMBIENTE..."
echo "========================================================================"
echo ""
vncserver -kill :1 > /dev/null 2>&1
vncserver -kill :2 > /dev/null 2>&1
pkill -9 Xvnc > /dev/null 2>&1
pkill -9 Xtigervnc > /dev/null 2>&1
sleep 2
rm -rf ~/.vnc > /dev/null 2>&1
rm -rf ~/.fluxbox > /dev/null 2>&1
echo "[OK] Ambiente preparado!"
sleep 2
echo ""
echo "========================================================================"
echo "  [5/6] CONFIGURANDO VNC SERVER..."
echo "========================================================================"
echo ""
mkdir -p ~/.vnc
echo "123456" | vncpasswd -f > ~/.vnc/passwd 2>/dev/null
chmod 600 ~/.vnc/passwd
SCREEN_SIZE=$(dumpsys window displays 2>/dev/null | grep -oP 'init=\K\d+x\d+' | head -1)
if [ -z "$SCREEN_SIZE" ]; then SCREEN_SIZE=$(wm size 2>/dev/null | grep -oP '\d+x\d+' | head -1); fi
if [ -z "$SCREEN_SIZE" ]; then SCREEN_SIZE="1920x1080"; fi
echo "$SCREEN_SIZE" > ~/.vnc/resolution.conf
mkdir -p ~/.fluxbox
cat > ~/.fluxbox/startup << 'FLUXSTARTEOF'
#!/bin/sh
xset -dpms &
xset s noblank &
xset s off &
exec fluxbox
FLUXSTARTEOF
chmod +x ~/.fluxbox/startup
cat > ~/.fluxbox/init << 'FLUXINITEOF'
session.screen0.toolbar.visible: true
session.screen0.toolbar.placement: TopCenter
session.screen0.tabs.usePixmap: true
session.screen0.tabs.maxOver: false
session.screen0.tabs.intitlebar: true
session.screen0.workspaces: 1
session.screen0.workspaceNames: Workspace 1
FLUXINITEOF
cat > ~/.fluxbox/menu << 'MENUEOF'
[begin] (Fluxbox)
  [submenu] (Aplicativos)
    [exec] (Firefox) {firefox}
    [exec] (Geany Editor) {geany}
    [exec] (Terminal) {xterm}
  [end]
  [submenu] (Sistema)
    [exec] (Reconfigurar) {fluxbox-remote reconfig}
    [restart] (Reiniciar Fluxbox)
  [end]
  [separator]
  [exit] (Sair)
[end]
MENUEOF
cat > ~/.vnc/xstartup << 'XSTARTEOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then eval $(dbus-launch --sh-syntax --exit-with-session); fi
xsetroot -solid "#2e3440" 2>/dev/null &
sleep 1
exec fluxbox 2>/dev/null
XSTARTEOF
chmod +x ~/.vnc/xstartup
echo "[OK] VNC configurado!"
echo "  -> Senha: 123456"
echo "  -> Resolucao: $SCREEN_SIZE"
echo "  -> Porta: 5901"
sleep 2
echo ""
echo "========================================================================"
echo "  [6/6] CRIANDO COMANDOS PERSONALIZADOS..."
echo "========================================================================"
echo ""
cat > $PREFIX/bin/iniciar << 'INICIAREOF'
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "========================================"
echo "       INICIANDO DESKTOP..."
echo "========================================"
echo ""
if pgrep -x "Xtigervnc" > /dev/null || pgrep -x "Xvnc" > /dev/null; then
    echo ""
    echo "========================================"
    echo "    VNC JA ESTA RODANDO!"
    echo "========================================"
    echo ""
    IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    if [ -z "$IP" ]; then
        IP=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)
    fi
    if [ -z "$IP" ]; then
        IP="127.0.0.1"
    fi
    if [ -f ~/.vnc/resolution.conf ]; then
        SCREEN_SIZE=$(cat ~/.vnc/resolution.conf)
    else
        SCREEN_SIZE="Desconhecida"
    fi
    echo "O desktop ja esta ativo!"
    echo ""
    echo "CONECTE-SE:"
    echo "  Mesmo celular: localhost:5901"
    echo "  Mesma rede: $IP:5901"
    echo ""
    echo "  SENHA: 123456"
    echo "  RESOLUCAO: $SCREEN_SIZE"
    echo ""
    echo "----------------------------------------"
    echo ""
    echo "Para reiniciar:"
    echo "  1. Digite: parar"
    echo "  2. Digite: iniciar"
    echo ""
    echo "========================================"
    echo ""
    exit 0
fi

if ! command -v vncserver &> /dev/null; then
    echo "[ERRO] TigerVNC nao instalado!"
    echo "Execute: pkg install tigervnc -y"
    exit 1
fi

if ! command -v fluxbox &> /dev/null; then
    echo "[ERRO] Fluxbox nao instalado!"
    echo "Execute: pkg install fluxbox -y"
    exit 1
fi

vncserver -kill :1 > /dev/null 2>&1
vncserver -kill :2 > /dev/null 2>&1
pkill -9 Xvnc > /dev/null 2>&1
pkill -9 Xtigervnc > /dev/null 2>&1
pkill -9 fluxbox > /dev/null 2>&1
sleep 2

rm -f /tmp/.X1-lock 2>/dev/null
rm -f /tmp/.X11-unix/X1 2>/dev/null
rm -f ~/.vnc/*.log 2>/dev/null
rm -f ~/.vnc/*.pid 2>/dev/null
rm -f ~/.fluxbox/session.screen* 2>/dev/null
sleep 1

if ! pgrep -x "dbus-daemon" > /dev/null; then
    dbus-daemon --session --fork > /dev/null 2>&1
fi

if [ -f ~/.vnc/resolution.conf ]; then
    SCREEN_SIZE=$(cat ~/.vnc/resolution.conf)
else
    SCREEN_SIZE=$(dumpsys window displays 2>/dev/null | grep -oP 'init=\K\d+x\d+' | head -1)
    if [ -z "$SCREEN_SIZE" ]; then
        SCREEN_SIZE=$(wm size 2>/dev/null | grep -oP '\d+x\d+' | head -1)
    fi
    if [ -z "$SCREEN_SIZE" ]; then
        SCREEN_SIZE="1920x1080"
    fi
    echo "$SCREEN_SIZE" > ~/.vnc/resolution.conf
fi

IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -z "$IP" ]; then
    IP=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)
fi
if [ -z "$IP" ]; then
    IP="127.0.0.1"
fi

echo "Iniciando VNC Server..."
echo ""
vncserver -localhost no -geometry $SCREEN_SIZE -depth 24 :1
sleep 3

if pgrep -x "Xtigervnc" > /dev/null || pgrep -x "Xvnc" > /dev/null; then
    echo ""
    echo "========================================"
    echo "   DESKTOP INICIADO COM SUCESSO!"
    echo "========================================"
    echo ""
    echo "ABRA: RealVNC Viewer"
    echo ""
    echo "----------------------------------------"
    echo ""
    echo "  Mesmo celular:"
    echo "    - localhost:5901"
    echo "    - 127.0.0.1:5901"
    echo ""
    echo "  Mesma rede WiFi:"
    echo "    - $IP:5901"
    echo ""
    echo "----------------------------------------"
    echo ""
    echo "  SENHA: 123456"
    echo "  RESOLUCAO: $SCREEN_SIZE"
    echo ""
    echo "========================================"
    echo ""
    echo "APLICATIVOS:"
    echo "  - Firefox (botao direito > Apps)"
    echo "  - Terminal (botao direito > Terminal)"
    echo "  - Geany Editor"
    echo ""
    echo "COMANDOS:"
    echo "  parar - Para o desktop"
    echo ""
    echo "========================================"
    echo ""
else
    clear
    echo ""
    echo "========================================"
    echo "    POSSIVEL ERRO (OU NAO)"
    echo "========================================"
    echo ""
    echo "O VNC pode nao ter iniciado corretamente,"
    echo "MAS frequentemente ele inicia mesmo assim!"
    echo ""
    echo "----------------------------------------"
    echo ""
    echo "FACA ISSO:"
    echo ""
    echo "1. Abra o RealVNC Viewer"
    echo "2. Conecte em: localhost:5901"
    echo "3. Use a senha: 123456"
    echo ""
    echo "----------------------------------------"
    echo ""
    echo "Se conectar = Ignore este erro!"
    echo "Se NAO conectar = Tente:"
    echo ""
    echo "  Digite: parar"
    echo "  Digite: iniciar"
    echo ""
    echo "========================================"
    echo ""
fi
INICIAREOF
chmod +x $PREFIX/bin/iniciar

cat > $PREFIX/bin/parar << 'PARAEOF'
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "========================================"
echo "       PARANDO DESKTOP..."
echo "========================================"
echo ""
vncserver -kill :1
vncserver -kill :2
pkill -9 Xvnc
pkill -9 Xtigervnc
pkill -9 fluxbox
pkill -9 pulseaudio
rm -f /tmp/.X1-lock 2>/dev/null
rm -f /tmp/.X11-unix/X1 2>/dev/null
rm -f ~/.vnc/*.log 2>/dev/null
rm -f ~/.vnc/*.pid 2>/dev/null
rm -f ~/.fluxbox/session.screen* 2>/dev/null
sleep 2

if ! pgrep -x "Xtigervnc" > /dev/null && ! pgrep -x "Xvnc" > /dev/null; then
    echo "[OK] Desktop parado completamente!"
else
    echo "[AVISO] Alguns processos ainda rodando"
fi

echo ""
echo "Para iniciar novamente: iniciar"
echo ""
echo "========================================"
echo ""
PARAEOF
chmod +x $PREFIX/bin/parar

echo "[OK] Comandos criados:"
echo "  - iniciar"
echo "  - parar"
sleep 2
echo ""
echo "========================================================================"
echo "  INSTALACAO CONCLUIDA!"
echo "========================================================================"
echo ""
echo "----------------------------------------------------------------------"
echo "                   COMPONENTES INSTALADOS"
echo "----------------------------------------------------------------------"
echo ""
echo "  [OK] TigerVNC Server  -> Servidor de desktop remoto"
echo "  [OK] Fluxbox          -> Gerenciador de janelas leve"
echo "  [OK] Firefox          -> Navegador web completo"
echo "  [OK] Geany            -> Editor de texto/codigo"
echo "  [OK] XTerm            -> Terminal X11"
echo "  [OK] D-Bus            -> Sistema de mensagens"
echo ""
echo "----------------------------------------------------------------------"
echo "                   COMANDOS DISPONIVEIS"
echo "----------------------------------------------------------------------"
echo ""
echo "  iniciar -> Inicia o desktop VNC"
echo "  parar   -> Para o desktop VNC"
echo ""
echo "----------------------------------------------------------------------"
echo "                   PROXIMOS PASSOS"
echo "----------------------------------------------------------------------"
echo ""
echo "  1. Digite no Termux: iniciar"
echo ""
echo "  2. Baixe o aplicativo: RealVNC Viewer"
echo "     Play Store:"
echo "     https://play.google.com/store/apps/details?id=com.realvnc.viewer.android"
echo ""
echo "  3. Conecte usando:"
echo "     Mesmo celular  -> localhost:5901"
echo "     Mesma rede     -> [IP do celular]:5901"
echo ""
echo "  4. Senha de acesso: 123456"
echo ""
echo "========================================================================"
echo ""
echo "Instalacao concluida! Digite 'iniciar' quando quiser usar o desktop."
echo ""
