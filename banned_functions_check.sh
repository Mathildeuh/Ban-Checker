#!/bin/bash

# Script : install_ban_checker.sh
# Crée et installe le script "banned_functions" sur la machine

INSTALL_PATH="/usr/local/bin/banned_functions"
BACKUP_PATH="/tmp/banned_functions.backup"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction pour afficher les messages d'erreur et quitter
error_exit() {
    echo -e "${RED}Erreur: $1${NC}" >&2
    exit 1
}

# Vérification des droits sudo
if [ "$(id -u)" != "0" ]; then
    error_exit "Ce script doit être exécuté avec les droits sudo.\nUtilisation: sudo $0"
fi

# Affichage d'un message d'accueil
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    Installation du${NC} ${YELLOW}Banned Function Checker${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "\n${GREEN}Début de l'installation...${NC}"

# Créer le script "banned_functions"
cat > "$INSTALL_PATH" << 'EOL'
#!/bin/bash
# Script : banned_functions.sh
# Vérifie si des fonctions non autorisées sont utilisées dans les fichiers source

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Variables globales pour le comptage
declare -i TOTAL_VIOLATIONS=0
declare -i FILES_WITH_VIOLATIONS=0
declare -i IGNORED_FILES=0

# Arrays pour stocker les fonctions autorisées et les fichiers exclus
ALLOWED_FUNCTIONS=()
EXCLUDED_FILES=()

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

# Vérifier si un fichier doit être exclu
should_exclude_file() {
    local file="$1"
    for excluded_file in "${EXCLUDED_FILES[@]}"; do
        if [[ "$file" == *"$excluded_file"* ]]; then
            ((IGNORED_FILES++))
            return 0
        fi
    done
    return 1
}

# Fonction pour vérifier un fichier
check_file() {
    local file="$1"
    local file_violations=0
    local first_violation=1

    for func in "${LIBC_FUNCTIONS[@]}"; do
        if [[ ! " ${ALLOWED_FUNCTIONS[@]} " =~ " ${func} " ]]; then
            # Vérification avec une regex qui capture mieux les appels de fonction
            local violations=$(grep -P -n "\\b${func}\\b" "$file" 2>/dev/null || true)
            if [ ! -z "$violations" ]; then
                if [ $first_violation -eq 1 ]; then
                    echo -e "\n${YELLOW}File: $file${NC}"
                    first_violation=0
                    ((FILES_WITH_VIOLATIONS++))
                fi
                
                echo -e "${RED}Unauthorized function '$func' found:${NC}"
                while IFS= read -r line; do
                    line_num=$(echo "$line" | cut -d: -f1)
                    line_content=$(echo "$line" | cut -d: -f2-)
                    echo -e "  Line $line_num: $line_content"
                    ((file_violations++))
                done <<< "$violations"
            fi
        fi
    done

    if [ $file_violations -gt 0 ]; then
        TOTAL_VIOLATIONS+=$file_violations
        return 1
    fi
    return 0
}

# Parcourir les fichiers et les analyser
while IFS= read -r -d '' file; do
    if ! should_exclude_file "$file"; then
        check_file "$file"
    fi
done < <(find . -type f \( -name "*.c" -o -name "*.h" \) -not -path "*/.*" -print0)

# Résumé final
echo -e "\n${YELLOW}=== Résumé ===${NC}"
if [ $TOTAL_VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}Aucune fonction non autorisée trouvée !${NC}"
    if [ $IGNORED_FILES -gt 0 ]; then
        echo -e "${BLUE}($IGNORED_FILES fichiers ignorés)${NC}"
    fi
    exit 0
else
    echo -e "${RED}Trouvé $TOTAL_VIOLATIONS appels de fonctions non autorisées dans $FILES_WITH_VIOLATIONS fichiers.${NC}"
    if [ $IGNORED_FILES -gt 0 ]; then
        echo -e "${BLUE}($IGNORED_FILES fichiers ignorés)${NC}"
    fi
    exit 1
fi
EOL

# Vérification de la création du fichier
if [ ! -f "$INSTALL_PATH" ]; then
    error_exit "Impossible de créer le fichier $INSTALL_PATH"
fi

# Rendre le script exécutable
chmod +x "$INSTALL_PATH" || error_exit "Impossible de rendre le script exécutable"

echo -e "\n${GREEN}✓ Installation réussie !${NC}"
echo -e "\n${BLUE}Détails de l'installation :${NC}"
echo -e "  ${YELLOW}►${NC} Emplacement : $INSTALL_PATH"
echo -e "  ${YELLOW}►${NC} Permissions : $(stat -c "%A" "$INSTALL_PATH")"
echo -e "  ${YELLOW}►${NC} Taille      : $(stat -c "%s" "$INSTALL_PATH") bytes"

echo -e "\n${BLUE}Utilisation :${NC}"
echo -e "  ${YELLOW}►${NC} Vérification simple : banned_functions write malloc free"
echo -e "  ${YELLOW}►${NC} Avec exclusions    : banned_functions --exclude test.c,main.c write malloc"
echo -e "  ${YELLOW}►${NC} Aide               : banned_functions --help"

if [ -f "$BACKUP_PATH" ]; then
    echo -e "\n${BLUE}Note : Une sauvegarde de l'ancienne version a été créée dans $BACKUP_PATH${NC}"
fi

echo -e "\n${GREEN}L'installation est terminée.${NC}"
