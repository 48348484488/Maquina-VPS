#!/bin/bash

# ════════════════════════════════════════════════════════════════
# Instalador Wine Pawn + Playit v8.3 - COM EXTRAÇÃO AVANÇADA
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
# CONFIGURAR COMANDO 'menu' (FUNÇÃO PRINCIPAL)
# ════════════════════════════════════════════════════════════════

setup_menu_command() {
    local script_path=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$PWD/$0")
    local script_name=$(basename "$0")
    
    log_info "Configurando comando 'menu'"
    log_info "Script path: $script_path"
    
    # Remove script_path se for relativo
    if [[ "$script_path" == "./"* ]]; then
        script_path="$PWD/${script_path#./}"
    fi
    
    # Cria backup do .bashrc
    if [ -f ~/.bashrc ]; then
        cp ~/.bashrc ~/.bashrc.backup.$(date +%s) 2>/dev/null
        log_info "Backup do .bashrc criado"
    fi
    
    # Remove aliases antigos do 'menu' se existirem
    if grep -q "alias menu=" ~/.bashrc 2>/dev/null; then
        sed -i '/alias menu=/d' ~/.bashrc
        log_info "Alias antigo do 'menu' removido"
    fi
    
    # Adiciona novo alias e configurações
    cat >> ~/.bashrc << BASHEOF

# ════════════════════════════════════════════════════════════════
# Comando 'menu' - Instalador Wine Pawn + Playit v8.3
# Adicionado automaticamente em $(date '+%Y-%m-%d %H:%M:%S')
# ════════════════════════════════════════════════════════════════
alias menu='bash "$script_path"'

# Configuração Wine 32-bit
mkdir -p ~/.wine-runtime 2>/dev/null
export XDG_RUNTIME_DIR=~/.wine-runtime
export WINEARCH=win32
export WINEPREFIX=~/.wine
export WINEDEBUG=-all
export DISPLAY=:0
BASHEOF
    
    log_info "Comando 'menu' adicionado ao .bashrc"
    
    # Tenta recarregar o .bashrc
    source ~/.bashrc 2>/dev/null || true
    
    return 0
}

# ════════════════════════════════════════════════════════════════
# FUNÇÕES DE VERIFICAÇÃO
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

check_menu_command() {
    if grep -q "alias menu=" ~/.bashrc 2>/dev/null; then
        echo "✓ Configurado"
        return 0
    else
        echo "✗ Não configurado"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# DETECTAR TIPO DE ARQUIVO
# ════════════════════════════════════════════════════════════════

detect_file_type() {
    local file="$1"
    
    # Verificar primeiros bytes do arquivo
    local header=$(hexdump -n 4 -e '4/1 "%02x"' "$file" 2>/dev/null)
    
    log_info "Header do arquivo: $header"
    
    case "$header" in
        504b0304|504b0506|504b0708)
            echo "zip"
            ;;
        3c21444f|3c68746d|3c48544d|3c3f786d)
            echo "html"
            ;;
        *)
            # Tentar com 'file' command
            if command -v file &>/dev/null; then
                local file_output=$(file -b "$file" | tr '[:upper:]' '[:lower:]')
                log_info "File command: $file_output"
                
                if echo "$file_output" | grep -q "zip"; then
                    echo "zip"
                elif echo "$file_output" | grep -q "html\|xml"; then
                    echo "html"
                else
                    echo "unknown"
                fi
            else
                echo "unknown"
            fi
            ;;
    esac
}

# ════════════════════════════════════════════════════════════════
# DETECTAR SERVIDOR SAMP
# ════════════════════════════════════════════════════════════════

