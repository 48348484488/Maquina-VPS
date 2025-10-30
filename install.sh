#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║  🚀 INSTALADOR WINE PAWN v4.1 - ULTRA SIMPLIFICADO           ║
# ║  Automatizado • Inteligente • Rápido                         ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

# ═══════════════════════════════════════════════════════════════
# 🎨 CORES E ESTILO
# ═══════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════
# 🔧 FUNÇÕES AUXILIARES
# ═══════════════════════════════════════════════════════════════

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  🚀 INSTALADOR WINE PAWN v4.1                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

spinner() {
    local pid=$1
    local message=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    wait $pid
    return $?
}

read_password() {
    local prompt="$1"
    local password=""
    local char=""
    
    echo -n "${prompt}"
    
    stty -echo 2>/dev/null
    
    while IFS= read -r -s -n1 char; do
        if [[ $char == $'\0' ]] || [[ $char == $'\n' ]] || [[ $char == $'\r' ]]; then
            break
        fi
        
        if [[ $char == $'\177' ]] || [[ $char == $'\b' ]]; then
            if [ ${#password} -gt 0 ]; then
                password="${password%?}"
                echo -ne "\b \b"
            fi
        else
            password+="$char"
            echo -n "●"
        fi
    done
    
    stty echo 2>/dev/null
    echo ""
    
    echo "$password"
}

verify_zip_password() {
    local zipfile="$1"
    local password="$2"
    
    unzip -t -P "$password" "$zipfile" >/dev/null 2>&1
    return $?
}

# ═══════════════════════════════════════════════════════════════
# 🔐 SISTEMA DE EXTRAÇÃO INTELIGENTE
# ═══════════════════════════════════════════════════════════════

smart_extract() {
    local zipfile="$1"
    local max_attempts=3
    
    print_step "🔓 Sistema de Extração Inteligente"
    
    if [ ! -f "$zipfile" ]; then
        print_error "Arquivo não encontrado: $zipfile"
        return 1
    fi
    
    print_info "Analisando: $zipfile [$(du -h "$zipfile" | cut -f1)]"
    
    echo -ne "${BLUE}▶${NC} Testando arquivo sem senha... "
    if unzip -t "$zipfile" >/dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        echo -ne "${BLUE}▶${NC} Extraindo... "
        if unzip -q -o "$zipfile" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
            print_success "Extração concluída!"
            rm -f "$zipfile"
            return 0
        fi
    fi
    echo -e "${YELLOW}SENHA NECESSÁRIA${NC}"
    
    print_warning "Arquivo protegido por senha detectado"
    echo ""
    
    for attempt in $(seq 1 $max_attempts); do
        echo -e "${CYAN}╭─ Tentativa ${attempt}/${max_attempts}${NC}"
        
        local password=$(read_password "${CYAN}│${NC} 🔑 Digite a senha: ")
        
        if [ -z "$password" ]; then
            echo -e "${CYAN}╰─${NC}"
            print_warning "Senha vazia"
            
            if [ $attempt -lt $max_attempts ]; then
                read -p "   Tentar novamente? (S/n): " retry
                [[ "$retry" =~ ^[Nn]$ ]] && return 1
            fi
            continue
        fi
        
        echo -ne "${CYAN}│${NC} ${BLUE}▶${NC} Verificando senha... "
        
        if verify_zip_password "$zipfile" "$password"; then
            echo -e "${GREEN}CORRETA${NC}"
            echo -ne "${CYAN}│${NC} ${BLUE}▶${NC} Extraindo arquivos... "
            
            if unzip -q -o -P "$password" "$zipfile" 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
                echo -e "${CYAN}╰─${NC}"
                print_success "Extração concluída com sucesso!"
                rm -f "$zipfile"
                return 0
            else
                echo -e "${RED}ERRO${NC}"
                echo -e "${CYAN}╰─${NC}"
                print_error "Falha na extração"
                return 1
            fi
        else
            echo -e "${RED}INCORRETA${NC}"
            echo -e "${CYAN}╰─${NC}"
            print_error "Senha incorreta"
            
            if [ $attempt -lt $max_attempts ]; then
                print_info "Dica: Verifique Caps Lock e espaços extras"
                echo ""
            fi
        fi
    done
    
    print_error "Limite de tentativas atingido"
    print_info "Arquivo mantido: $zipfile"
    print_info "Extraia manualmente: unzip -P \"sua_senha\" $zipfile"
    return 1
}

# ═══════════════════════════════════════════════════════════════
# 📦 INSTALAÇÃO DE PACOTES
# ═══════════════════════════════════════════════════════════════

install_package() {
    local package=$1
    local name=$2
    
    if command -v $package >/dev/null 2>&1; then
        print_success "$name já instalado"
        return 0
    fi
    
    echo -ne "${BLUE}▶${NC} Instalando $name... "
    sudo apt install -y $package >/dev/null 2>&1 &
    spinner $! ""
    print_success "$name instalado"
}

# ═══════════════════════════════════════════════════════════════
# 🚀 INÍCIO DA INSTALAÇÃO
# ═══════════════════════════════════════════════════════════════

print_header

print_step "📋 Etapa 1/5 • Verificação do Sistema"

print_info "Verificando dependências..."
install_package "unzip" "UnZip"
install_package "zip" "Zip"
install_package "wget" "Wget"
install_package "curl" "Curl"

# ═══════════════════════════════════════════════════════════════
print_step "🍷 Etapa 2/5 • Instalação do Wine"

if command -v wine >/dev/null 2>&1; then
    print_success "Wine já instalado: $(wine --version 2>/dev/null)"
else
    print_info "Instalando Wine 32-bit (pode levar 2-5 minutos)..."
    
    sudo apt remove --purge wine wine32 wine64 -y >/dev/null 2>&1
    sudo apt autoremove -y >/dev/null 2>&1
    rm -rf ~/.wine 2>/dev/null
    
    echo -ne "${BLUE}▶${NC} Configurando repositórios... "
    sudo dpkg --add-architecture i386 >/dev/null 2>&1
    sudo apt update >/dev/null 2>&1
    sudo mkdir -pm755 /etc/apt/keyrings >/dev/null 2>&1
    sudo wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key 2>/dev/null
    sudo wget -q -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources 2>/dev/null
    echo -e "${GREEN}OK${NC}"
    
    echo -ne "${BLUE}▶${NC} Instalando Wine... "
    sudo apt update >/dev/null 2>&1
    sudo apt install --install-recommends winehq-stable -y >/dev/null 2>&1 &
    spinner $! ""
    
    mkdir -p ~/.wine-runtime
    chmod 700 ~/.wine-runtime
    
    export XDG_RUNTIME_DIR=~/.wine-runtime
    export WINEARCH=win32
    export WINEPREFIX=~/.wine
    export WINEDEBUG=-all
    export DISPLAY=:0
    
    wineboot -u >/dev/null 2>&1 &
    spinner $! "Inicializando Wine..."
    
    if ! grep -q "WINEARCH=win32" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOF'

# ═══════════════════════════════════════════════════════════════
# Wine 32-bit (Necessário para Pawn)
# ═══════════════════════════════════════════════════════════════
mkdir -p ~/.wine-runtime 2>/dev/null
export XDG_RUNTIME_DIR=~/.wine-runtime
export WINEARCH=win32
export WINEPREFIX=~/.wine
export WINEDEBUG=-all
export DISPLAY=:0
EOF
    fi
    
    source ~/.bashrc 2>/dev/null || true
    
    if command -v wine >/dev/null 2>&1; then
        print_success "Wine instalado: $(wine --version 2>/dev/null)"
    else
        print_error "Falha na instalação do Wine"
        print_info "Execute: source ~/.bashrc"
        exit 1
    fi
fi

# ═══════════════════════════════════════════════════════════════
print_step "⚙️  Etapa 3/5 • Configuração VS Code"

mkdir -p .vscode

cat > .vscode/settings.json << 'EOF'
{
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

echo -ne "${BLUE}▶${NC} Baixando tasks.json... "
wget -q https://github.com/48348484488/Maquina-VPS/raw/74c1d4876c3342d3df52d7db0142fef90f05f4bd/task.zip -O task.zip 2>&1

if [ -f "task.zip" ]; then
    echo -e "${GREEN}OK [$(du -h task.zip | cut -f1)]${NC}"
    
    unzip -q -o task.zip
    rm -f task.zip
    
    if [ -d "vscode" ]; then
        [ -f ".vscode/settings.json" ] && mv .vscode/settings.json .vscode/settings.json.backup
        mv vscode/* .vscode/ 2>/dev/null
        rm -rf vscode
        [ -f ".vscode/settings.json.backup" ] && mv .vscode/settings.json.backup .vscode/settings.json
    fi
    
    if [ -f ".vscode/tasks.json" ]; then
        print_success "tasks.json configurado"
    else
        print_error "tasks.json não encontrado"
        exit 1
    fi
else
    echo -e "${RED}FALHOU${NC}"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
print_step "🔌 Etapa 4/5 • Extensões do VS Code"

EXT_PAWN=$(code --list-extensions 2>/dev/null | grep -c "southclaws.vscode-pawn" || echo "0")
EXT_TASK=$(code --list-extensions 2>/dev/null | grep -c "sanaajani.taskrunnercode" || echo "0")

if [ "$EXT_PAWN" = "1" ]; then
    print_success "Pawn Language já instalada"
else
    echo -ne "${BLUE}▶${NC} Instalando Pawn Language... "
    code --install-extension southclaws.vscode-pawn >/dev/null 2>&1
    echo -e "${GREEN}OK${NC}"
fi

if [ "$EXT_TASK" = "1" ]; then
    print_success "Task Runner já instalada"
else
    echo -ne "${BLUE}▶${NC} Instalando Task Runner... "
    code --install-extension sanaajani.taskrunnercode >/dev/null 2>&1
    echo -e "${GREEN}OK${NC}"
fi

# ═══════════════════════════════════════════════════════════════
print_step "📥 Etapa 5/5 • Download MediaFire (Opcional)"

echo -e "${CYAN}╭─ MediaFire Download${NC}"
echo -e "${CYAN}│${NC}"
read -p "$(echo -e ${CYAN}│${NC}) 🔗 URL (ou ENTER para pular): " MEDIAFIRE_URL
echo -e "${CYAN}╰─${NC}"

if [ -n "$MEDIAFIRE_URL" ] && echo "$MEDIAFIRE_URL" | grep -q "mediafire.com"; then
    echo ""
    
    FILE_ID=$(echo "$MEDIAFIRE_URL" | grep -oP '(?<=file/)[^/]+' | head -1)
    FILENAME=$(echo "$MEDIAFIRE_URL" | grep -oP '(?<=/)[^/]+(?=/file)' | head -1)
    [ -z "$FILENAME" ] && FILENAME="gamemode.zip"
    
    print_info "Obtendo link direto..."
    DIRECT_LINK=$(curl -sL "$MEDIAFIRE_URL" | grep -oP 'https://download[0-9]+\.mediafire\.com/[^"]+' | head -1)
    
    if [ -n "$DIRECT_LINK" ]; then
        echo -ne "${BLUE}▶${NC} Baixando $FILENAME... "
        wget -q "$DIRECT_LINK" -O "$FILENAME" 2>&1
        echo -e "${GREEN}OK${NC}"
        
        if [ -f "$FILENAME" ]; then
            smart_extract "$FILENAME"
        fi
    else
        print_error "Link direto não encontrado"
    fi
elif [ -n "$MEDIAFIRE_URL" ]; then
    print_warning "URL inválida - deve ser do MediaFire"
else
    print_info "Download pulado"
fi

# ═══════════════════════════════════════════════════════════════
print_step "🌐 BONUS • Playit (Túnel de Rede)"

if command -v playit >/dev/null 2>&1; then
    print_success "Playit já instalado"
else
    echo -ne "${BLUE}▶${NC} Instalando Playit... "
    curl -fsSL https://playit-cloud.github.io/ppa/key.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/playit-cloud.gpg 2>/dev/null
    sudo curl -fsSL -o /etc/apt/sources.list.d/playit-cloud.list https://playit-cloud.github.io/ppa/playit-cloud.list 2>/dev/null
    sudo apt update >/dev/null 2>&1
    sudo apt install playit -y >/dev/null 2>&1 &
    spinner $! ""
    
    if command -v playit >/dev/null 2>&1; then
        print_success "Playit instalado"
    else
        print_warning "Playit não foi instalado (opcional)"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# 🎉 RELATÓRIO FINAL
# ═══════════════════════════════════════════════════════════════

clear
print_header

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${WHITE}  ✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO!                        ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}📊 COMPONENTES INSTALADOS:${NC}"
echo ""

if command -v wine >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Wine: ${CYAN}$(wine --version 2>/dev/null)${NC}"
else
    echo -e "  ${RED}✗${NC} Wine: ${YELLOW}Execute 'source ~/.bashrc'${NC}"
fi

if [ -f "pawno/pawncc.exe" ]; then
    echo -e "  ${GREEN}✓${NC} Compilador: ${CYAN}pawno/pawncc.exe${NC}"
elif [ -f "pawncc/pawncc.exe" ]; then
    echo -e "  ${GREEN}✓${NC} Compilador: ${CYAN}pawncc/pawncc.exe${NC}"
else
    echo -e "  ${YELLOW}⚠${NC} Compilador: ${YELLOW}Aguardando upload${NC}"
fi

if [ -f ".vscode/settings.json" ] && [ -f ".vscode/tasks.json" ]; then
    echo -e "  ${GREEN}✓${NC} VS Code: ${CYAN}Configurado${NC}"
else
    echo -e "  ${RED}✗${NC} VS Code: ${YELLOW}Configuração incompleta${NC}"
fi

if command -v playit >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Playit: ${CYAN}Instalado${NC}"
else
    echo -e "  ${YELLOW}⚠${NC} Playit: ${YELLOW}Não instalado${NC}"
fi

echo ""
echo -e "${BOLD}🚀 COMO USAR:${NC}"
echo ""
echo -e "${CYAN}┌─ Compilar Pawn${NC}"
echo -e "${CYAN}│${NC}  1. Abra um arquivo .pwn"
echo -e "${CYAN}│${NC}  2. Pressione: ${BOLD}Ctrl + Shift + B${NC}"
echo -e "${CYAN}└─${NC}"
echo ""
echo -e "${CYAN}┌─ Usar Playit${NC}"
echo -e "${CYAN}│${NC}  Digite: ${BOLD}playit${NC}"
echo -e "${CYAN}└─${NC}"
echo ""

if command -v playit >/dev/null 2>&1; then
    echo -e "${BOLD}Execute o Playit agora?${NC}"
    read -p "$(echo -e ${CYAN}▶${NC}) (S/n): " RUN_PLAYIT
    
    if [[ "$RUN_PLAYIT" =~ ^[Ss]$ ]] || [[ -z "$RUN_PLAYIT" ]]; then
        echo ""
        print_info "Iniciando Playit..."
        echo ""
        playit
    fi
fi

echo ""
echo -e "${GREEN}✓${NC} Tudo pronto! Boa sorte com seu projeto Pawn! 🎉"
echo ""
