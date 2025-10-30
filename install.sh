#!/bin/bash

# ════════════════════════════════════════════════════════════════
# Instalador Wine Pawn + Playit v4.0
# Sistema de senha profissional + Interface moderna
# ════════════════════════════════════════════════════════════════

set -euo pipefail

# ════════════════════════════════════════════════════════════════
# CORES E SÍMBOLOS
# ════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

# ════════════════════════════════════════════════════════════════
# FUNÇÕES DE UTILIDADE
# ════════════════════════════════════════════════════════════════

print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}  ${BOLD}🚀 Instalador Wine Pawn + Playit v4.0${RESET}          ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  $1${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${RESET} $1"
}

print_error() {
    echo -e "${RED}✗${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${RESET} $1"
}

# ════════════════════════════════════════════════════════════════
# SISTEMA DE SENHA PROFISSIONAL
# ════════════════════════════════════════════════════════════════

read_password_secure() {
    local prompt="$1"
    local password=""
    local char=""
    local show_chars="${2:-true}"
    
    echo -ne "${CYAN}${prompt}${RESET} "
    
    # Salva configuração do terminal
    if [ -t 0 ]; then
        local old_stty=$(stty -g 2>/dev/null)
        stty -echo -icanon min 1 time 0 2>/dev/null
    fi
    
    while true; do
        # Lê um caractere por vez
        if IFS= read -r -n1 -s char 2>/dev/null; then
            # Enter (código ASCII 10 ou 13)
            if [[ "$char" == $'\n' ]] || [[ "$char" == $'\r' ]] || [[ -z "$char" ]]; then
                break
            fi
            
            # Backspace (código ASCII 127 ou 8)
            if [[ "$char" == $'\177' ]] || [[ "$char" == $'\b' ]]; then
                if [ ${#password} -gt 0 ]; then
                    password="${password%?}"
                    echo -ne "\b \b"
                fi
                continue
            fi
            
            # Ctrl+C (código ASCII 3)
            if [[ "$char" == $'\003' ]]; then
                echo ""
                if [ -t 0 ]; then
                    stty "$old_stty" 2>/dev/null
                fi
                return 130
            fi
            
            # Adiciona caractere à senha
            password+="$char"
            
            # Mostra asterisco ou oculta completamente
            if [ "$show_chars" = "true" ]; then
                echo -n "*"
            fi
        else
            break
        fi
    done
    
    # Restaura configuração do terminal
    if [ -t 0 ]; then
        stty "$old_stty" 2>/dev/null
    fi
    
    echo ""
    echo "$password"
}

verify_zip_has_password() {
    local zipfile="$1"
    
    # Tenta extrair primeiro arquivo sem senha
    if unzip -t "$zipfile" >/dev/null 2>&1; then
        return 1  # Sem senha
    fi
    
    # Verifica se o erro é por senha
    local test_output=$(unzip -t "$zipfile" 2>&1)
    if echo "$test_output" | grep -qi "password"; then
        return 0  # Com senha
    fi
    
    # Outro tipo de erro
    return 2
}

extract_zip_smart() {
    local zipfile="$1"
    local max_attempts=3
    
    print_step "📦 Processando Arquivo ZIP"
    
    # Verifica se o arquivo existe
    if [ ! -f "$zipfile" ]; then
        print_error "Arquivo não encontrado: $zipfile"
        return 1
    fi
    
    local filesize=$(du -h "$zipfile" | cut -f1)
    print_info "Arquivo: ${BOLD}$zipfile${RESET} (${filesize})"
    echo ""
    
    # Primeira tentativa: sem senha
    print_info "Verificando necessidade de senha..."
    sleep 0.5
    
    if unzip -q -o -d "." "$zipfile" 2>/dev/null; then
        print_success "Extração concluída sem senha!"
        rm -f "$zipfile"
        return 0
    fi
    
    # Verifica tipo de proteção
    verify_zip_has_password "$zipfile"
    local has_password=$?
    
    if [ $has_password -eq 1 ]; then
        print_error "Arquivo corrompido ou formato inválido"
        print_info "Arquivo mantido: ${BOLD}$zipfile${RESET}"
        return 1
    elif [ $has_password -eq 2 ]; then
        print_error "Erro desconhecido ao processar ZIP"
        print_info "Tente extrair manualmente: ${BOLD}unzip $zipfile${RESET}"
        return 1
    fi
    
    # Arquivo protegido por senha
    echo ""
    print_warning "Arquivo protegido por senha detectado"
    echo ""
    
    # Loop de tentativas
    for attempt in $(seq 1 $max_attempts); do
        print_step "🔐 Tentativa ${attempt}/${max_attempts}"
        
        # Dicas antes da primeira tentativa
        if [ $attempt -eq 1 ]; then
            echo -e "${YELLOW}💡 Dicas:${RESET}"
            echo "  • Digite a senha com cuidado"
            echo "  • Verifique se Caps Lock está desativado"
            echo "  • A senha não será exibida enquanto digita"
            echo ""
        fi
        
        # Lê a senha
        local password=$(read_password_secure "🔑 Digite a senha:")
        local read_status=$?
        
        # Verifica se foi cancelado (Ctrl+C)
        if [ $read_status -eq 130 ]; then
            echo ""
            print_warning "Operação cancelada pelo usuário"
            print_info "Arquivo mantido: ${BOLD}$zipfile${RESET}"
            return 1
        fi
        
        # Verifica se a senha está vazia
        if [ -z "$password" ]; then
            print_warning "Senha vazia não é válida"
            
            if [ $attempt -lt $max_attempts ]; then
                echo ""
                echo -ne "${YELLOW}Deseja tentar novamente? (S/n):${RESET} "
                read -r retry
                
                if [[ "$retry" =~ ^[Nn]$ ]]; then
                    print_info "Operação cancelada"
                    print_info "Arquivo mantido: ${BOLD}$zipfile${RESET}"
                    return 1
                fi
            fi
            continue
        fi
        
        # Tenta extrair com a senha
        echo ""
        print_info "Tentando extrair com a senha fornecida..."
        
        if unzip -q -o -P "$password" -d "." "$zipfile" 2>/dev/null; then
            echo ""
            print_success "Extração concluída com sucesso!"
            rm -f "$zipfile"
            return 0
        else
            print_error "Senha incorreta"
            
            if [ $attempt -lt $max_attempts ]; then
                echo ""
                echo -e "${YELLOW}💡 Sugestões:${RESET}"
                echo "  • Verifique se copiou a senha corretamente"
                echo "  • Confirme com quem enviou o arquivo"
                echo "  • Tente desativar Caps Lock"
                sleep 1
            fi
        fi
        
        echo ""
    done
    
    # Todas as tentativas falharam
    print_step "⚠️ Limite de Tentativas Atingido"
    
    print_error "Não foi possível extrair o arquivo"
    print_info "Arquivo mantido: ${BOLD}$zipfile${RESET}"
    echo ""
    echo -e "${YELLOW}Você pode tentar manualmente:${RESET}"
    echo -e "  ${BOLD}unzip -P \"SUA_SENHA\" $zipfile${RESET}"
    echo ""
    
    return 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO - ETAPA 1: VERIFICAÇÕES INICIAIS
# ════════════════════════════════════════════════════════════════

check_initial_setup() {
    print_header
    print_step "🔍 [1/9] Verificação Inicial"
    
    # Verifica extensões VS Code
    print_info "Verificando extensões do VS Code..."
    
    EXT_PAWN_INSTALLED=false
    EXT_TASK_INSTALLED=false
    
    if code --list-extensions 2>/dev/null | grep -q "southclaws.vscode-pawn"; then
        EXT_PAWN_INSTALLED=true
        print_success "Extensão Pawn já instalada"
    fi
    
    if code --list-extensions 2>/dev/null | grep -q "sanaajani.taskrunnercode"; then
        EXT_TASK_INSTALLED=true
        print_success "Extensão Task Runner já instalada"
    fi
    
    # Verifica diretórios
    echo ""
    print_info "Verificando estrutura de diretórios..."
    
    if [ -d "pawno" ] || [ -d "pawncc" ]; then
        print_success "Compilador Pawn detectado"
    fi
    
    if [ -d ".vscode" ]; then
        print_warning "Configuração .vscode/ existente será atualizada"
    fi
    
    sleep 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO - ETAPA 2: WINE
# ════════════════════════════════════════════════════════════════

install_wine() {
    print_header
    print_step "🍷 [2/9] Instalação do Wine"
    
    WINE_ALREADY_INSTALLED=false
    
    if command -v wine >/dev/null 2>&1; then
        local wine_version=$(wine --version 2>/dev/null)
        if [ -n "$wine_version" ]; then
            print_success "Wine já instalado: ${BOLD}$wine_version${RESET}"
            WINE_ALREADY_INSTALLED=true
            sleep 1
            return 0
        fi
    fi
    
    print_info "Iniciando instalação do Wine 32-bit..."
    print_warning "Este processo pode levar ${BOLD}2-5 minutos${RESET}"
    echo ""
    
    # Limpeza prévia
    print_info "Removendo instalações antigas..."
    sudo apt remove --purge wine wine32 wine64 -y >/dev/null 2>&1
    sudo apt autoremove -y >/dev/null 2>&1
    rm -rf ~/.wine
    
    # Configuração de repositório
    print_info "Configurando repositório Wine..."
    sudo dpkg --add-architecture i386 >/dev/null 2>&1
    sudo apt update >/dev/null 2>&1
    sudo mkdir -pm755 /etc/apt/keyrings >/dev/null 2>&1
    
    sudo wget -q -O /etc/apt/keyrings/winehq-archive.key \
        https://dl.winehq.org/wine-builds/winehq.key
    
    sudo wget -q -NP /etc/apt/sources.list.d/ \
        https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
    
    # Instalação
    print_info "Instalando Wine (pode demorar)..."
    sudo apt update >/dev/null 2>&1
    
    if ! sudo apt install --install-recommends winehq-stable -y >/dev/null 2>&1; then
        print_error "Falha na instalação do Wine"
        exit 1
    fi
    
    # Configuração do ambiente
    print_info "Configurando ambiente Wine 32-bit..."
    
    mkdir -p ~/.wine-runtime
    chmod 700 ~/.wine-runtime
    
    export XDG_RUNTIME_DIR=~/.wine-runtime
    export WINEARCH=win32
    export WINEPREFIX=~/.wine
    export WINEDEBUG=-all
    export DISPLAY=:0
    
    wineboot -u >/dev/null 2>&1
    
    # Adiciona ao .bashrc
    if ! grep -q "WINEARCH=win32" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOF'

# ════════════════════════════════════════════════════════════════
# Configuração Wine 32-bit (Instalador Pawn v4.0)
# NÃO REMOVER - Necessário para compilar Pawn
# ════════════════════════════════════════════════════════════════
mkdir -p ~/.wine-runtime 2>/dev/null
export XDG_RUNTIME_DIR=~/.wine-runtime
export WINEARCH=win32
export WINEPREFIX=~/.wine
export WINEDEBUG=-all
export DISPLAY=:0
EOF
    fi
    
    # Adiciona ao .bash_profile
    if [ -f ~/.bash_profile ]; then
        if ! grep -q "WINEARCH=win32" ~/.bash_profile; then
            cat >> ~/.bash_profile << 'EOF'

# ════════════════════════════════════════════════════════════════
# Configuração Wine 32-bit (Instalador Pawn v4.0)
# ════════════════════════════════════════════════════════════════
mkdir -p ~/.wine-runtime 2>/dev/null
export XDG_RUNTIME_DIR=~/.wine-runtime
export WINEARCH=win32
export WINEPREFIX=~/.wine
export WINEDEBUG=-all
export DISPLAY=:0
EOF
        fi
    fi
    
    source ~/.bashrc 2>/dev/null || true
    
    # Verificação final
    if command -v wine >/dev/null 2>&1; then
        local wine_version=$(wine --version 2>/dev/null)
        print_success "Wine instalado com sucesso: ${BOLD}$wine_version${RESET}"
    else
        print_error "Falha na instalação do Wine"
        exit 1
    fi
    
    sleep 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO - ETAPA 3: VERIFICAÇÃO CRÍTICA
# ════════════════════════════════════════════════════════════════

verify_wine_availability() {
    print_header
    print_step "🔍 [3/9] Verificação Crítica do Wine"
    
    source ~/.bashrc 2>/dev/null || true
    
    export WINEARCH=win32
    export WINEPREFIX=~/.wine
    export WINEDEBUG=-all
    export XDG_RUNTIME_DIR=~/.wine-runtime
    
    if ! command -v wine >/dev/null 2>&1; then
        echo ""
        print_error "Wine não está disponível no PATH atual"
        echo ""
        echo -e "${YELLOW}╔════════════════════════════════════════════════╗${RESET}"
        echo -e "${YELLOW}║  ⚠️  REINÍCIO DO TERMINAL NECESSÁRIO         ║${RESET}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "${CYAN}Escolha uma opção:${RESET}"
        echo ""
        echo "  ${BOLD}1)${RESET} Recarregar terminal automaticamente"
        echo "  ${BOLD}2)${RESET} Recarregar manualmente (source ~/.bashrc)"
        echo "  ${BOLD}3)${RESET} Fechar e reabrir o terminal"
        echo ""
        echo -ne "${CYAN}Opção [1/2/3]:${RESET} "
        read -r option
        
        case $option in
            1)
                exec bash "$0"
                ;;
            2)
                echo ""
                print_info "Execute: ${BOLD}source ~/.bashrc${RESET}"
                print_info "Depois execute novamente este script"
                exit 0
                ;;
            *)
                echo ""
                print_info "Feche e reabra o terminal, depois execute novamente"
                exit 0
                ;;
        esac
    fi
    
    print_success "Wine disponível: ${BOLD}$(which wine)${RESET}"
    sleep 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO - ETAPA 4: DEPENDÊNCIAS
# ════════════════════════════════════════════════════════════════

install_dependencies() {
    print_header
    print_step "📦 [4/9] Instalação de Dependências"
    
    local deps_needed=()
    
    command -v unzip >/dev/null 2>&1 || deps_needed+=("unzip")
    command -v zip >/dev/null 2>&1 || deps_needed+=("zip")
    command -v wget >/dev/null 2>&1 || deps_needed+=("wget")
    command -v curl >/dev/null 2>&1 || deps_needed+=("curl")
    
    if [ ${#deps_needed[@]} -eq 0 ]; then
        print_success "Todas as dependências já instaladas"
    else
        print_info "Instalando: ${BOLD}${deps_needed[*]}${RESET}"
        sudo apt install -y "${deps_needed[@]}" >/dev/null 2>&1
        print_success "Dependências instaladas com sucesso"
    fi
    
    sleep 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO - ETAPA 5: CONFIGURAÇÃO VS CODE
# ════════════════════════════════════════════════════════════════

configure_vscode() {
    print_header
    print_step "⚙️ [5/9] Configuração do VS Code"
    
    mkdir -p .vscode
    
    # Cria settings.json
    print_info "Criando settings.json..."
    cat > .vscode/settings.json << 'EOF'
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
EOF
    print_success "settings.json configurado"
    
    # Download tasks.json
    echo ""
    print_info "Baixando tasks.json..."
    
    if wget -q https://github.com/48348484488/Maquina-VPS/raw/74c1d4876c3342d3df52d7db0142fef90f05f4bd/task.zip 2>&1; then
        local filesize=$(du -h task.zip | cut -f1)
        print_success "Download concluído (${filesize})"
        
        print_info "Extraindo configurações..."
        unzip -q -o task.zip
        rm -f task.zip
        
        if [ -d "vscode" ]; then
            # Preserva settings.json
            if [ -f ".vscode/settings.json" ]; then
                mv .vscode/settings.json .vscode/settings.json.backup
            fi
            
            mv vscode/* .vscode/ 2>/dev/null
            rm -rf vscode
            
            # Restaura settings.json
            if [ -f ".vscode/settings.json.backup" ]; then
                mv .vscode/settings.json.backup .vscode/settings.json
            fi
        fi
        
        if [ -f ".vscode/tasks.json" ]; then
            print_success "tasks.json configurado"
        else
            print_error "tasks.json não encontrado no ZIP"
            exit 1
        fi
    else
        print_error "Falha no download do tasks.json"
        exit 1
    fi
    
    sleep 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO - ETAPA 6: EXTENSÕES
# ════════════════════════════════════════════════════════════════

install_extensions() {
    print_header
    print_step "🔌 [6/9] Instalação de Extensões"
    
    if [ "$EXT_PAWN_INSTALLED" = true ] && [ "$EXT_TASK_INSTALLED" = true ]; then
        print_success "Extensões já instaladas"
        sleep 1
        return 0
    fi
    
    if [ "$EXT_PAWN_INSTALLED" = false ]; then
        print_info "Instalando southclaws.vscode-pawn..."
        code --install-extension southclaws.vscode-pawn >/dev/null 2>&1
    fi
    
    if [ "$EXT_TASK_INSTALLED" = false ]; then
        print_info "Instalando sanaajani.taskrunnercode..."
        code --install-extension sanaajani.taskrunnercode >/dev/null 2>&1
    fi
    
    sleep 2
    
    # Verificação
    local ext_pawn=$(code --list-extensions 2>/dev/null | grep -c "southclaws.vscode-pawn" || echo 0)
    local ext_task=$(code --list-extensions 2>/dev/null | grep -c "sanaajani.taskrunnercode" || echo 0)
    local total=$((ext_pawn + ext_task))
    
    if [ "$total" -eq 2 ]; then
        print_success "Extensões instaladas [2/2]"
    elif [ "$total" -eq 1 ]; then
        print_warning "Extensões parcialmente instaladas [1/2]"
        print_info "Solução: Recarregue a página (F5)"
    else
        print_error "Erro ao instalar extensões"
        print_info "Solução: Recarregue a página (F5)"
    fi
    
    sleep 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO - ETAPA 7: DOWNLOAD MEDIAFIRE
# ════════════════════════════════════════════════════════════════

download_mediafire() {
    print_header
    print_step "📥 [7/9] Download MediaFire (Opcional)"
    
    echo -e "${CYAN}Insira a URL completa do MediaFire:${RESET}"
    echo -e "${YELLOW}Exemplo:${RESET} https://www.mediafire.com/file/XXXXX/arquivo.zip/file"
    echo ""
    echo -e "${YELLOW}💡 Deixe em branco para pular este passo${RESET}"
    echo ""
    echo -ne "${CYAN}🔗 URL:${RESET} "
    read -r MEDIAFIRE_URL
    echo ""
    
    if [ -z "$MEDIAFIRE_URL" ]; then
        print_warning "Download pulado pelo usuário"
        sleep 1
        return 0
    fi
    
    if ! echo "$MEDIAFIRE_URL" | grep -q "mediafire.com"; then
        print_error "URL inválida - deve ser do MediaFire"
        sleep 2
        return 1
    fi
    
    print_success "URL do MediaFire válida"
    
    local file_id=$(echo "$MEDIAFIRE_URL" | grep -oP '(?<=file/)[^/]+' | head -1)
    
    if [ -n "$file_id" ]; then
        local filename=$(echo "$MEDIAFIRE_URL" | grep -oP '(?<=/)[^/]+(?=/file)' | head -1)
        [ -z "$filename" ] && filename="gamemode.zip"
        
        print_info "Obtendo link direto..."
        local direct_link=$(curl -sL "$MEDIAFIRE_URL" | grep -oP 'https://download[0-9]+\.mediafire\.com/[^"]+' | head -1)
        
        if [ -n "$direct_link" ]; then
            echo ""
            print_info "Baixando ${BOLD}$filename${RESET}..."
            echo ""
            
            if wget --show-progress "$direct_link" -O "$filename" 2>&1; then
                echo ""
                local filesize=$(du -h "$filename" | cut -f1)
                print_success "Download concluído (${filesize})"
                echo ""
                
                # Usa a função melhorada de extração
                extract_zip_smart "$filename"
            else
                print_error "Falha no download"
            fi
        else
            print_error "Não foi possível obter link direto"
        fi
    fi
    
    sleep 1
}

# ════════════════════════════════════════════════════════════════
# INSTALAÇÃO - ETAPA 8: PLAYIT
# ════════════════════════════════════════════════════════════════

install_playit() {
    print_header
    print_step "🌐 [8/9] Instalação do Playit"
    
    PLAYIT_ALREADY_INSTALLED=false
    
    if command -v playit >/dev/null 2>&1; then
        local playit_version=$(playit --version 2>/dev/null || echo "instalado")
        print_success "Playit já instalado: ${BOLD}$playit_version${RESET}"
        PLAYIT_ALREADY_INSTALLED=true
        sleep 1
        return 0
    fi
    
    print_info "Adicionando chave GPG do repositório..."
    curl -fsSL https://playit-cloud.github.io/ppa/key.gpg | \
        sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/playit-cloud.gpg 2>/dev/null
    
    print_info "Adicionando repositório Playit..."
    sudo curl -fsSL -o /etc/apt/sources.list.d/playit-cloud.list \
        https://playit-cloud.github.io/ppa/playit-cloud.list 2>/dev/null
    
    print_info "Atualizando lista de pacotes..."
    sudo apt update >/dev/null 2>&1
    
    print_info "Instalando Playit..."
    if sudo apt install playit -y >/dev/null 2>&1; then
        local playit_version=$(playit --version 2>/dev/null || echo "Desconhecida")
        print_success "Playit instalado: ${BOLD}$playit_version${RESET}"
    else
        print_error "Erro na instalação do Playit"
        print_warning "O Pawn continuará funcionando normalmente"
    fi
    
    sleep 1
}

# ════════════════════════════════════════════════════════════════
# RELATÓRIO FINAL
# ════════════════════════════════════════════════════════════════

show_final_report() {
    print_header
    
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║  ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!             ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    echo -e "${BOLD}🧪 COMPONENTES INSTALADOS:${RESET}"
    echo ""
    
    # Wine
    if command -v wine >/dev/null 2>&1; then
        local wine_ver=$(wine --version 2>/dev/null)
        local wine_path=$(which wine)
        echo -e "  ${GREEN}✅${RESET} Wine: ${BOLD}$wine_ver${RESET}"
        echo -e "     Caminho: $wine_path"
    else
        echo -e "  ${RED}❌${RESET} Wine: Não detectado"
        echo -e "     ${YELLOW}Execute: source ~/.bashrc${RESET}"
    fi
    
    echo ""
    
    # Compilador Pawn
    if [ -f "pawno/pawncc.exe" ]; then
        echo -e "  ${GREEN}✅${RESET} Compilador: ${BOLD}pawno/pawncc.exe${RESET}"
    elif [ -f "pawncc/pawncc.exe" ]; then
        echo -e "  ${GREEN}✅${RESET} Compilador: ${BOLD}pawncc/pawncc.exe${RESET}"
    else
        echo -e "  ${YELLOW}⚠${RESET}  Compilador: Aguardando upload"
    fi
    
    echo ""
    
    # VS Code
    if [ -f ".vscode/settings.json" ] && [ -f ".vscode/tasks.json" ]; then
        echo -e "  ${GREEN}✅${RESET} VS Code: Configurado corretamente"
    else
        echo -e "  ${YELLOW}⚠${RESET}  VS Code: Configuração incompleta"
    fi
    
    echo ""
    
    # Playit
    if command -v playit >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${RESET} Playit: Instalado e disponível"
    else
        echo -e "  ${YELLOW}⚠${RESET}  Playit: Não instalado"
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  🚀 COMO USAR${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    
    echo -e "${CYAN}📝 COMPILAR PAWN:${RESET}"
    echo "  • Abra qualquer arquivo .pwn no VS Code"
    echo "  • Pressione: ${BOLD}Ctrl + Shift + B${RESET}"
    echo "  • Ou clique no botão ${BOLD}'Run Task'${RESET}"
    echo ""
    
    echo -e "${CYAN}🌐 USAR O PLAYIT:${RESET}"
    echo "  • Digite no terminal: ${BOLD}playit${RESET}"
    echo "  • Configure o túnel para a porta do servidor"
    echo "  • Ideal para SA-MP, FiveM, Minecraft, etc"
    echo ""
    
    echo -e "${CYAN}🔧 SOLUÇÃO DE PROBLEMAS:${RESET}"
    echo "  • Se Wine não funcionar: ${BOLD}source ~/.bashrc${RESET}"
    echo "  • Se extensões falharem: Recarregue a página (F5)"
    echo "  • Para reconfigurar: Execute este script novamente"
    echo ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    
    # Perguntar se quer executar Playit
    if command -v playit >/dev/null 2>&1; then
        echo ""
        echo -e "${MAGENTA}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${MAGENTA}║  🌐 Executar Playit Agora?                        ║${RESET}"
        echo -e "${MAGENTA}╚════════════════════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "${YELLOW}💡 O Playit permite expor seu servidor na internet${RESET}"
        echo -e "${YELLOW}   sem precisar abrir portas no roteador.${RESET}"
        echo ""
        echo -e "${CYAN}📌 Você pode executar a qualquer momento: ${BOLD}playit${RESET}"
        echo ""
        echo -ne "${CYAN}❓ Deseja executar agora? (S/n):${RESET} "
        read -r run_playit
        echo ""
        
        if [[ "$run_playit" =~ ^[Ss]$ ]] || [[ -z "$run_playit" ]]; then
            echo -e "${GREEN}🚀 Iniciando Playit...${RESET}"
            echo ""
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo ""
            playit
        else
            print_success "Playit não será executado agora"
            print_info "Para executar depois: ${BOLD}playit${RESET}"
            echo ""
        fi
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${GREEN}${BOLD}✅ Instalação completa! Boa sorte com seu projeto!${RESET}"
    echo ""
}

# ════════════════════════════════════════════════════════════════
# FUNÇÃO PRINCIPAL
# ════════════════════════════════════════════════════════════════

main() {
    # Trap para Ctrl+C
    trap 'echo ""; print_error "Instalação cancelada pelo usuário"; exit 130' INT
    
    # Executa todas as etapas
    check_initial_setup
    install_wine
    verify_wine_availability
    install_dependencies
    configure_vscode
    install_extensions
    download_mediafire
    install_playit
    show_final_report
}

# ════════════════════════════════════════════════════════════════
# EXECUÇÃO
# ════════════════════════════════════════════════════════════════

main "$@"