find_samp_server() {
    local locations=(
        "./samp-server.exe"
        "./server/samp-server.exe"
        "./samp/samp-server.exe"
        "./SA-MP/samp-server.exe"
        "./SAMP/samp-server.exe"
        "./gamemodes/../samp-server.exe"
    )
    
    for loc in "${locations[@]}"; do
        if [ -f "$loc" ]; then
            echo "$loc"
            return 0
        fi
    done
    
    # Busca recursiva (limitada a 3 níveis)
    local found=$(find . -maxdepth 3 -name "samp-server.exe" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAR WINE
# ════════════════════════════════════════════════════════════════

install_wine() {
    log_info "Iniciando instalação do Wine"
    
    # Verifica se já está instalado
    if command -v wine &>/dev/null; then
        local wine_version=$(wine --version 2>/dev/null | head -1)
        log_info "Wine já instalado: $wine_version"
        dialog --title "Wine Já Instalado" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✓ Wine já está instalado!\n\nVersão: $wine_version" 9 50
        return 0
    fi
    
    # Aviso sobre tempo de instalação
    dialog --title "⏱️ Instalação do Wine" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
        setup_menu_command
        
        echo "98" ; sleep 0.2
        log_info "Recarregando configurações"
        source ~/.bashrc 2>/dev/null || true
        
        echo "100" ; sleep 0.2
        log_info "Instalação concluída"
    ) | dialog \
        --title "Instalando Wine" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --gauge "Iniciando instalação... (pode demorar de 2 a 5 minutos)" 10 70 0
    
    sleep 2
    source ~/.bashrc 2>/dev/null || true
    
    if command -v wine &>/dev/null; then
        local wine_version=$(wine --version 2>/dev/null | head -1)
        log_info "Wine instalado com sucesso: $wine_version"
        dialog --title "✓ Sucesso" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✓ Wine instalado com sucesso!\n\nVersão: $wine_version\n\n💡 Dica: Digite 'menu' para abrir este instalador" 12 55
        return 0
    else
        log_error "Wine não está disponível após instalação"
        dialog --title "⚠️ Atenção" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "⚠️ Instalação concluída mas Wine não está no PATH.\n\nSOLUÇÕES:\n1. Execute: source ~/.bashrc\n2. Feche e reabra o terminal\n3. Reinicie este script\n\nSe persistir, verifique: $LOG_FILE" 14 60
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# CONFIGURAR VS CODE
# ════════════════════════════════════════════════════════════════

configure_vscode() {
    log_info "Iniciando configuração do VS Code"
    
    mkdir -p .vscode
    
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
                    if [ -f "$OLDPWD/.vscode/settings.json" ]; then
                        cp "$OLDPWD/.vscode/settings.json" "$OLDPWD/.vscode/settings.json.backup"
                        log_info "Backup de settings.json criado"
                    fi
                    
                    cp -r vscode/* "$OLDPWD/.vscode/" 2>/dev/null
                    log_info "Arquivos copiados"
                    
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
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --gauge "Processando..." 10 70 0
    
    sleep 1
    
    if [ -f ".vscode/settings.json" ]; then
        if [ -f ".vscode/tasks.json" ]; then
            log_info "VS Code configurado completamente"
            dialog --title "✓ Sucesso" \
                --backtitle "Instalador Wine Pawn + Playit v8.3" \
                --msgbox "✓ VS Code configurado!\n\n• settings.json criado\n• tasks.json instalado" 10 50
            return 0
        else
            log_info "VS Code configurado parcialmente (sem tasks.json)"
            dialog --title "⚠️ Parcial" \
                --backtitle "Instalador Wine Pawn + Playit v8.3" \
                --msgbox "⚠️ Configuração parcial:\n\n• settings.json: OK\n• tasks.json: Falhou\n\nVocê pode criar tasks.json manualmente." 11 55
            return 0
        fi
    else
        log_error "Falha ao criar settings.json"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# INSTALAR EXTENSÕES
# ════════════════════════════════════════════════════════════════

install_extensions() {
    log_info "Iniciando instalação de extensões"
    
    if ! command -v code &>/dev/null; then
        log_error "VS Code não encontrado"
        dialog --title "Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ VS Code não está instalado!\n\nNo GitHub Codespaces, o VS Code já está instalado.\nSe estiver em outro ambiente, instale o VS Code primeiro." 11 60
        return 1
    fi
    
    local ext_pawn_installed=false
    local ext_task_installed=false
    
    code --list-extensions 2>/dev/null | grep -qi "southclaws.vscode-pawn" && ext_pawn_installed=true
    code --list-extensions 2>/dev/null | grep -qi "sanaajani.taskrunnercode" && ext_task_installed=true
    
    if [ "$ext_pawn_installed" = true ] && [ "$ext_task_installed" = true ]; then
        log_info "Extensões já instaladas"
        dialog --title "Extensões Já Instaladas" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --gauge "Processando..." 10 70 0
    
    sleep 2
    
    local count=0
    code --list-extensions 2>/dev/null | grep -qi "southclaws.vscode-pawn" && ((count++))
    code --list-extensions 2>/dev/null | grep -qi "sanaajani.taskrunnercode" && ((count++))
    
    log_info "Extensões instaladas: $count/2"
    
    if [ $count -eq 2 ]; then
        dialog --title "✓ Sucesso" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✓ Extensões instaladas com sucesso!\n\nInstaladas: $count/2" 9 50
        return 0
    elif [ $count -eq 1 ]; then
        dialog --title "⚠️ Parcial" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "⚠️ Instalação parcial: $count/2\n\nRecarregue a página (F5) e tente novamente." 10 55
        return 0
    else
        log_error "Nenhuma extensão foi instalada"
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ Falha ao instalar extensões.\n\nVerifique o log: $LOG_FILE" 9 50
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# INSTALAR PLAYIT
# ════════════════════════════════════════════════════════════════

install_playit() {
    log_info "Iniciando instalação do Playit"
    
    if command -v playit &>/dev/null; then
        local playit_version=$(playit --version 2>/dev/null || echo "instalado")
        log_info "Playit já instalado: $playit_version"
        dialog --title "Playit Já Instalado" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --gauge "Processando..." 10 70 0
    
    sleep 1
    
    if command -v playit &>/dev/null; then
        local playit_version=$(playit --version 2>/dev/null || echo "Instalado")
        log_info "Playit instalado com sucesso: $playit_version"
        dialog --title "✓ Sucesso" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✓ Playit instalado com sucesso!\n\nVersão: $playit_version" 9 50
        return 0
    else
        log_error "Playit não foi instalado corretamente"
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ Falha ao instalar Playit.\n\n⚠️ O Pawn continuará funcionando.\n\nVerifique: $LOG_FILE" 11 55
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# EXTRAIR ARQUIVO ZIP (COM SUPORTE A 7Z)
# ════════════════════════════════════════════════════════════════

extract_zip() {
    local file="$1"
    local pass="$2"
    local name=$(basename "$file")
    local work_dir=$(pwd)
    
    log_info "=========================================="
    log_info "EXTRAINDO ZIP"
    log_info "Arquivo: $file"
    log_info "Destino: $work_dir"
    log_info "=========================================="
    
    # Decidir qual ferramenta usar
    local use_7z=0
    
    # Testar com unzip primeiro
    local test_output=$(unzip -t "$file" 2>&1)
    
    if echo "$test_output" | grep -qi "unsupported compression"; then
        log_info "Método de compressão não suportado pelo unzip, usando 7z"
        use_7z=1
        
        if ! command -v 7z &>/dev/null; then
            dialog --title "⚠️ 7z Necessário" \
                --backtitle "Instalador Wine Pawn + Playit v8.3" \
                --msgbox "Este arquivo requer o 7z para extrair.\n\nInstalando 7z..." 9 50
            
            (
                echo "50" ; echo "# Instalando p7zip-full..."
                sudo apt-get update -qq
                sudo apt-get install -y p7zip-full
                echo "100"
            ) | dialog \
                --title "Instalando 7z" \
                --backtitle "Instalador Wine Pawn + Playit v8.3" \
                --gauge "Aguarde..." 10 60 0
        fi
    fi
    
    # Usar 7z se necessário
    if [ $use_7z -eq 1 ]; then
        local extract_cmd="7z x -y"
        [ -n "$pass" ] && extract_cmd="7z x -y -p$pass"
        
        log_info "Comando: $extract_cmd '$file'"
        
        (
            echo "50" ; echo "# Extraindo com 7z..."
            local extract_output
            extract_output=$($extract_cmd "$file" -o"$work_dir" 2>&1)
            local extract_result=$?
            
            echo "$extract_output" >> "$LOG_FILE"
            
            echo "100"
            
            if [ $extract_result -eq 0 ]; then
                log_info "Extração com 7z bem-sucedida"
                
                # Contar arquivos extraídos
                local file_count=$(echo "$extract_output" | grep -c "^Extracting")
                log_info "Arquivos extraídos: $file_count"
                
                # Remover ZIP original
                rm -f "$file"
                
                # Listar arquivos
                local file_list=$(ls -lh "$work_dir" | tail -n +2 | head -15)
                
                dialog --title "✓ Sucesso" \
                    --backtitle "Instalador Wine Pawn + Playit v8.3" \
                    --msgbox "✓ Extração concluída com 7z!\n\nArquivo: $name\nArquivos extraídos: $file_count\nLocal: $work_dir\n\nUse 'ls -la' para ver todos os arquivos" 14 60
                
                return 0
            else
                log_error "Falha na extração com 7z. Código: $extract_result"
                
                if echo "$extract_output" | grep -qi "wrong password\|cannot open encrypted"; then
                    dialog --title "✗ Senha Incorreta" \
                        --backtitle "Instalador Wine Pawn + Playit v8.3" \
                        --msgbox "✗ A senha fornecida está incorreta.\n\nTente novamente com a senha correta." 9 50
                    return 1
                else
                    dialog --title "✗ Erro" \
                        --backtitle "Instalador Wine Pawn + Playit v8.3" \
                        --msgbox "✗ Falha na extração com 7z\n\nArquivo: $file\nLog: $LOG_FILE" 10 55
                    return 1
                fi
            fi
        ) | dialog \
            --title "Extraindo: $name" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --gauge "Processando..." 10 70 0
        
        return $?
    fi
    
    # Usar unzip (método padrão)
    (
        echo "20" ; echo "# Verificando integridade..."
        
        if [ -n "$pass" ]; then
            if ! unzip -t -P "$pass" "$file" &>/dev/null; then
                log_error "Senha incorreta ou arquivo corrompido"
                dialog --title "✗ Erro" \
                    --backtitle "Instalador Wine Pawn + Playit v8.3" \
                    --msgbox "✗ Senha incorreta ou arquivo corrompido\n\nVerifique a senha e tente novamente." 9 55
                echo "100"
                return 1
            fi
        else
            if ! unzip -t "$file" &>/dev/null; then
                log_error "Arquivo ZIP corrompido"
                dialog --title "✗ Erro" \
                    --backtitle "Instalador Wine Pawn + Playit v8.3" \
                    --msgbox "✗ Arquivo ZIP corrompido" 7 40
                echo "100"
                return 1
            fi
        fi
        
        echo "60" ; echo "# Extraindo arquivos..."
        
        # Extrair
        local extract_output
        if [ -n "$pass" ]; then
            extract_output=$(unzip -o -P "$pass" "$file" -d "$work_dir" 2>&1)
        else
            extract_output=$(unzip -o "$file" -d "$work_dir" 2>&1)
        fi
        
        local extract_result=$?
        echo "$extract_output" >> "$LOG_FILE"
        
        echo "100"
        
        if [ $extract_result -eq 0 ]; then
            log_info "Extração bem-sucedida"
            
            # Contar arquivos extraídos
            local file_count=$(echo "$extract_output" | grep "inflating:" | wc -l)
            log_info "Arquivos extraídos: $file_count"
            
            # Remover ZIP original
            rm -f "$file"
            
            dialog --title "✓ Sucesso" \
                --backtitle "Instalador Wine Pawn + Playit v8.3" \
                --msgbox "✓ Extração concluída!\n\nArquivo: $name\nArquivos extraídos: $file_count\nLocal: $work_dir" 11 55
            
            return 0
        else
            log_error "Falha na extração. Código: $extract_result"
            
            dialog --title "✗ Erro" \
                --backtitle "Instalador Wine Pawn + Playit v8.3" \
                --msgbox "✗ Falha na extração\n\nArquivo: $file\nLog: $LOG_FILE" 10 50
            
            return 1
        fi
    ) | dialog \
        --title "Extraindo: $name" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --gauge "Processando..." 10 70 0
    
    return ${PIPESTATUS[0]}
}

# ════════════════════════════════════════════════════════════════
# EXTRAIR LINK DIRETO DO MEDIAFIRE
# ════════════════════════════════════════════════════════════════

get_direct_link() {
    local url="$1"
    local html_file="$TEMP_DIR/page.html"
    
    log_info "Obtendo página do MediaFire: $url"
    
    # Baixar página HTML
    curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
         -H "Accept: text/html,application/xhtml+xml,application/xml" \
         -H "Accept-Language: en-US,en;q=0.9" \
         "$url" -o "$html_file" 2>&1 | tee -a "$LOG_FILE" >/dev/null
    
    if [ ! -f "$html_file" ]; then
        log_error "Falha ao baixar página HTML"
        return 1
    fi
    
    log_info "Página HTML salva em: $html_file"
    
    # Tentar múltiplos métodos para extrair o link
    local link=""
    
    # Método 1: Botão de download principal
    link=$(grep -oP 'id="downloadButton"[^>]*href="\K[^"]+' "$html_file" | head -1)
    log_info "Método 1 (downloadButton): $link"
    
    # Método 2: Link direto do servidor de download
    if [ -z "$link" ]; then
        link=$(grep -oP 'href="(https?://download[0-9]*\.mediafire\.com/[^"]+)"' "$html_file" | \
               sed 's/href="//; s/"$//' | head -1)
        log_info "Método 2 (download server): $link"
    fi
    
    # Método 3: Padrão alternativo
    if [ -z "$link" ]; then
        link=$(grep -oP 'https?://download[0-9]+\.mediafire\.com/[^\s"<>]+' "$html_file" | head -1)
        log_info "Método 3 (regex alternativo): $link"
    fi
    
    # Método 4: Script de download
    if [ -z "$link" ]; then
        link=$(grep -oP "window\.location\.href\s*=\s*['\"]([^'\"]+)['\"]" "$html_file" | \
               grep -oP "https?://[^'\"]+")
        log_info "Método 4 (window.location): $link"
    fi
    
    rm -f "$html_file"
    
    if [ -z "$link" ]; then
        log_error "Nenhum link de download encontrado"
        return 1
    fi
    
    # Decodificar entidades HTML
    link=$(echo "$link" | sed 's/&amp;/\&/g')
    
    echo "$link"
    return 0
}

# ════════════════════════════════════════════════════════════════
# DOWNLOAD MEDIAFIRE (COM EXTRAÇÃO AVANÇADA)
# ════════════════════════════════════════════════════════════════

download_mediafire() {
    local url=$(dialog --stdout \
        --title "MediaFire Download" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --inputbox "Cole a URL do MediaFire:" 10 70)
    
    [ $? -ne 0 ] || [ -z "$url" ] && return
    
    url=$(echo "$url" | tr -d ' \n\r')
    
    if ! echo "$url" | grep -qE "mediafire\.com"; then
        dialog --title "Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ URL inválida!\n\nUse um link do MediaFire." 9 50
        return
    fi
    
    local filename=$(echo "$url" | grep -oP '/file/[^/]+/\K[^/]+' | head -1)
    filename=$(echo "$filename" | sed 's/%252B/+/g; s/%2B/+/g; s/%20/ /g')
    [ -z "$filename" ] && filename="download.zip"
    
    log_info "Nome do arquivo: $filename"
    
    # Perguntar sobre senha
    local file_pass=""
    dialog --title "Arquivo Protegido?" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --yesno "O arquivo ZIP tem senha?" 8 50
    
    if [ $? -eq 0 ]; then
        file_pass=$(dialog --stdout \
            --title "Senha do Arquivo" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --insecure \
            --passwordbox "Digite a senha do ZIP:" 9 50)
        
        log_info "Senha fornecida pelo usuário"
    fi
    
    # Obter link direto
    (
        echo "50" ; echo "# Obtendo link direto..."
        sleep 1
        echo "100"
    ) | dialog \
        --title "Processando URL" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --gauge "Conectando ao MediaFire..." 10 70 0
    
    local link=$(get_direct_link "$url")
    
    if [ -z "$link" ]; then
        log_error "Falha ao obter link direto"
        
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ Não foi possível obter o link de download\n\nPossíveis causas:\n• Arquivo removido ou privado\n• Link expirado\n• Problema de conexão\n\nTente abrir o link no navegador.\n\nLog: $LOG_FILE" 15 60
        return
    fi
    
    log_info "Link direto obtido: ${link:0:80}..."
    
    # Download
    local output_file="$filename"
    
    (
        wget -q --show-progress \
             -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
             --content-disposition \
             "$link" \
             -O "$output_file" 2>&1 | \
        stdbuf -o0 tr '\r' '\n' | \
        grep --line-buffered -o '[0-9]*%' | \
        sed -u 's/%//'
    ) | dialog \
        --title "Baixando: $filename" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --gauge "Aguarde..." 10 70 0
    
    if [ ! -f "$output_file" ]; then
        log_error "Download falhou"
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ Falha no download\n\nArquivo não foi criado.\n\nLog: $LOG_FILE" 10 50
        return
    fi
    
    local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
    log_info "Download concluído. Tamanho: $file_size bytes"
    
    # Verificar tipo de arquivo
    local file_type=$(detect_file_type "$output_file")
    log_info "Tipo detectado: $file_type"
    
    if [ "$file_type" = "html" ]; then
        log_error "Arquivo baixado é HTML, não ZIP"
        
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ O arquivo baixado é uma página HTML, não um ZIP\n\nIsso significa que o MediaFire retornou uma\npágina de erro ou o link não é mais válido.\n\nArquivo salvo em: $output_file\nVocê pode abrir no navegador para ver o erro.\n\nTente abrir o link original no navegador." 15 65
        
        return
    fi
    
    if [ "$file_type" != "zip" ]; then
        log_error "Arquivo não é ZIP: $file_type"
        
        dialog --title "⚠ Aviso" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "⚠ Arquivo baixado não parece ser um ZIP\n\nTipo detectado: $file_type\nTamanho: $file_size bytes\nLocal: $output_file\n\nVocê pode tentar extrair manualmente." 13 60
        
        return
    fi
    
    # Extrair
    dialog --title "Download Concluído" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --yesno "✓ Download concluído!\n\nArquivo: $filename\nTamanho: $file_size bytes\n\nExtrair agora?" 11 55
    
    if [ $? -eq 0 ]; then
        log_info "Tentando extrair arquivo..."
        
        # Se não tem senha, tentar sem senha primeiro
        if [ -z "$file_pass" ]; then
            log_info "Testando se arquivo tem senha..."
            if unzip -t "$output_file" &>/dev/null; then
                log_info "Arquivo sem senha"
                extract_zip "$output_file" ""
            else
                log_info "Arquivo protegido por senha"
                dialog --title "🔒 Senha Necessária" \
                    --backtitle "Instalador Wine Pawn + Playit v8.3" \
                    --msgbox "Este arquivo está protegido por senha.\n\nVocê precisará fornecer a senha para extrair." 9 55
                
                # Pedir senha até 3 vezes
                local max_tries=3
                for ((i=1; i<=$max_tries; i++)); do
                    file_pass=$(dialog --stdout \
                        --title "Senha Necessária ($i/$max_tries)" \
                        --backtitle "Instalador Wine Pawn + Playit v8.3" \
                        --insecure \
                        --passwordbox "Digite a senha:" 9 50)
                    
                    if [ -z "$file_pass" ]; then
                        log_info "Usuário cancelou"
                        dialog --title "✓ Arquivo Salvo" \
                            --backtitle "Instalador Wine Pawn + Playit v8.3" \
                            --msgbox "Arquivo salvo em:\n$output_file\n\nVocê pode extrair depois com:\nunzip $output_file" 10 60
                        return
                    fi
                    
                    log_info "Testando senha (tentativa $i)..."
                    if unzip -t -P "$file_pass" "$output_file" &>/dev/null; then
                        log_info "Senha correta!"
                        extract_zip "$output_file" "$file_pass"
                        return
                    else
                        log_error "Senha incorreta (tentativa $i)"
                        if [ $i -lt $max_tries ]; then
                            dialog --title "✗ Senha Incorreta" \
                                --backtitle "Instalador Wine Pawn + Playit v8.3" \
                                --msgbox "Senha incorreta. Tente novamente.\n\nTentativas restantes: $((max_tries - i))" 9 50
                        fi
                    fi
                done
                
                log_error "Todas as tentativas de senha falharam"
                dialog --title "✗ Tentativas Esgotadas" \
                    --backtitle "Instalador Wine Pawn + Playit v8.3" \
                    --msgbox "Não foi possível extrair o arquivo.\n\nArquivo salvo em:\n$output_file\n\nVocê pode tentar extrair manualmente:\nunzip $output_file\n\nOu pedir a senha correta ao dono do arquivo." 14 60
            fi
        else
            # Senha foi fornecida no início
            extract_zip "$output_file" "$file_pass"
        fi
    else
        log_info "Extração pulada pelo usuário"
        dialog --title "✓ Arquivo Salvo" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "Arquivo salvo em:\n$output_file\n\nTamanho: $file_size bytes\n\nPara extrair depois:\nunzip $output_file" 11 55
    fi
    
    log_info "=========================================="
    log_info "PROCESSO FINALIZADO"
    log_info "=========================================="
}

# ════════════════════════════════════════════════════════════════
# INICIAR SERVIDOR SAMP
# ════════════════════════════════════════════════════════════════

start_samp_server() {
    log_info "Tentando iniciar servidor SA-MP"
    
    if ! command -v wine &>/dev/null; then
        dialog --title "Wine Não Instalado" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ Wine não está instalado!\n\nInstale o Wine primeiro no menu principal." 9 50
        return 1
    fi
    
    local server_path=$(find_samp_server)
    
    if [ -z "$server_path" ]; then
        dialog --title "Servidor Não Encontrado" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ samp-server.exe não encontrado!\n\nLocais procurados:\n• ./samp-server.exe\n• ./server/samp-server.exe\n• ./samp/samp-server.exe\n• (busca recursiva em 3 níveis)\n\nColoque o servidor SA-MP na pasta atual." 14 60
        return 1
    fi
    
    local server_dir=$(dirname "$server_path")
    local server_name=$(basename "$server_path")
    
    log_info "Servidor encontrado: $server_path"
    
    local cfg_exists=false
    if [ -f "$server_dir/server.cfg" ]; then
        cfg_exists=true
    fi
    
    local info_msg="📂 Servidor encontrado:\n$server_path\n\n"
    
    if [ "$cfg_exists" = true ]; then
        info_msg+="✓ server.cfg: Encontrado\n\n"
        
        local port=$(grep -i "^port" "$server_dir/server.cfg" 2>/dev/null | cut -d' ' -f2 | tr -d '\r')
        local hostname=$(grep -i "^hostname" "$server_dir/server.cfg" 2>/dev/null | cut -d' ' -f2- | tr -d '\r')
        
        [ -n "$port" ] && info_msg+="🔌 Porta: $port\n"
        [ -n "$hostname" ] && info_msg+="📝 Nome: $hostname\n\n"
    else
        info_msg+="⚠️ server.cfg: NÃO encontrado\n\n"
    fi
    
    info_msg+="O servidor será iniciado em uma nova janela.\n\n"
    info_msg+="💡 Dica: Use Playit para expor na internet!"
    
    dialog --title "Iniciar Servidor SA-MP" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --yesno "$info_msg" 18 65
    
    if [ $? -ne 0 ]; then
        return 0
    fi
    
    export XDG_RUNTIME_DIR=~/.wine-runtime
    export WINEARCH=win32
    export WINEPREFIX=~/.wine
    export WINEDEBUG=-all
    export DISPLAY=:0
    
    mkdir -p ~/.wine-runtime 2>/dev/null
    
    clear
    echo "════════════════════════════════════════════════════════"
    echo "  🎮 INICIANDO SERVIDOR SA-MP"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "📂 Localização: $server_path"
    echo "📁 Diretório: $server_dir"
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo ""
    
    log_info "Iniciando servidor: $server_path"
    
    cd "$server_dir"
    wine "$server_name"
    
    local exit_code=$?
    
    echo ""
    echo "════════════════════════════════════════════════════════"
    if [ $exit_code -eq 0 ]; then
        echo "  ✅ Servidor encerrado normalmente"
        log_info "Servidor encerrado: código $exit_code"
    else
        echo "  ⚠️ Servidor encerrado com código: $exit_code"
        log_error "Servidor encerrou com erro: código $exit_code"
    fi
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "Pressione ENTER para voltar ao menu..."
    read
    
    cd - >/dev/null 2>&1
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
    
    local server_status="✗ Não encontrado"
    local server_location="N/A"
    local server_path=$(find_samp_server)
    if [ -n "$server_path" ]; then
        server_status="✓ Encontrado"
        server_location="$server_path"
        
        local server_dir=$(dirname "$server_path")
        if [ -f "$server_dir/server.cfg" ]; then
            server_status+=" (com server.cfg)"
        else
            server_status+=" (sem server.cfg)"
        fi
    fi
    
    local menu_cmd_status=$(check_menu_command)
    
    local zip_7z_status="✗ Não instalado"
    if command -v 7z &>/dev/null; then
        zip_7z_status="✓ Instalado"
    fi
    
    dialog --title "Status do Sistema" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --msgbox "══════════════════════════════════════

🍷 WINE
   Status: $wine_status
   Path: $wine_path

📦 COMPILADOR PAWN
   Status: $compiler_status

🎮 SERVIDOR SA-MP
   Status: $server_status
   Local: $server_location

⚙️ VS CODE
   Config: $vscode_status

🔌 EXTENSÕES
   Status: $ext_status

🌐 PLAYIT
   Status: $playit_status

📦 7Z (Extração Avançada)
   Status: $zip_7z_status

⌨️ COMANDO 'menu'
   Status: $menu_cmd_status

📋 LOG DE DEBUG
   Arquivo: $LOG_FILE

💡 COMANDO RÁPIDO
   Digite: menu (para abrir este instalador)

══════════════════════════════════════" 32 75
}

# ════════════════════════════════════════════════════════════════
# CONFIGURAR COMANDO 'menu' MANUALMENTE
# ════════════════════════════════════════════════════════════════

configure_menu_command_manual() {
    local current_status=$(check_menu_command)
    
    dialog --title "Configurar Comando 'menu'" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --yesno "Status atual: $current_status\n\nEsta opção configura o comando 'menu' para\nque você possa abrir este instalador digitando\napenas 'menu' no terminal.\n\nO comando será adicionado ao ~/.bashrc\n\nContinuar?" 14 60
    
    if [ $? -ne 0 ]; then
        return 0
    fi
    
    (
        echo "20" ; sleep 0.3
        echo "# Configurando comando..."
        
        if setup_menu_command; then
            echo "80" ; sleep 0.3
            echo "# Recarregando configurações..."
            source ~/.bashrc 2>/dev/null || true
            echo "100"
        else
            echo "100"
        fi
    ) | dialog \
        --title "Configurando Comando 'menu'" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --gauge "Processando..." 10 70 0
    
    sleep 1
    
    if grep -q "alias menu=" ~/.bashrc 2>/dev/null; then
        dialog --title "✓ Sucesso" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✓ Comando 'menu' configurado!\n\nAgora você pode:\n\n1. Fechar e reabrir o terminal\n   OU\n2. Executar: source ~/.bashrc\n\nDepois disso, digite 'menu' para\nabrir este instalador!" 14 55
        return 0
    else
        dialog --title "✗ Erro" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ Falha ao configurar comando.\n\nVerifique: $LOG_FILE" 9 50
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO PERSONALIZADA
# ════════════════════════════════════════════════════════════════

show_config_menu() {
    local wine_check=$(check_wine)
    local vscode_check=$(check_vscode)
    local ext_check=$(check_extensions)
    local playit_check=$(check_playit)
    
    local choices=$(dialog --stdout \
        --title "Instalação Personalizada" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --checklist "Selecione os componentes (ESPAÇO marca/desmarca):" 16 75 4 \
        "1" "Wine 32-bit - $wine_check" off \
        "2" "VS Code Config - $vscode_check" off \
        "3" "Extensões - $ext_check" off \
        "4" "Playit - $playit_check" off)
    
    [ $? -ne 0 ] || [ -z "$choices" ] && return
    
    local count=$(echo "$choices" | wc -w)
    
    dialog --title "Confirmação de Instalação" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --yesno "Instalar $count componente(s) selecionado(s)?\n\nContinuar?" 9 50
    
    [ $? -ne 0 ] && return
    
    local installed=0
    local failed=0
    local current=1
    
    log_info "========== INSTALAÇÃO PERSONALIZADA INICIADA =========="
    
    if echo "$choices" | grep -q "1"; then
        dialog --title "Instalando ($current/$count)" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --msgbox "$message" 14 50
}

# ════════════════════════════════════════════════════════════════
# EXECUTAR PLAYIT
# ════════════════════════════════════════════════════════════════

run_playit() {
    if ! command -v playit &>/dev/null; then
        dialog --title "Playit Não Instalado" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "✗ Playit não está instalado!\n\nInstale-o primeiro no menu principal." 9 50
        return
    fi
    
    dialog --title "Executar Playit" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
            --msgbox "Nenhum log de debug disponível ainda." 7 50
        return
    fi
    
    local lines=$(wc -l < "$LOG_FILE")
    
    dialog --title "Log de Debug ($lines linhas)" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --textbox "$LOG_FILE" 20 75
}

# ════════════════════════════════════════════════════════════════
# MENU PRINCIPAL
# ════════════════════════════════════════════════════════════════

show_menu() {
    dialog --stdout \
        --title "Menu Principal" \
        --backtitle "Instalador Wine Pawn + Playit v8.3" \
        --menu "Escolha uma opção:" 21 72 9 \
        "1" "Instalação Personalizada (Escolher componentes)" \
        "2" "MediaFire Download (Com extração avançada 7z)" \
        "3" "Status do Sistema" \
        "4" "Iniciar Servidor SA-MP" \
        "5" "Executar Playit" \
        "6" "Configurar Comando 'menu'" \
        "7" "Ver Log de Debug" \
        "0" "Sair"
}

# ════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════

if [ -f "$LOG_FILE" ]; then
    local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    [ "$size" -gt 10485760 ] && rm -f "$LOG_FILE"
fi

log_info "=========================================="
log_info "Instalador Wine Pawn + Playit v8.3 INICIADO"
log_info "=========================================="

setup_menu_command

dialog --title "Bem-vindo" \
    --backtitle "Instalador Wine Pawn + Playit v8.3" \
    --msgbox "🚀 Instalador de Ambiente Pawn v8.3\n\n✓ Instalação Personalizada: Escolha componentes\n✓ MediaFire: Download e extração avançada\n✓ Suporte a 7z: Compressão não suportada pelo unzip\n✓ Status: Veja o que está instalado\n✓ Servidor SA-MP: Inicie seu servidor\n✓ Playit: Execute o túnel de rede\n✓ Comando 'menu': Configure acesso rápido\n✓ Debug Log: Veja logs detalhados\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nNOVO NA v8.3:\n• Extração avançada com 7z\n• Detecta método de compressão\n• Fallback automático unzip → 7z\n• Melhor detecção de arquivos HTML\n• Suporte a múltiplos formatos ZIP\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n💡 DICA: Após a instalação, digite 'menu'\n   no terminal para abrir este instalador!\n\nUse SETAS para navegar\nENTER para selecionar" 30 65

while true; do
    choice=$(show_menu)
    
    if [ $? -ne 0 ]; then
        dialog --title "Confirmação" \
            --backtitle "Instalador Wine Pawn + Playit v8.3" \
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
        4) start_samp_server ;;
        5) run_playit ;;
        6) configure_menu_command_manual ;;
        7) show_debug_log ;;
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
echo "💡 Dicas úteis:"
echo "   • Digite 'menu' para abrir o instalador"
echo "   • Use 'source ~/.bashrc' para recarregar"
echo "   • Log completo: cat $LOG_FILE"
echo ""

log_info "=========================================="
log_info "Instalador Wine Pawn + Playit v8.3 ENCERRADO"
log_info "=========================================="
