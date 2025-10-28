#!/bin/bash

# Instalador Wine Pawn para VS Code v3.2
# Correções: Persistência total + Avisos ao usuário

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Instalador Wine Pawn para VS Code v3.2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
sleep 1

# [1/8] Verificando extensões
echo "🔍 [1/8] Verificando extensões do VS Code..."
EXT_PAWN_INSTALLED=false
EXT_TASK_INSTALLED=false

if code --list-extensions 2>/dev/null | grep -q "southclaws.vscode-pawn"; then
    EXT_PAWN_INSTALLED=true
    echo "✓ southclaws.vscode-pawn já instalada"
fi

if code --list-extensions 2>/dev/null | grep -q "sanaajani.taskrunnercode"; then
    EXT_TASK_INSTALLED=true
    echo "✓ sanaajani.taskrunnercode já instalada"
fi

if [ "$EXT_PAWN_INSTALLED" = false ] && [ "$EXT_TASK_INSTALLED" = false ]; then
    echo "⚠️  Nenhuma extensão detectada"
fi

sleep 1
echo ""

# [2/8] Verificação de diretórios
echo "🔍 [2/8] Verificando estrutura de diretórios..."

if [ -d "pawno" ] || [ -d "pawncc" ]; then
    echo "✓ Compilador detectado - será preservado"
fi

if [ -d ".vscode" ]; then
    echo "⚠️  Configuração .vscode/ existente - será atualizada"
fi

echo "✓ Verificação concluída"
sleep 1
echo ""

# [3/8] Verificação e instalação do Wine
echo "🍷 [3/8] Verificando Wine..."
WINE_ALREADY_INSTALLED=false

if command -v wine >/dev/null 2>&1; then
    EXISTING_WINE_VER=$(wine --version 2>/dev/null)
    if [ -n "$EXISTING_WINE_VER" ]; then
        echo "✓ Wine já instalado: $EXISTING_WINE_VER"
        WINE_ALREADY_INSTALLED=true
    fi
fi

if [ "$WINE_ALREADY_INSTALLED" = false ]; then
    echo "⏳ Instalando Wine 32-bit (2-5 minutos)..."
    echo "⏳ Aguarde... Este processo pode demorar."
    echo ""
    
    # Limpeza prévia
    sudo apt remove --purge wine wine32 wine64 -y >/dev/null 2>&1
    sudo apt autoremove -y >/dev/null 2>&1
    rm -rf ~/.wine
    
    # Configuração de repositório
    sudo dpkg --add-architecture i386 >/dev/null 2>&1
    sudo apt update >/dev/null 2>&1
    sudo mkdir -pm755 /etc/apt/keyrings >/dev/null 2>&1
    sudo wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    sudo wget -q -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
    
    # Instalação
    sudo apt update >/dev/null 2>&1
    sudo apt install --install-recommends winehq-stable -y >/dev/null 2>&1
    
    # Configuração inicial do Wine
    mkdir -p ~/.wine-runtime
    chmod 700 ~/.wine-runtime
    
    export XDG_RUNTIME_DIR=~/.wine-runtime
    export WINEARCH=win32
    export WINEPREFIX=~/.wine
    export WINEDEBUG=-all
    export DISPLAY=:0
    
    wineboot -u >/dev/null 2>&1
    
    # Adicionar ao .bashrc
    if ! grep -q "WINEARCH=win32" ~/.bashrc; then
        echo -e "\n# ═══════════════════════════════════════════════════" >> ~/.bashrc
        echo "# Configuração Wine 32-bit (Auto-start)" >> ~/.bashrc
        echo "# NÃO REMOVER - Necessário para compilar Pawn" >> ~/.bashrc
        echo "# ═══════════════════════════════════════════════════" >> ~/.bashrc
        echo "mkdir -p ~/.wine-runtime 2>/dev/null" >> ~/.bashrc
        echo "export XDG_RUNTIME_DIR=~/.wine-runtime" >> ~/.bashrc
        echo "export WINEARCH=win32" >> ~/.bashrc
        echo "export WINEPREFIX=~/.wine" >> ~/.bashrc
        echo "export WINEDEBUG=-all" >> ~/.bashrc
        echo "export DISPLAY=:0" >> ~/.bashrc
    fi
    
    # Adicionar ao .bash_profile (executado ao fazer login)
    if ! grep -q "WINEARCH=win32" ~/.bash_profile 2>/dev/null; then
        echo -e "\n# ═══════════════════════════════════════════════════" >> ~/.bash_profile
        echo "# Configuração Wine 32-bit (Auto-start)" >> ~/.bash_profile
        echo "# NÃO REMOVER - Necessário para compilar Pawn" >> ~/.bash_profile
        echo "# ═══════════════════════════════════════════════════" >> ~/.bash_profile
        echo "mkdir -p ~/.wine-runtime 2>/dev/null" >> ~/.bash_profile
        echo "export XDG_RUNTIME_DIR=~/.wine-runtime" >> ~/.bash_profile
        echo "export WINEARCH=win32" >> ~/.bash_profile
        echo "export WINEPREFIX=~/.wine" >> ~/.bash_profile
        echo "export WINEDEBUG=-all" >> ~/.bash_profile
        echo "export DISPLAY=:0" >> ~/.bash_profile
    fi
    
    echo "✓ Variáveis configuradas em ~/.bashrc e ~/.bash_profile"
    
    # Recarregar variáveis
    source ~/.bashrc 2>/dev/null || true
    
    if command -v wine >/dev/null 2>&1; then
        WINE_VERSION=$(wine --version 2>/dev/null)
        echo "✓ Wine instalado com sucesso [$WINE_VERSION]"
    else
        echo "❌ Falha ao instalar Wine"
        exit 1
    fi
