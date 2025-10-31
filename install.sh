#!/bin/bash

# ════════════════════════════════════════════════════════════════
# Instalador Wine Pawn + Playit v8.0 - VERSÃO CORRIGIDA
# ════════════════════════════════════════════════════════════════

TEMP_DIR="/tmp/wine_installer_$$"
mkdir -p "$TEMP_DIR"

# Log para debug
LOG_FILE="/tmp/wine_installer.log"
exec 2>> "$LOG_FILE"

trap 'rm -rf "$TEMP_DIR"; clear' EXIT

# ════════════════════════════════════════════════════════════════
# VERIFICAR E INSTALAR DIALOG
# ════════════════════════════════════════════════════════════════

if ! command -v dialog &>/dev/null; then
    echo "════════════════════════════════════════"
    echo "  Instalando dialog..."
    echo "════════════════════════════════════════"
    sudo apt-get update -qq && sudo apt-get install -y dialog
fi

# ════════════════════════════════════════════════════════════════
# FUNÇÕES DE LOG E DEBUG
# ════════════════════════════════════════════════════════════════

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

# ════════════════════════════════════════════════════════════════
# FUNÇÕES DE VERIFICAÇÃO MELHORADAS
# ════════════════════════════════════════════════════════════════

check_wine() {
    if command -v wine &>/dev/null; then
        local version=$(wine --version 2>/dev/null | head -1)
        echo "✓ Instalado ($version)"
        return 0
    else
        echo "✗ Não instalado"
        return 1
    fi
}

check_vscode() {
    if [ -f ".vscode/tasks.json" ] && [ -f ".vscode/settings.json" ]; then
        echo "✓ Configurado"
        return 0
    else
        echo "✗ Não configurado"
        return 1
    fi
}

check_extensions() {
    if ! command -v code &>/dev/null; then
        echo "✗ VS Code não instalado"
        return 1
    fi
    
    local count=0
    code --list-extensions 2>/dev/null | grep -qi "southclaws.vscode-pawn" && ((count++))
    code --list-extensions 2>/dev/null | grep -qi "sanaajani.taskrunnercode" && ((count++))
    
    if [ $count -eq 2 ]; then
        echo "✓ Todas instaladas ($count/2)"
        return 0
    elif [ $count -eq 1 ]; then
        echo "⚠ Parcial ($count/2)"
        return 1
    else
        echo "✗ Não instaladas (0/2)"
        return 1
    fi
}

