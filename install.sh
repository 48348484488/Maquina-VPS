cat > install-wine-pawn-playit.sh << 'SCRIPT_END'
#!/bin/bash

# Instalador Wine Pawn para VS Code v3.3
# Correções: Persistência total + Avisos ao usuário + Playit

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Instalador Wine Pawn + Playit v3.3"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
sleep 1

# [1/9] Verificando extensões
echo "🔍 [1/9] Verificando extensões do VS Code..."
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

# [2/9] Verificação de diretórios
echo "🔍 [2/9] Verificando estrutura de diretórios..."

if [ -d "pawno" ] || [ -d "pawncc" ]; then
    echo "✓ Compilador detectado - será preservado"
fi

if [ -d ".vscode" ]; then
    echo "⚠️  Configuração .vscode/ existente - será atualizada"
fi

echo "✓ Verificação concluída"
sleep 1
echo ""

# [3/9] Verificação e instalação do Wine
echo "🍷 [3/9] Verificando Wine..."
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
    
    sudo apt remove --purge wine wine32 wine64 -y >/dev/null 2>&1
    sudo apt autoremove -y >/dev/null 2>&1
    rm -rf ~/.wine
    
    sudo dpkg --add-architecture i386 >/dev/null 2>&1
    sudo apt update >/dev/null 2>&1
    sudo mkdir -pm755 /etc/apt/keyrings >/dev/null 2>&1
    sudo wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    sudo wget -q -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
    
    sudo apt update >/dev/null 2>&1
    sudo apt install --install-recommends winehq-stable -y >/dev/null 2>&1
    
    mkdir -p ~/.wine-runtime
    chmod 700 ~/.wine-runtime
    
    export XDG_RUNTIME_DIR=~/.wine-runtime
    export WINEARCH=win32
    export WINEPREFIX=~/.wine
    export WINEDEBUG=-all
    export DISPLAY=:0
    
    wineboot -u >/dev/null 2>&1
    
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

# [4/9] VERIFICAÇÃO CRÍTICA DO WINE
echo "🔍 [4/9] Verificando disponibilidade do Wine..."
source ~/.bashrc 2>/dev/null || true

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

# [5/9] Dependências
echo "📦 [5/9] Verificando dependências..."
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

# [6/9] Configuração do ambiente VS Code
echo "⚙️  [6/9] Configurando ambiente de desenvolvimento..."

mkdir -p .vscode

cat > .vscode/settings.json << 'SETTINGS_EOF'
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
SETTINGS_EOF

echo "✓ settings.json criado com variáveis Wine"

echo "⏳ Baixando tasks.json..."
wget -q https://github.com/48348484488/Maquina-VPS/raw/74c1d4876c3342d3df52d7db0142fef90f05f4bd/task.zip 2>&1