fi

sleep 1
echo ""

# [4/8] VERIFICAÇÃO CRÍTICA DO WINE
echo "🔍 [4/8] Verificando disponibilidade do Wine..."
source ~/.bashrc 2>/dev/null || true

# Forçar exportação das variáveis
export WINEARCH=win32
export WINEPREFIX=~/.wine
export WINEDEBUG=-all
export XDG_RUNTIME_DIR=~/.wine-runtime

if ! command -v wine >/dev/null 2>&1; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⚠️  ATENÇÃO: REINÍCIO NECESSÁRIO"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "O Wine foi instalado mas não está disponível neste terminal."
    echo ""
    echo "🔄 SOLUÇÕES:"
    echo ""
    echo "  1. Execute: source ~/.bashrc"
    echo "  2. OU feche e reabra o terminal"
    echo "  3. OU execute: exec bash"
    echo ""
    read -p "Pressione ENTER para tentar recarregar automaticamente..."
    exec bash "$0"
    exit 0
fi

echo "✓ Wine disponível no PATH"
sleep 1
echo ""

# [5/8] Dependências
echo "📦 [5/8] Verificando dependências..."
DEPS_ALREADY_INSTALLED=true
MISSING_DEPS=""

command -v unzip >/dev/null 2>&1 || { DEPS_ALREADY_INSTALLED=false; MISSING_DEPS="$MISSING_DEPS unzip"; }
command -v zip >/dev/null 2>&1 || { DEPS_ALREADY_INSTALLED=false; MISSING_DEPS="$MISSING_DEPS zip"; }
command -v wget >/dev/null 2>&1 || { DEPS_ALREADY_INSTALLED=false; MISSING_DEPS="$MISSING_DEPS wget"; }
command -v curl >/dev/null 2>&1 || { DEPS_ALREADY_INSTALLED=false; MISSING_DEPS="$MISSING_DEPS curl"; }

if [ "$DEPS_ALREADY_INSTALLED" = true ]; then
    echo "✓ Todas as dependências já instaladas"
else
    echo "⚠️  Instalando dependências:$MISSING_DEPS"
    sudo apt install -y unzip zip wget curl >/dev/null 2>&1
    echo "✓ Dependências instaladas com sucesso"
fi

sleep 1
echo ""
clear