check_playit() {
    if command -v playit &>/dev/null; then
        echo "✓ Instalado"
        return 0
    else
        echo "✗ Não instalado"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# INSTALAR WINE (VERSÃO CORRIGIDA E MELHORADA)
# ════════════════════════════════════════════════════════════════

install_wine() {
    log_info "Iniciando instalação do Wine"
    
    # Verifica se já está instalado
    if command -v wine &>/dev/null; then
        local wine_version=$(wine --version 2>/dev/null | head -1)
        log_info "Wine já instalado: $wine_version"
        dialog --title "Wine Já Instalado" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✓ Wine já está instalado!\n\nVersão: $wine_version" 9 50
        return 0
    fi
    
    # Aviso sobre tempo de instalação
    dialog --title "⏱️ Instalação do Wine" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --msgbox "A instalação do Wine pode demorar de 2 a 5 minutos.\n\nPor favor, aguarde pacientemente.\n\nNão feche o terminal durante a instalação!" 11 60
    
    (
        echo "5" ; sleep 0.2
        log_info "Removendo versões antigas do Wine"
        sudo apt remove --purge wine wine32 wine64 libwine* -y &>/dev/null
        sudo apt autoremove -y &>/dev/null
        rm -rf ~/.wine &>/dev/null
        
        echo "10" ; sleep 0.2
        log_info "Configurando arquitetura i386"
        sudo dpkg --add-architecture i386
        
        echo "15" ; sleep 0.2
        log_info "Atualizando cache do apt"
        sudo apt update
        
        echo "25" ; sleep 0.2
        log_info "Instalando dependências básicas"
        sudo apt install -y wget gnupg software-properties-common apt-transport-https ca-certificates
        
        echo "35" ; sleep 0.2
        log_info "Criando diretório para chaves"
        sudo mkdir -pm755 /etc/apt/keyrings
        
        echo "40" ; sleep 0.2
        log_info "Baixando chave WineHQ"
        sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
        
        echo "50" ; sleep 0.2
        log_info "Detectando versão do Ubuntu"
        local ubuntu_version=$(lsb_release -cs 2>/dev/null || echo "jammy")
        log_info "Versão detectada: $ubuntu_version"
        
        echo "55" ; sleep 0.2
        log_info "Adicionando repositório WineHQ"
        sudo wget -NP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/${ubuntu_version}/winehq-${ubuntu_version}.sources"
        
        # Se falhar, tenta com jammy como fallback
        if [ ! -f "/etc/apt/sources.list.d/winehq-${ubuntu_version}.sources" ]; then
            log_info "Tentando com jammy como fallback"
            sudo wget -NP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources"
        fi
        
        echo "65" ; sleep 0.2
        log_info "Atualizando lista de pacotes"
        sudo apt update
        
        echo "70" ; sleep 0.2
        log_info "Instalando Wine (isso pode demorar vários minutos)"
        sudo apt install -y --install-recommends winehq-stable
        
        if [ $? -ne 0 ]; then
            log_error "Falha ao instalar winehq-stable, tentando wine-stable"
            sudo apt install -y wine-stable
        fi
        
        echo "85" ; sleep 0.2
        log_info "Configurando ambiente Wine"
        mkdir -p ~/.wine-runtime
        chmod 700 ~/.wine-runtime
        
        export XDG_RUNTIME_DIR=~/.wine-runtime
        export WINEARCH=win32
        export WINEPREFIX=~/.wine
        export WINEDEBUG=-all
        export DISPLAY=:0
        
        echo "90" ; sleep 0.2
        log_info "Inicializando Wine"
        timeout 60 wineboot -u &>/dev/null || true
        
        echo "95" ; sleep 0.2
        log_info "Configurando .bashrc"
        if ! grep -q "WINEARCH=win32" ~/.bashrc 2>/dev/null; then
            cat >> ~/.bashrc << 'BASHRC'

# ════════════════════════════════════════════════════════════════
# Configuração Wine 32-bit (Instalador v8.0)
# ════════════════════════════════════════════════════════════════
mkdir -p ~/.wine-runtime 2>/dev/null
export XDG_RUNTIME_DIR=~/.wine-runtime
export WINEARCH=win32
export WINEPREFIX=~/.wine
export WINEDEBUG=-all
export DISPLAY=:0
BASHRC
        fi
        
        echo "98" ; sleep 0.2
        log_info "Recarregando configurações"
        source ~/.bashrc 2>/dev/null || true
        
        echo "100" ; sleep 0.2
        log_info "Instalação concluída"
    ) | dialog \
        --title "Instalando Wine" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --gauge "Iniciando instalação... (pode demorar de 2 a 5 minutos)" 10 70 0
    
    # Aguarda um momento para garantir que tudo foi instalado
    sleep 2
    
    # Recarrega as variáveis
    source ~/.bashrc 2>/dev/null || true
    
    # Verificação final MELHORADA
    if command -v wine &>/dev/null; then
        local wine_version=$(wine --version 2>/dev/null | head -1)
        log_info "Wine instalado com sucesso: $wine_version"
        dialog --title "✓ Sucesso" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✓ Wine instalado com sucesso!\n\nVersão: $wine_version\n\n💡 Dica: Se tiver problemas, execute:\nsource ~/.bashrc" 12 55
        return 0
    else
        log_error "Wine não está disponível após instalação"
        dialog --title "⚠️ Atenção" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "⚠️ Instalação concluída mas Wine não está no PATH.\n\nSOLUÇÕES:\n1. Execute: source ~/.bashrc\n2. Feche e reabra o terminal\n3. Reinicie este script\n\nSe persistir, verifique: $LOG_FILE" 14 60
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# CONFIGURAR VS CODE (VERSÃO MELHORADA)
# ════════════════════════════════════════════════════════════════

configure_vscode() {
    log_info "Iniciando configuração do VS Code"
    
    # Cria diretório
    mkdir -p .vscode
    
    # Cria settings.json
    cat > .vscode/settings.json << 'SETTINGS'
{
    "// ⚠️ ATENÇÃO": "NÃO APAGUE ESTE ARQUIVO!",
    "// Necessário": "Para compilar Pawn com Wine no Codespaces",
    
    "terminal.integrated.env.linux": {
        "WINEARCH": "win32",
        "WINEPREFIX": "${env:HOME}/.wine",
        "WINEDEBUG": "-all",
        "XDG_RUNTIME_DIR": "${env:HOME}/.wine-runtime",
        "DISPLAY": ":0"
    }
}
SETTINGS
    
    log_info "settings.json criado"
    
    (
        echo "10" ; sleep 0.2
        log_info "Baixando task.zip"
        
        # Tenta múltiplas URLs
        local downloaded=false
        
        if wget -q --timeout=15 "https://github.com/48348484488/Maquina-VPS/raw/74c1d4876c3342d3df52d7db0142fef90f05f4bd/task.zip" -O "$TEMP_DIR/task.zip" 2>/dev/null; then
            downloaded=true
            log_info "Download bem-sucedido"
        fi
        
        echo "50" ; sleep 0.2
        
        if [ "$downloaded" = true ] && [ -f "$TEMP_DIR/task.zip" ]; then
            log_info "Extraindo task.zip"
            cd "$TEMP_DIR"
            
            if unzip -q -o task.zip 2>/dev/null; then
                log_info "Extração bem-sucedida"
                
                if [ -d "vscode" ]; then
                    # Backup do settings.json
                    if [ -f "$OLDPWD/.vscode/settings.json" ]; then
                        cp "$OLDPWD/.vscode/settings.json" "$OLDPWD/.vscode/settings.json.backup"
                        log_info "Backup de settings.json criado"
                    fi
                    
                    # Copia arquivos
                    cp -r vscode/* "$OLDPWD/.vscode/" 2>/dev/null
                    log_info "Arquivos copiados"
                    
                    # Restaura settings.json
                    if [ -f "$OLDPWD/.vscode/settings.json.backup" ]; then
                        mv "$OLDPWD/.vscode/settings.json.backup" "$OLDPWD/.vscode/settings.json"
                        log_info "settings.json restaurado"
                    fi
                fi
            else
                log_error "Falha ao extrair task.zip"
            fi
            
            cd - >/dev/null
        else
            log_error "Falha no download de task.zip"
        fi
        
        rm -f "$TEMP_DIR/task.zip" 2>/dev/null
        
        echo "100" ; sleep 0.2
    ) | dialog \
        --title "Configurando VS Code" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --gauge "Processando..." 10 70 0
    
    sleep 1
    
    # Verificação
    if [ -f ".vscode/settings.json" ]; then
        if [ -f ".vscode/tasks.json" ]; then
            log_info "VS Code configurado completamente"
            dialog --title "✓ Sucesso" \
                --backtitle "Instalador Wine Pawn + Playit v8.0" \
                --msgbox "✓ VS Code configurado!\n\n• settings.json criado\n• tasks.json instalado" 10 50
            return 0
        else
            log_info "VS Code configurado parcialmente (sem tasks.json)"
            dialog --title "⚠️ Parcial" \
                --backtitle "Instalador Wine Pawn + Playit v8.0" \
                --msgbox "⚠️ Configuração parcial:\n\n• settings.json: OK\n• tasks.json: Falhou\n\nVocê pode criar tasks.json manualmente." 11 55
            return 0  # Considera sucesso parcial
        fi
    else
        log_error "Falha ao criar settings.json"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# INSTALAR EXTENSÕES (VERSÃO MELHORADA)
# ════════════════════════════════════════════════════════════════

install_extensions() {
    log_info "Iniciando instalação de extensões"
    
    if ! command -v code &>/dev/null; then
        log_error "VS Code não encontrado"
        dialog --title "Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✗ VS Code não está instalado!\n\nNo GitHub Codespaces, o VS Code já está instalado.\nSe estiver em outro ambiente, instale o VS Code primeiro." 11 60
        return 1
    fi
    
    # Verifica extensões já instaladas
    local ext_pawn_installed=false
    local ext_task_installed=false
    
    code --list-extensions 2>/dev/null | grep -qi "southclaws.vscode-pawn" && ext_pawn_installed=true
    code --list-extensions 2>/dev/null | grep -qi "sanaajani.taskrunnercode" && ext_task_installed=true
    
    if [ "$ext_pawn_installed" = true ] && [ "$ext_task_installed" = true ]; then
        log_info "Extensões já instaladas"
        dialog --title "Extensões Já Instaladas" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✓ Todas as extensões já estão instaladas!\n\n• Pawn Language\n• Task Runner" 10 50
        return 0
    fi
    
    (
        echo "10" ; sleep 0.2
        
        if [ "$ext_pawn_installed" = false ]; then
            log_info "Instalando Pawn Language"
            echo "30" ; echo "# Instalando Pawn Language..."
            code --install-extension southclaws.vscode-pawn --force 2>&1 | tee -a "$LOG_FILE" >/dev/null
        else
            log_info "Pawn Language já instalado"
            echo "30" ; echo "# Pawn Language já instalado"
        fi
        
        sleep 1
        
        if [ "$ext_task_installed" = false ]; then
            log_info "Instalando Task Runner"
            echo "70" ; echo "# Instalando Task Runner..."
            code --install-extension sanaajani.taskrunnercode --force 2>&1 | tee -a "$LOG_FILE" >/dev/null
        else
            log_info "Task Runner já instalado"
            echo "70" ; echo "# Task Runner já instalado"
        fi
        
        echo "100" ; sleep 0.5
    ) | dialog \
        --title "Instalando Extensões" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --gauge "Processando..." 10 70 0
    
    # Aguarda sincronização
    sleep 2
    
    # Verificação final
    local count=0
    code --list-extensions 2>/dev/null | grep -qi "southclaws.vscode-pawn" && ((count++))
    code --list-extensions 2>/dev/null | grep -qi "sanaajani.taskrunnercode" && ((count++))
    
    log_info "Extensões instaladas: $count/2"
    
    if [ $count -eq 2 ]; then
        dialog --title "✓ Sucesso" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✓ Extensões instaladas com sucesso!\n\nInstaladas: $count/2" 9 50
        return 0
    elif [ $count -eq 1 ]; then
        dialog --title "⚠️ Parcial" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "⚠️ Instalação parcial: $count/2\n\nRecarregue a página (F5) e tente novamente." 10 55
        return 0  # Considera sucesso parcial
    else
        log_error "Nenhuma extensão foi instalada"
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✗ Falha ao instalar extensões.\n\nVerifique o log: $LOG_FILE" 9 50
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# INSTALAR PLAYIT (VERSÃO MELHORADA)
# ════════════════════════════════════════════════════════════════

install_playit() {
    log_info "Iniciando instalação do Playit"
    
    if command -v playit &>/dev/null; then
        local playit_version=$(playit --version 2>/dev/null || echo "instalado")
        log_info "Playit já instalado: $playit_version"
        dialog --title "Playit Já Instalado" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✓ Playit já está instalado!\n\nVersão: $playit_version" 9 50
        return 0
    fi
    
    (
        echo "10" ; sleep 0.2
        log_info "Criando diretório de chaves"
        sudo mkdir -p /etc/apt/trusted.gpg.d
        
        echo "25" ; sleep 0.2
        log_info "Baixando chave GPG do Playit"
        if curl -fsSL https://playit-cloud.github.io/ppa/key.gpg 2>/dev/null | \
            sudo gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/playit-cloud.gpg; then
            log_info "Chave GPG instalada"
        else
            log_error "Falha ao baixar chave GPG"
        fi
        
        echo "50" ; sleep 0.2
        log_info "Adicionando repositório Playit"
        if sudo curl -fsSL -o /etc/apt/sources.list.d/playit-cloud.list \
            https://playit-cloud.github.io/ppa/playit-cloud.list; then
            log_info "Repositório adicionado"
        else
            log_error "Falha ao adicionar repositório"
        fi
        
        echo "70" ; sleep 0.2
        log_info "Atualizando cache do apt"
        sudo apt update
        
        echo "85" ; sleep 0.2
        log_info "Instalando Playit"
        sudo apt install -y playit
        
        echo "100" ; sleep 0.2
    ) | dialog \
        --title "Instalando Playit" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --gauge "Processando..." 10 70 0
    
    sleep 1
    
    if command -v playit &>/dev/null; then
        local playit_version=$(playit --version 2>/dev/null || echo "Instalado")
        log_info "Playit instalado com sucesso: $playit_version"
        dialog --title "✓ Sucesso" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✓ Playit instalado com sucesso!\n\nVersão: $playit_version" 9 50
        return 0
    else
        log_error "Playit não foi instalado corretamente"
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✗ Falha ao instalar Playit.\n\n⚠️ O Pawn continuará funcionando.\n\nVerifique: $LOG_FILE" 11 55
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# FUNÇÕES DE EXTRAÇÃO (MANTIDAS)
# ════════════════════════════════════════════════════════════════

extract_with_known_pass() {
    local file="$1"
    local pass="$2"
    local name=$(basename "$file")

    (
        echo "10" ; sleep 0.1
        echo "50" ; echo "# Extraindo com senha..."
        
        if unzip -q -o -P "$pass" "$file" 2>/dev/null; then
            echo "100" ; echo "# Concluído!"
        else
            echo "100" ; echo "# Erro!"
        fi
    ) | dialog \
        --title "Extraindo Arquivo" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --gauge "Processando: $name" 10 70 0

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        rm -f "$file"
        dialog --title "✓ Sucesso" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✓ Arquivo extraído!\n\n→ $name" 9 55
        return 0
    else
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✗ Falha na extração!\n\nArquivo: $name" 9 50
        return 1
    fi
}

extract_with_pass_manual() {
    local file="$1"
    local name=$(basename "$file")
    local max_attempts=3

    for ((i=1; i<=$max_attempts; i++)); do
        local pass=$(dialog --stdout \
            --title "Senha Necessária ($i/$max_attempts)" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --insecure \
            --passwordbox "Digite a senha para:\n\n→ $name" 11 60)
        
        [ $? -ne 0 ] && return 1
        [ -z "$pass" ] && continue
        
        (
            echo "50" ; echo "# Extraindo..."
            unzip -q -o -P "$pass" "$file" 2>/dev/null && echo "100"
        ) | dialog \
            --title "Extraindo ($i/$max_attempts)" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --gauge "$name" 10 70 0
        
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            rm -f "$file"
            dialog --title "✓ Sucesso" \
                --backtitle "Instalador Wine Pawn + Playit v8.0" \
                --msgbox "✓ Arquivo extraído!" 7 40
            return 0
        fi
    done
    
    dialog --title "✗ Limite Excedido" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --msgbox "✗ Tentativas esgotadas." 7 40
    return 1
}

# ════════════════════════════════════════════════════════════════
# DOWNLOAD MEDIAFIRE (MANTIDO)
# ════════════════════════════════════════════════════════════════

download_mediafire() {
    local url=$(dialog --stdout \
        --title "MediaFire Download" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --inputbox "Cole a URL do MediaFire:" 10 70)
    
    [ $? -ne 0 ] || [ -z "$url" ] && return
    
    url=$(echo "$url" | tr -d ' \n\r')
    
    if ! echo "$url" | grep -qE "mediafire\.com"; then
        dialog --title "Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✗ URL inválida!" 7 40
        return
    fi
    
    local filename=$(echo "$url" | grep -oP '/file/[^/]+/\K[^/]+' | head -1)
    
    [ -z "$filename" ] && filename="download.zip"
    
    # Pergunta sobre senha
    local global_pass=""
    dialog --title "Arquivo Protegido?" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --yesno "O arquivo tem senha?" 8 50
    
    if [ $? -eq 0 ]; then
        global_pass=$(dialog --stdout \
            --title "Senha" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --insecure \
            --passwordbox "Digite a senha:" 9 50)
    fi
    
    # Obter link
    local html_file="$TEMP_DIR/mediafire.html"
    
    (
        echo "50" ; echo "# Obtendo link..."
        curl -sL -A "Mozilla/5.0" "$url" -o "$html_file" 2>/dev/null
        echo "100"
    ) | dialog \
        --title "Processando" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --gauge "Conectando..." 10 70 0
    
    [ ! -f "$html_file" ] && return
    
    local link=$(grep -oP 'id="downloadButton"[^>]*href="\K[^"]+' "$html_file" | head -1)
    
    if [ -z "$link" ]; then
        link=$(grep -oP 'https?://download[0-9]*\.mediafire\.com/[^"'\''<> ]+' "$html_file" | head -1)
    fi
    
    rm -f "$html_file"
    
    [ -z "$link" ] && return
    
    link=$(echo "$link" | sed 's/&amp;/\&/g')
    
    # Download
    (
        wget -q --show-progress -U "Mozilla/5.0" "$link" -O "$filename" 2>&1 | \
        stdbuf -o0 tr '\r' '\n' | \
        grep --line-buffered -o '[0-9]*%' | \
        sed -u 's/%//'
    ) | dialog \
        --title "Baixando: $filename" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --gauge "Aguarde..." 10 70 0
    
    [ ! -f "$filename" ] && return
    
    # Extração
    if [ -n "$global_pass" ]; then
        extract_with_known_pass "$filename" "$global_pass"
    else
        dialog --title "Download Concluído" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --yesno "Extrair agora?" 8 40
        
        [ $? -eq 0 ] && extract_with_pass_manual "$filename"
    fi
}

# ════════════════════════════════════════════════════════════════
# STATUS DO SISTEMA
# ════════════════════════════════════════════════════════════════

show_status() {
    local wine_status="✗ Não instalado"
    local wine_path="N/A"
    
    if command -v wine &>/dev/null; then
        wine_status="✓ $(wine --version 2>/dev/null | head -1)"
        wine_path=$(which wine 2>/dev/null)
    fi
    
    local playit_status="✗ Não instalado"
    if command -v playit &>/dev/null; then
        playit_status="✓ $(playit --version 2>/dev/null | head -1 || echo 'Instalado')"
    fi
    
    local vscode_status="✗ Não configurado"
    if [ -f ".vscode/settings.json" ] && [ -f ".vscode/tasks.json" ]; then
        vscode_status="✓ Configurado completo"
    elif [ -f ".vscode/settings.json" ]; then
        vscode_status="⚠ Configurado parcial"
    fi
    
    local ext_status="✗ Não instaladas (0/2)"
    if command -v code &>/dev/null; then
        local count=0
        code --list-extensions 2>/dev/null | grep -qi "southclaws.vscode-pawn" && ((count++))
        code --list-extensions 2>/dev/null | grep -qi "sanaajani.taskrunnercode" && ((count++))
        
        if [ $count -eq 2 ]; then
            ext_status="✓ Todas instaladas (2/2)"
        elif [ $count -eq 1 ]; then
            ext_status="⚠ Parcial (1/2)"
        fi
    else
        ext_status="✗ VS Code não disponível"
    fi
    
    local compiler_status="✗ Não detectado"
    if [ -f "pawno/pawncc.exe" ]; then
        compiler_status="✓ pawno/pawncc.exe"
    elif [ -f "pawncc/pawncc.exe" ]; then
        compiler_status="✓ pawncc/pawncc.exe"
    elif [ -f "pawncc.exe" ]; then
        compiler_status="✓ ./pawncc.exe"
    fi
    
    dialog --title "Status do Sistema" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --msgbox "══════════════════════════════════════

🍷 WINE
   Status: $wine_status
   Path: $wine_path

📦 COMPILADOR PAWN
   Status: $compiler_status

⚙️ VS CODE
   Config: $vscode_status

🔌 EXTENSÕES
   Status: $ext_status

🌐 PLAYIT
   Status: $playit_status

📋 LOG DE DEBUG
   Arquivo: $LOG_FILE

══════════════════════════════════════" 24 70
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO PERSONALIZADA (MELHORADA)
# ════════════════════════════════════════════════════════════════

show_config_menu() {
    local wine_check=$(check_wine)
    local vscode_check=$(check_vscode)
    local ext_check=$(check_extensions)
    local playit_check=$(check_playit)
    
    local choices=$(dialog --stdout \
        --title "Instalação Personalizada" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --checklist "Selecione os componentes (ESPAÇO marca/desmarca):" 16 75 4 \
        "1" "Wine 32-bit - $wine_check" off \
        "2" "VS Code Config - $vscode_check" off \
        "3" "Extensões - $ext_check" off \
        "4" "Playit - $playit_check" off)
    
    [ $? -ne 0 ] || [ -z "$choices" ] && return
    
    local count=$(echo "$choices" | wc -w)
    
    dialog --title "Confirmação de Instalação" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --yesno "Instalar $count componente(s) selecionado(s)?\n\nContinuar?" 9 50
    
    [ $? -ne 0 ] && return
    
    local installed=0
    local failed=0
    local current=1
    
    log_info "========== INSTALAÇÃO PERSONALIZADA INICIADA =========="
    
    if echo "$choices" | grep -q "1"; then
        dialog --title "Instalando ($current/$count)" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --infobox "Instalando Wine..." 6 50
        
        if install_wine; then
            ((installed++))
            log_info "Wine: SUCESSO"
        else
            ((failed++))
            log_error "Wine: FALHA"
        fi
        ((current++))
        sleep 1
    fi
    
    if echo "$choices" | grep -q "2"; then
        dialog --title "Instalando ($current/$count)" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --infobox "Configurando VS Code..." 6 50
        
        if configure_vscode; then
            ((installed++))
            log_info "VS Code: SUCESSO"
        else
            ((failed++))
            log_error "VS Code: FALHA"
        fi
        ((current++))
        sleep 1
    fi
    
    if echo "$choices" | grep -q "3"; then
        dialog --title "Instalando ($current/$count)" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --infobox "Instalando extensões..." 6 50
        
        if install_extensions; then
            ((installed++))
            log_info "Extensões: SUCESSO"
        else
            ((failed++))
            log_error "Extensões: FALHA"
        fi
        ((current++))
        sleep 1
    fi
    
    if echo "$choices" | grep -q "4"; then
        dialog --title "Instalando ($current/$count)" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --infobox "Instalando Playit..." 6 50
        
        if install_playit; then
            ((installed++))
            log_info "Playit: SUCESSO"
        else
            ((failed++))
            log_error "Playit: FALHA"
        fi
    fi
    
    log_info "========== INSTALAÇÃO PERSONALIZADA FINALIZADA =========="
    log_info "Resultado: $installed instalados, $failed falhas de $count selecionados"
    
    local message="Instalação Personalizada Concluída!\n\n"
    message+="Resultado:\n"
    message+="✓ Instalados: $installed\n"
    message+="✗ Falhas: $failed\n"
    message+="Total selecionado: $count\n\n"
    
    if [ $failed -eq 0 ]; then
        message+="✓ Tudo certo!"
    else
        message+="⚠ Verifique o log: $LOG_FILE"
    fi
    
    dialog --title "Instalação Finalizada" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --msgbox "$message" 14 50
}

# ════════════════════════════════════════════════════════════════
# EXECUTAR PLAYIT
# ════════════════════════════════════════════════════════════════

run_playit() {
    if ! command -v playit &>/dev/null; then
        dialog --title "Playit Não Instalado" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "✗ Playit não está instalado!\n\nInstale-o primeiro no menu principal." 9 50
        return
    fi
    
    dialog --title "Executar Playit" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --yesno "💡 O Playit permite expor seu servidor\nna internet sem abrir portas.\n\nO menu será fechado para executar.\n\nContinuar?" 12 55
    
    if [ $? -eq 0 ]; then
        clear
        echo "════════════════════════════════════════"
        echo "  🌐 Executando Playit..."
        echo "════════════════════════════════════════"
        echo ""
        log_info "Playit executado pelo usuário"
        playit
    fi
}

# ════════════════════════════════════════════════════════════════
# VER LOG DE DEBUG
# ════════════════════════════════════════════════════════════════

show_debug_log() {
    if [ ! -f "$LOG_FILE" ]; then
        dialog --title "Log não encontrado" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --msgbox "Nenhum log de debug disponível ainda." 7 50
        return
    fi
    
    local lines=$(wc -l < "$LOG_FILE")
    
    dialog --title "Log de Debug ($lines linhas)" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --textbox "$LOG_FILE" 20 75
}

# ════════════════════════════════════════════════════════════════
# MENU PRINCIPAL
# ════════════════════════════════════════════════════════════════

show_menu() {
    dialog --stdout \
        --title "Menu Principal" \
        --backtitle "Instalador Wine Pawn + Playit v8.0" \
        --menu "Escolha uma opção:" 18 70 7 \
        "1" "Instalação Personalizada (Escolher componentes)" \
        "2" "MediaFire Download" \
        "3" "Status do Sistema" \
        "4" "Executar Playit" \
        "5" "Ver Log de Debug" \
        "0" "Sair"
}

# ════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════

# Limpa log antigo se for muito grande (>10MB)
if [ -f "$LOG_FILE" ]; then
    local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    [ "$size" -gt 10485760 ] && rm -f "$LOG_FILE"
fi

log_info "=========================================="
log_info "Instalador Wine Pawn + Playit v8.0 INICIADO"
log_info "=========================================="

dialog --title "Bem-vindo" \
    --backtitle "Instalador Wine Pawn + Playit v8.0" \
    --msgbox "🚀 Instalador de Ambiente Pawn v8.0\n\n✓ Instalação Personalizada: Escolha componentes\n✓ MediaFire: Download e extração\n✓ Status: Veja o que está instalado\n✓ Playit: Execute o túnel de rede\n✓ Debug Log: Veja logs detalhados\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nNOVO NA v8.0:\n• Sistema de log detalhado\n• Detecção melhorada de erros\n• Relatórios mais informativos\n• Retornos de função corrigidos\n• Interface simplificada\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\nUse SETAS para navegar\nENTER para selecionar" 24 65

while true; do
    choice=$(show_menu)
    
    if [ $? -ne 0 ]; then
        dialog --title "Confirmação" \
            --backtitle "Instalador Wine Pawn + Playit v8.0" \
            --yesno "Deseja realmente sair?" 7 35
        
        if [ $? -eq 0 ]; then
            log_info "Instalador encerrado pelo usuário"
            break
        fi
        continue
    fi
    
    case $choice in
        1) show_config_menu ;;
        2) download_mediafire ;;
        3) show_status ;;
        4) run_playit ;;
        5) show_debug_log ;;
        0) 
            log_info "Instalador encerrado pelo usuário"
            break 
            ;;
    esac
done

clear
echo ""
echo "════════════════════════════════════════"
echo "  ✅ Instalador encerrado. Até logo!"
echo "════════════════════════════════════════"
echo ""
echo "💡 Dica: Para ver o log completo, execute:"
echo "   cat $LOG_FILE"
echo ""

log_info "=========================================="
log_info "Instalador Wine Pawn + Playit v8.0 ENCERRADO"
log_info "=========================================="
