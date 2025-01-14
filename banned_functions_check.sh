#!/bin/bash

# Script : install_ban_checker.sh
# Crée et installe le script "banned_functions" sur la machine

INSTALL_PATH="/usr/local/bin/banned_functions"

# Créer le script "banned_functions"
sudo bash -c "cat > $INSTALL_PATH" << 'EOF'
#!/bin/bash

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Arrays pour stocker les fonctions autorisées et fichiers exclus
ALLOWED_FUNCTIONS=()
EXCLUDED_FILES=()

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
    echo "Usage: $0 [--exclude file1,file2,...] allowed_function1 [allowed_function2 ...]"
    echo "Example: $0 --exclude main.c,test.c write malloc free"
    exit 1
}

# Parsing des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --exclude)
            if [ -z "$2" ]; then
                echo "Error: --exclude requires a comma-separated list of files"
                show_usage
            fi
            IFS=',' read -ra EXCLUDED_FILES <<< "$2"
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

# Vérifier si un fichier doit être exclu
should_exclude_file() {
    local file="$1"
    for excluded_file in "${EXCLUDED_FILES[@]}"; do
        if [[ "$file" == *"$excluded_file"* ]]; then
            return 0
        fi
    done
    return 1
}

# Compteurs globaux
total_violations=0
files_with_violations=0

# Fonction pour vérifier un fichier
# Fonction pour vérifier un fichier
check_file() {
    local file="$1"
    local file_violations=0
    local first_violation=1

    for func in "${LIBC_FUNCTIONS[@]}"; do
        if [[ ! " ${ALLOWED_FUNCTIONS[@]} " =~ " ${func} " ]]; then
            # Vérification améliorée avec une regex qui capture mieux les appels de fonction
            local violations=$(grep -P -n "\\b${func}\\b" "$file" 2>/dev/null || true)
            if [ ! -z "$violations" ]; then
                if [ $first_violation -eq 1 ]; then
                    echo -e "\n${YELLOW}File: $file${NC}"
                    first_violation=0
                    ((files_with_violations++))
                fi
                echo -e "${RED}Unauthorized function '$func' found:${NC}"
                echo "$violations" | while IFS= read -r line; do
                    line_num=$(echo "$line" | cut -d: -f1)
                    line_content=$(echo "$line" | cut -d: -f2-)
                    echo -e "  Line $line_num: $line_content"
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

# Parcourir les fichiers et les analyser
find . -type f \( -name "*.c" -o -name "*.h" \) -not -path "*/.*" | while read -r file; do
    if ! should_exclude_file "$file"; then
        check_file "$file"
    fi
done

# Résumé final
echo -e "\n${YELLOW}=== Summary ===${NC}"
if [ $total_violations -eq 0 ]; then
    echo -e "${GREEN}No unauthorized functions found!${NC}"
    exit 0
else
    echo -e "${RED}Found $total_violations unauthorized function calls in $files_with_violations files.${NC}"
    exit 1
fi
EOF

# Rendre le script exécutable
sudo chmod +x "$INSTALL_PATH"

echo "Le script 'banned_functions' a été installé avec succès dans $INSTALL_PATH"
echo "Vous pouvez l'exécuter avec la commande : banned_functions"
