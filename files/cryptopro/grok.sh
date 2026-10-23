#!/bin/bash
# =============================================================================
# КриптоПро ЭЦП — Установщик + Автоматическая выдача лицензий из PDF
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LICENSE_PDF="licenses35.pdf"
LICENSE_XLSX="Лицензия.xlsx"

# ====================== МЕНЮ ======================
show_main_menu() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}     Установка и управление КриптоПро CSP${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    echo "1) Полная установка + лицензия"
    echo "2) Только установка лицензии (из PDF)"
    echo "3) Выход"
    echo ""
    read -rp "Выберите действие [1-3]: " choice
    case $choice in
        1) full_install ;;
        2) only_license ;;
        3) exit 0 ;;
        *) log_error "Неверный выбор!"; show_main_menu ;;
    esac
}

# ====================== РАБОТА С ЛИЦЕНЗИЯМИ ======================
extract_serials_from_pdf() {
    if [[ ! -f "$LICENSE_PDF" ]]; then
        log_error "Файл $LICENSE_PDF не найден!"
        return 1
    fi

    log_info "Извлекаю серийные номера из PDF..."

    python3 - <<PYCODE 2>/dev/null
import re
from PyPDF2 import PdfReader

reader = PdfReader("$LICENSE_PDF")
serials = []
for page in reader.pages:
    text = page.extract_text()
    matches = re.findall(r'Серийный номер:\s*([A-Z0-9-]+)', text)
    serials.extend(matches)

serials = list(dict.fromkeys([s.strip() for s in serials if len(s) > 15]))
for i, s in enumerate(serials):
    print(f"{i+1}|{s}")
PYCODE
}

install_license() {
    local serial="$1"
    local owner="$2"

    log_info "Устанавливаю лицензию: $serial"
    if /opt/cprocsp/bin/amd64/cpconfig -license -set "$serial" >/dev/null 2>&1 || \
       echo "$serial" | /opt/cprocsp/bin/amd64/csptest -license -set >/dev/null 2>&1; then
        log_ok "Лицензия успешно установлена"
        update_excel "$owner" "$serial"
        return 0
    else
        log_error "Не удалось установить лицензию"
        return 1
    fi
}

update_excel() {
    local name="$1"
    local serial="$2"
    python3 - <<PYCODE 2>/dev/null
import pandas as pd
import os
file = "$LICENSE_XLSX"
if not os.path.exists(file):
    df = pd.DataFrame(columns=["Имя", "IP/ПК", "Серийный номер"])
else:
    df = pd.read_excel(file)
free = df[df.iloc[:,0].isna() | (df.iloc[:,0].astype(str).str.strip() == '')].index
if len(free) == 0:
    free = [len(df)]
    df.loc[len(df)] = [None, None, None]
idx = free[0]
df.iloc[idx, 0] = "$name"
df.iloc[idx, 2] = "$serial"
df.to_excel(file, index=False)
PYCODE
}

