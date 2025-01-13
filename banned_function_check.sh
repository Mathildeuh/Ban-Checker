#!/bin/bash

# Script : install_ban_checker.sh
# Crée et installe le script "banned_functions" sur la machine

INSTALL_PATH="/usr/local/bin/banned_functions"
REPO_URL="https://raw.githubusercontent.com/Mathildeuh/Ban-Checker/main/banned_functions_check.sh"
LOCAL_VERSION_FILE="/tmp/ban_checker_version"
LATEST_VERSION=$(curl -sI $REPO_URL | grep -i "last-modified" | sed 's/Last-Modified: //')

# Fonction pour vérifier les mises à jour
check_for_update() {
    # Si le fichier de version local n'existe pas, le créer
    if [ ! -f "$LOCAL_VERSION_FILE" ]; then
        echo "0" > "$LOCAL_VERSION_FILE"
    fi

    # Lire la version locale stockée dans le fichier
    LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE")

    # Comparer la version locale avec la version la plus récente
    if [ "$LOCAL_VERSION" != "$LATEST_VERSION" ]; then
        echo "Mise à jour disponible pour le script 'banned_functions'."
        echo "Téléchargement de la dernière version..."
        # Télécharger la dernière version du script avec sudo
        sudo curl -sSL $REPO_URL -o "$INSTALL_PATH"
        sudo chmod +x "$INSTALL_PATH"
        echo "$LATEST_VERSION" > "$LOCAL_VERSION_FILE"
        echo "Le script a été mis à jour avec succès."
    fi
}

# Vérification de mise à jour avant de commencer l'installation
check_for_update

# Créer le script "banned_functions"
sudo bash -c "cat > $INSTALL_PATH" << 'EOF'
#!/bin/bash

# Script : banned_functions_check.sh
# Fonction principale de vérification des fonctions interdites

INSTALL_PATH="/usr/local/bin/banned_functions"
REPO_URL="https://raw.githubusercontent.com/Mathildeuh/Ban-Checker/main/banned_functions_check.sh"
LOCAL_VERSION_FILE="/tmp/ban_checker_version"
LATEST_VERSION=$(curl -sI $REPO_URL | grep -i "last-modified" | sed 's/Last-Modified: //')

# Fonction pour vérifier les mises à jour
check_for_update() {
    # Si le fichier de version local n'existe pas, le créer
    if [ ! -f "$LOCAL_VERSION_FILE" ]; then
        echo "0" > "$LOCAL_VERSION_FILE"
    fi

    # Lire la version locale stockée dans le fichier
    LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE")

    # Comparer la version locale avec la version la plus récente
    if [ "$LOCAL_VERSION" != "$LATEST_VERSION" ]; then
        echo "Mise à jour disponible pour le script 'banned_functions'."
        echo "Téléchargement de la dernière version..."
        # Télécharger la dernière version du script avec sudo
        sudo curl -sSL $REPO_URL -o "$INSTALL_PATH"
        sudo chmod +x "$INSTALL_PATH"
        echo "$LATEST_VERSION" > "$LOCAL_VERSION_FILE"
        echo "Le script a été mis à jour avec succès."
    fi
}

# Vérifier la mise à jour à chaque lancement du script
check_for_update

# Le reste du code reste inchangé
# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Arrays pour stocker les fonctions
ALLOWED_FUNCTIONS=()
EXCLUDED_FUNCTIONS=()

# Liste des fonctions de la libc courantes
LIBC_FUNCTIONS=( 
    "printf" "fprintf" "sprintf" "snprintf" "scanf" "fscanf" "sscanf" 
    "malloc" "free" "calloc" "realloc" 
    "open" "close" "read" "write" "lseek" 
    "memset" "memcpy" "memmove" "memcmp" "memchr" 
    "strlen" "strcpy" "strncpy" "strcat" "strncat" 
    "strcmp" "strncmp" "strchr" "strrchr" "strstr" 
    "atoi" "atol" "atoll" "strtol" "strtoll" 
    "getline" "getchar" "putchar" "puts" 
    "fopen" "fclose" "fread" "fwrite" "fseek" 
    "exit" "system" "time" "rand" "srand" 
)

# Fonction d'aide
show_usage() {
    echo "Usage: $0 [--exclude func1,func2,...] allowed_function1 [allowed_function2 ...]"
    echo "Example: $0 --exclude printf,strlen write malloc free"
    exit 1
}

# Parsing des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --exclude)
            if [ -z "$2" ]; then
                echo "Error: --exclude requires a comma-separated list of functions"
                show_usage
            fi
            IFS=',' read -ra EXCLUDED_FUNCTIONS <<< "$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            ALLOWED_FUNCTIONS+=("$1")
            shift
            ;;
    esac
done

if [ ${#ALLOWED_FUNCTIONS[@]} -eq 0 ]; then
    echo "Error: No allowed functions specified"
    show_usage
fi

# Compteurs
total_violations=0
files_with_violations=0

check_file() {
    local file="$1"
    local file_violations=0
    local first_violation=1

    for func in "${LIBC_FUNCTIONS[@]}"; do
        if [[ ! " ${ALLOWED_FUNCTIONS[@]} " =~ " ${func} " ]] && \
           [[ ! " ${EXCLUDED_FUNCTIONS[@]} " =~ " ${func} " ]]; then
            local violations=$(grep -n "\<${func}\>(" "$file" 2>/dev/null || true)
            if [ ! -z "$violations" ]; then
                if [ $first_violation -eq 1 ]; then
                    echo -e "\n${YELLOW}File: ${file}${NC}"
                    first_violation=0
                    ((files_with_violations++))
                fi
                echo -e "${RED}Unauthorized function '${func}' found:${NC}"
                echo "$violations" | while read -r line; do
                    line_num=$(echo "$line" | cut -d: -f1)
                    line_content=$(echo "$line" | cut -d: -f2-)
                    echo -e "  Line ${line_num}: ${line_content}"
                    ((file_violations++))
                done
            fi
        fi
    done

    if [ $file_violations -gt 0 ]; then
        ((total_violations += file_violations))
        return 1
    fi
    return 0
}

echo -e "${YELLOW}Checking for unauthorized functions...${NC}"
echo -e "Allowed functions: ${GREEN}${ALLOWED_FUNCTIONS[*]}${NC}"
if [ ${#EXCLUDED_FUNCTIONS[@]} -gt 0 ]; then
    echo -e "Excluded functions: ${GREEN}${EXCLUDED_FUNCTIONS[*]}${NC}"
fi

find . -type f \( -name "*.c" -o -name "*.h" \) -not -path "*/\.*" | while read -r file; do
    check_file "$file"
done

echo -e "\n${YELLOW}=== Summary ===${NC}"
if [ $total_violations -eq 0 ]; then
    echo -e "${GREEN}No unauthorized functions found!${NC}"
    exit 0
else
    echo -e "${RED}Found $total_violations unauthorized function calls in $files_with_violations files${NC}"
    exit 1
fi
EOF

# Rendre le script exécutable
sudo chmod +x "$INSTALL_PATH"

echo "Le script 'banned_functions' a été installé avec succès dans $INSTALL_PATH"
echo "Vous pouvez l'exécuter avec la commande : banned_functions"