# [6/8] Configuração do ambiente VS Code
echo "⚙️  [6/8] Configurando ambiente de desenvolvimento..."

# Criar diretório .vscode se não existir
mkdir -p .vscode

# Criar settings.json com variáveis de ambiente
cat > .vscode/settings.json << 'EOF'
{
    "// ⚠️  ATENÇÃO": "NÃO APAGUE ESTE ARQUIVO!",
    "// Necessário": "Para compilar Pawn com Wine no Codespaces",
    "// Documentação": "https://github.com/seu-repo (adicionar link se tiver)",
    
    "terminal.integrated.env.linux": {
        "WINEARCH": "win32",
        "WINEPREFIX": "${env:HOME}/.wine",
        "WINEDEBUG": "-all",
        "XDG_RUNTIME_DIR": "${env:HOME}/.wine-runtime",
        "DISPLAY": ":0"
    }
}
EOF

echo "✓ settings.json criado com variáveis Wine"

# Baixar tasks.json
echo "⏳ Baixando tasks.json..."
wget -q https://github.com/48348484488/Maquina-VPS/raw/74c1d4876c3342d3df52d7db0142fef90f05f4bd/task.zip 2>&1

if [ -f "task.zip" ]; then
    TASK_SIZE=$(du -h task.zip | cut -f1)
    echo "✓ Download concluído [$TASK_SIZE]"
    echo ""
    echo "📂 Extraindo configurações..."
    unzip -q -o task.zip
    rm -f task.zip
    
    # Mover vscode para .vscode se necessário
    if [ -d "vscode" ]; then
        # Preservar settings.json que acabamos de criar
        if [ -f ".vscode/settings.json" ]; then
            mv .vscode/settings.json .vscode/settings.json.backup
        fi
        
        # Mover conteúdo
        mv vscode/* .vscode/ 2>/dev/null
        rm -rf vscode
        
        # Restaurar settings.json
        if [ -f ".vscode/settings.json.backup" ]; then
            mv .vscode/settings.json.backup .vscode/settings.json
        fi
    fi
    
    if [ -f ".vscode/tasks.json" ]; then
        echo "✓ tasks.json configurado"
        
        # Adicionar comentário de aviso no tasks.json
        if ! grep -q "NÃO APAGUE" .vscode/tasks.json; then
            # Backup do tasks.json original
            cp .vscode/tasks.json .vscode/tasks.json.tmp
            
            # Adicionar aviso no início
            cat > .vscode/tasks.json << 'TASKS_HEADER'
{
    "// ⚠️  ATENÇÃO": "NÃO APAGUE ESTE ARQUIVO!",
    "// Necessário": "Para compilar Pawn com Ctrl+Shift+B",
TASKS_HEADER
            
            # Adicionar resto do arquivo (pulando a primeira linha com {)
            tail -n +2 .vscode/tasks.json.tmp >> .vscode/tasks.json
            rm .vscode/tasks.json.tmp
        fi
    else
        echo "❌ Erro: tasks.json não encontrado no ZIP"
        exit 1
    fi
else
    echo "❌ Falha no download do task.zip"
    exit 1
fi

sleep 1
echo ""

# [7/8] Extensões
echo "🔌 [7/8] Instalando extensões do VS Code..."

if [ "$EXT_PAWN_INSTALLED" = true ] && [ "$EXT_TASK_INSTALLED" = true ]; then
    echo "✓ Extensões já instaladas - pulando"
else
    if [ "$EXT_PAWN_INSTALLED" = false ]; then
        echo "⏳ Instalando southclaws.vscode-pawn..."
        code --install-extension southclaws.vscode-pawn >/dev/null 2>&1
    fi
    
    if [ "$EXT_TASK_INSTALLED" = false ]; then
        echo "⏳ Instalando sanaajani.taskrunnercode..."
        code --install-extension sanaajani.taskrunnercode >/dev/null 2>&1
    fi
    
    sleep 2
    
    EXT_PAWN=$(code --list-extensions 2>/dev/null | grep -c "southclaws.vscode-pawn")
    EXT_TASK=$(code --list-extensions 2>/dev/null | grep -c "sanaajani.taskrunnercode")
    TOTAL_EXT=$((EXT_PAWN + EXT_TASK))
    
    if [ "$TOTAL_EXT" -eq 2 ]; then
        echo "✓ Extensões confirmadas [2/2]"
    elif [ "$TOTAL_EXT" -eq 1 ]; then
        echo "⚠️  Extensões parcialmente instaladas [1/2]"
        echo "⚠️  Solução: Recarregue a página (F5)"
    else
        echo "❌ Erro ao instalar extensões"
        echo "❌ Solução: Recarregue a página (F5)"
    fi
fi

sleep 1
echo ""
clear

# [8/8] Download MediaFire
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📥 [8/8] Download do Arquivo MediaFire"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Insira a URL completa do MediaFire:"
echo "(Ex: https://www.mediafire.com/file/XXXXXXXXX/arquivo.zip/file)"
echo ""
echo "💡 Dica: Deixe em branco para pular"
echo ""
read -p "🔗 URL: " MEDIAFIRE_URL
echo ""

if [ -z "$MEDIAFIRE_URL" ]; then
    echo "⚠️  URL não fornecida - pulando download"
elif echo "$MEDIAFIRE_URL" | grep -q "mediafire.com"; then
    echo "✓ URL do MediaFire detectada"
    
    FILE_ID=$(echo "$MEDIAFIRE_URL" | grep -oP '(?<=file/)[^/]+' | head -1)
    
    if [ -n "$FILE_ID" ]; then
        FILENAME=$(echo "$MEDIAFIRE_URL" | grep -oP '(?<=/)[^/]+(?=/file)' | head -1)
        [ -z "$FILENAME" ] && FILENAME="gamemode.zip"
        
        echo "☁️  Obtendo link direto..."
        DIRECT_LINK=$(curl -sL "$MEDIAFIRE_URL" | grep -oP 'https://download[0-9]+\.mediafire\.com/[^"]+' | head -1)
        
        if [ -n "$DIRECT_LINK" ]; then
            echo "⬇️  Baixando $FILENAME..."
            wget -q --show-progress "$DIRECT_LINK" -O "$FILENAME" 2>&1
            
            if [ -f "$FILENAME" ]; then
                echo ""
                echo "✓ Download concluído [$(du -h "$FILENAME" | cut -f1)]"
                echo ""
                echo "📂 Extraindo arquivos..."
                
                if unzip -q -o "$FILENAME" 2>/dev/null; then
                    rm -f "$FILENAME"
                    echo "✅ Extração concluída!"
                else
                    echo "❌ Erro na extração - arquivo mantido: $FILENAME"
                fi
            else
                echo "❌ Falha no download"
            fi
        else
            echo "❌ Não foi possível obter link direto"
        fi
    fi
else
    echo "❌ URL inválida - deve ser do MediaFire"
fi

echo ""
sleep 1

# Relatório final
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ INSTALAÇÃO CONCLUÍDA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Teste final do Wine
echo "🧪 TESTE FINAL:"
echo ""
if command -v wine >/dev/null 2>&1; then
    echo "  ✅ Wine: $(wine --version 2>/dev/null)"
    echo "  ✅ Caminho: $(which wine)"
else
    echo "  ❌ AVISO: Wine não detectado no PATH"
    echo "  🔧 Execute: source ~/.bashrc"
fi

# Verificar compilador
echo ""
if [ -f "pawno/pawncc.exe" ]; then
    echo "  ✅ Compilador: pawno/pawncc.exe"
elif [ -f "pawncc/pawncc.exe" ]; then
    echo "  ✅ Compilador: pawncc/pawncc.exe"
else
    echo "  ⚠️  Compilador: Aguardando arquivo do MediaFire"
fi

# Verificar configurações
echo ""
if [ -f ".vscode/settings.json" ] && [ -f ".vscode/tasks.json" ]; then
    echo "  ✅ Configuração VS Code: OK"
else
    echo "  ⚠️  Configuração VS Code: Incompleta"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━