# ====================== УСТАНОВКА ПАКЕТОВ ======================
install_packages() {
    local pattern="$1"
    local desc="$2"
    log_info "Устанавливаю: $desc [$pattern]"

    mapfile -t FILES < <(find "$SCRIPT_DIR" -maxdepth 2 -name "${pattern}.rpm" 2>/dev/null | sort)
    if [[ ${#FILES[@]} -gt 0 ]]; then
        rpm -ivh --force --nodeps "${FILES[@]}" && log_ok "$desc — установлено" || log_warn "Ошибка установки $desc"
    else
        apt-get install -y "$pattern" && log_ok "$desc — установлено" || log_warn "Не удалось установить $desc"
    fi
}

ask_yes_no() {
    local q="$1"
    local def="${2:-y}"
    read -rp "$(echo -e "${YELLOW}?${NC} $q [y/n] (по умолчанию $def): ")" ans
    [[ -z "$ans" || "$ans" =~ ^[YyДд] ]]
}

# ====================== ПОЛНАЯ УСТАНОВКА ======================
full_install() {
    log_info "=== Полная установка КриптоПро ==="

    ask_yes_no "Установить базовые пакеты?" y && BASE=y
    ask_yes_no "Поддержка Рутокен?" y && RUTOKEN=y
    ask_yes_no "Поддержка JaCarta?" n && JACARTA=y
    ask_yes_no "PKCS#11?" y && CRYPTOKI=y
    ask_yes_no "Сертификаты ГУЦ?" y && CACERTS=y
    ask_yes_no "Графические инструменты?" y && CPTOOLS=y
    ask_yes_no "Плагин CAdES?" y && CADES=y

    [[ "$BASE" == y ]] && {
        install_packages "lsb-cprocsp-base*" "Base"
        install_packages "lsb-cprocsp-capilite*" "Capilite"
        install_packages "lsb-cprocsp-kc1-64*" "KC1"
        install_packages "lsb-cprocsp-rdr-64*" "RDR"
    }

    [[ "$RUTOKEN" == y ]] && {
        install_packages "cprocsp-rdr-rutoken*" "Rutoken"
        install_packages "cprocsp-rdr-pcsc*" "PCSC"
        install_packages "cprocsp-rdr-gui-gtk*" "GUI Rutoken"
        apt-get install -y pcsc-lite-rutokens pcsc-lite-ccid 2>/dev/null || true
    }

    [[ "$JACARTA" == y ]] && install_packages "cprocsp-rdr-jacarta*" "JaCarta"
    [[ "$CRYPTOKI" == y ]] && install_packages "cprocsp-rdr-cryptoki*" "Cryptoki"
    [[ "$CACERTS" == y ]] && install_packages "lsb-cprocsp-ca-certs*" "CA Certs"
    [[ "$CPTOOLS" == y ]] && install_packages "cprocsp-cptools*" "CPTools"
    [[ "$CADES" == y ]] && {
        install_packages "cprocsp-pki-cades*" "CAdES"
        install_packages "cprocsp-pki-plugin*" "Plugin"
    }

    systemctl enable --now cprocsp 2>/dev/null || service cprocsp restart 2>/dev/null || true
    log_ok "Установка пакетов завершена"
    only_license
}

# ====================== ТОЛЬКО ЛИЦЕНЗИЯ ======================
only_license() {
    echo ""
    log_info "=== Установка лицензии из PDF ==="

    SERIAL_LIST=$(extract_serials_from_pdf)
    if [[ -z "$SERIAL_LIST" ]]; then
        log_error "Не удалось извлечь лицензии из PDF"
        read -rp "Введите серийный номер вручную: " serial
        [[ -n "$serial" ]] && install_license "$serial" "$(hostname)"
        show_main_menu
        return
    fi

    echo -e "${YELLOW}Доступные серийные номера:${NC}"
    echo "$SERIAL_LIST" | cut -d'|' -f2
    echo ""

    read -rp "${YELLOW}Введите имя владельца / описание ПК: ${NC}" OWNER_NAME
    [[ -z "$OWNER_NAME" ]] && OWNER_NAME="$(hostname)"

    FIRST_SERIAL=$(echo "$SERIAL_LIST" | head -n1 | cut -d'|' -f2)

    if [[ -n "$FIRST_SERIAL" ]]; then
        install_license "$FIRST_SERIAL" "$OWNER_NAME"
    else
        log_error "Нет доступных лицензий"
    fi

    echo ""
    log_info "Текущие лицензии в системе:"
    /opt/cprocsp/bin/amd64/cpconfig -license -list 2>/dev/null || true

    show_main_menu
}

# ====================== ЗАПУСК ======================
if [[ $EUID -ne 0 ]]; then
    log_error "Скрипт нужно запускать от root: sudo bash $0"
    exit 1
fi

# Устанавливаем зависимости для чтения PDF
apt-get update -qq && apt-get install -y python3-pypdf2 python3-pandas 2>/dev/null || true

show_main_menu