if [ -f "task.zip" ]; then
    TASK_SIZE=$(du -h task.zip | cut -f1)
    echo "✓ Download concluído [$TASK_SIZE]"
    echo ""
    echo "📂 Extraindo configurações..."
    unzip -q -o task.zip
    rm -f task.zip
    
    if [ -d "vscode" ]; then
        if [ -f ".vscode/settings.json" ]; then
            mv .vscode/settings.json .vscode/settings.json.backup
        fi
        
        mv vscode/* .vscode/ 2>/dev/null
        rm -rf vscode
        
        if [ -f ".vscode/settings.json.backup" ]; then
            mv .vscode/settings.json.backup .vscode/settings.json
        fi
    fi
    
    if [ -f ".vscode/tasks.json" ]; then
        echo "✓ tasks.json configurado"
        
        if ! grep -q "NÃO APAGUE" .vscode/tasks.json; then
            cp .vscode/tasks.json .vscode/tasks.json.tmp
            
            cat > .vscode/tasks.json << 'TASKS_HEADER'
{
    "// ⚠️  ATENÇÃO": "NÃO APAGUE ESTE ARQUIVO!",
    "// Necessário": "Para compilar Pawn com Ctrl+Shift+B",
TASKS_HEADER
            
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

# [7/9] Extensões
echo "🔌 [7/9] Instalando extensões do VS Code..."

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

# [8/9] Download MediaFire
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📥 [8/9] Download do Arquivo MediaFire"
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
clear

# [9/9] INSTALAÇÃO DO PLAYIT (SEMPRE INSTALA SE NÃO ESTIVER)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌐 [9/9] Instalando Playit (Túnel de Rede)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PLAYIT_ALREADY_INSTALLED=false

if command -v playit >/dev/null 2>&1; then
    EXISTING_PLAYIT_VER=$(playit --version 2>/dev/null || echo "instalado")
    if [ -n "$EXISTING_PLAYIT_VER" ]; then
        echo "✓ Playit já instalado: $EXISTING_PLAYIT_VER"
        PLAYIT_ALREADY_INSTALLED=true
    fi
fi

if [ "$PLAYIT_ALREADY_INSTALLED" = false ]; then
    echo "⏳ Adicionando chave GPG do repositório..."
    curl -fsSL https://playit-cloud.github.io/ppa/key.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/playit-cloud.gpg 2>/dev/null
    
    echo "⏳ Adicionando repositório Playit..."
    sudo curl -fsSL -o /etc/apt/sources.list.d/playit-cloud.list https://playit-cloud.github.io/ppa/playit-cloud.list 2>/dev/null
    
    echo "⏳ Atualizando lista de pacotes..."
    sudo apt update >/dev/null 2>&1
    
    echo "⏳ Instalando Playit..."
    sudo apt install playit -y >/dev/null 2>&1
    
    if command -v playit >/dev/null 2>&1; then
        PLAYIT_VERSION=$(playit --version 2>/dev/null || echo "Desconhecida")
        echo "✓ Playit instalado com sucesso [$PLAYIT_VERSION]"
    else
        echo "❌ Erro na instalação do Playit"
        echo "⚠️  O Pawn continuará funcionando normalmente"
    fi
fi

echo ""
sleep 1

# Relatório final
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🧪 COMPONENTES INSTALADOS:"
echo ""
if command -v wine >/dev/null 2>&1; then
    echo "  ✅ Wine: $(wine --version 2>/dev/null)"
    echo "  ✅ Caminho: $(which wine)"
else
    echo "  ❌ AVISO: Wine não detectado no PATH"
    echo "  🔧 Execute: source ~/.bashrc"
fi

echo ""
if [ -f "pawno/pawncc.exe" ]; then
    echo "  ✅ Compilador Pawn: pawno/pawncc.exe"
elif [ -f "pawncc/pawncc.exe" ]; then
    echo "  ✅ Compilador Pawn: pawncc/pawncc.exe"
else
    echo "  ⚠️  Compilador Pawn: Aguardando arquivo"
fi

echo ""
if [ -f ".vscode/settings.json" ] && [ -f ".vscode/tasks.json" ]; then
    echo "  ✅ Configuração VS Code: OK"
else
    echo "  ⚠️  Configuração VS Code: Incompleta"
fi

echo ""
if command -v playit >/dev/null 2>&1; then
    echo "  ✅ Playit: Instalado"
else
    echo "  ⚠️  Playit: Não instalado"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 COMO USAR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 COMPILAR PAWN:"
echo "  • Abra um arquivo .pwn no VS Code"
echo "  • Pressione: Ctrl + Shift + B"
echo "  • Ou use o botão 'Run Task'"
echo ""
echo "🌐 USAR O PLAYIT:"
echo "  • Execute a qualquer momento: playit"
echo "  • Configure o túnel para a porta do seu servidor"
echo "  • Útil para hospedar servidores SA-MP, FiveM, etc"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Perguntar se quer executar o Playit agora
if command -v playit >/dev/null 2>&1; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🌐 Executar Playit Agora?"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "💡 O Playit permite expor seu servidor na internet"
    echo "   sem precisar abrir portas no roteador."
    echo ""
    echo "📌 Você pode executar o Playit a qualquer momento"
    echo "   digitando apenas: playit"
    echo ""
    read -p "❓ Deseja executar o Playit agora? (S/n): " RUN_PLAYIT
    echo ""
    
    if [[ "$RUN_PLAYIT" =~ ^[Ss]$ ]] || [[ -z "$RUN_PLAYIT" ]]; then
        echo "🚀 Iniciando Playit..."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        playit
    else
        echo "✅ Playit não será executado agora."
        echo "💡 Para executar depois, digite: playit"
        echo ""
    fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Tudo pronto! Boa sorte com seu projeto Pawn!"
echo ""
SCRIPT_END

chmod +x install-wine-pawn-playit.sh && ./install-wine-pawn-playit.sh
