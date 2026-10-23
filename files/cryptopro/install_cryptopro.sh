#!/bin/bash
# =============================================================================
# Скрипт автоматической установки КриптоПро ЭЦП на ALT Linux
# =============================================================================

set -e

# --- Цвета для вывода ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
log_ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# --- Проверка прав root ---
if [[ $EUID -ne 0 ]]; then
    log_error "Скрипт необходимо запускать с правами root"
    exit 1
fi

# --- Определение архитектуры ---
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    BITS=64
    log_info "Архитектура: 64-бит (x86_64)"
else
    BITS=32
    log_info "Архитектура: 32-бит"
fi

# --- Рабочая папка ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_info "Рабочая папка: $SCRIPT_DIR"

# =============================================================================
# Функция установки пакетов
# =============================================================================
install_packages() {
    local pattern="$1"
    local description="$2"
    local files_found=()

    log_info "Устанавливаю: $description [$pattern]"

    # Безопасный поиск файлов без mapfile
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            files_found+=("$line")
        fi
    done < <(find "$SCRIPT_DIR" -maxdepth 2 -name "${pattern}.rpm" 2>/dev/null | sort)

    if [[ ${#files_found[@]} -gt 0 ]]; then
        log_info "Найдены локальные пакеты (${#files_found[@]} шт.), устанавливаю через rpm..."
        rpm -ivh --force --nodeps "${files_found[@]}" && log_ok "$description — установлено" || {
            log_error "Ошибка установки $description"
            return 1
        }
    else
        log_warn "Локальные пакеты не найдены, пробую apt-get..."
        apt-get update -q || true
        apt-get install -y "${pattern}" && log_ok "$description — установлено через apt-get" || {
            log_warn "Не удалось установить $description (пропуск)"
        }
    fi
}

# =============================================================================
# Интерактивный выбор
# =============================================================================
echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}   Установка КриптоПро ЭЦП на ALT Linux${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

ask_yes_no() {
    local question="$1"
    local default="$2"
    local answer

    while true; do
        printf "${YELLOW}?${NC} %s [y/n] (по умолчанию: %s): " "$question" "$default"
        read -r answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "   Введите y или n" ;;
        esac
    done
}

INSTALL_BASE=true
INSTALL_RUTOKEN=false
INSTALL_JACARTA=false
INSTALL_CRYPTOKI=false
INSTALL_CA_CERTS=false
INSTALL_CPTOOLS=false
INSTALL_CADES=false
SETUP_CHROMIUM=false
SETUP_FIREFOX=false

if ask_yes_no "Установить базовые пакеты КриптоПро CSP?" "y"; then INSTALL_BASE=true; fi
if ask_yes_no "Установить поддержку Рутокен S / Рутокен ЭЦП?" "n"; then INSTALL_RUTOKEN=true; fi
if ask_yes_no "Установить поддержку JaCarta?" "n"; then INSTALL_JACARTA=true; fi
if ask_yes_no "Установить поддержку носителей с неизвлекаемыми ключами (PKCS#11)?" "n"; then INSTALL_CRYPTOKI=true; fi
if ask_yes_no "Установить сертификаты Главного удостоверяющего центра?" "y"; then INSTALL_CA_CERTS=true; fi
if ask_yes_no "Установить графические инструменты КриптоПро (cptools)?" "n"; then INSTALL_CPTOOLS=true; fi
if ask_yes_no "Установить плагин CAdES?" "y"; then INSTALL_CADES=true; fi

if $INSTALL_CADES; then
    if ask_yes_no "Создать симлинк для Chromium?" "y"; then SETUP_CHROMIUM=true; fi
    if ask_yes_no "Создать симлинк для Firefox (64-бит)?" "y"; then SETUP_FIREFOX=true; fi
fi

echo ""
log_info "Начинаю установку..."
echo ""

# 1. Базовые пакеты
if $INSTALL_BASE; then
    log_info "--- Базовые пакеты ---"
    install_packages "cprocsp-curl*"            "cprocsp-curl"
    install_packages "lsb-cprocsp-base*"        "lsb-cprocsp-base"
    install_packages "lsb-cprocsp-capilite*"    "lsb-cprocsp-capilite"

    if [[ "$BITS" -eq 64 ]]; then
        install_packages "lsb-cprocsp-kc1-64*"  "lsb-cprocsp-kc1 (64-bit)"
        install_packages "lsb-cprocsp-rdr-64*"  "lsb-cprocsp-rdr (64-bit)"
    else
        install_packages "lsb-cprocsp-kc1-32*"  "lsb-cprocsp-kc1 (32-bit)"
        install_packages "lsb-cprocsp-rdr-4*"   "lsb-cprocsp-rdr (32-bit)"
    fi
    echo ""
fi

# 2. Рутокен
if $INSTALL_RUTOKEN; then
    log_info "--- Рутокен S / Рутокен ЭЦП ---"
    install_packages "cprocsp-rdr-gui-gtk*"    "cprocsp-rdr-gui-gtk"
    install_packages "cprocsp-rdr-rutoken*"    "cprocsp-rdr-rutoken"
    install_packages "cprocsp-rdr-pcsc*"       "cprocsp-rdr-pcsc"
    install_packages "lsb-cprocsp-pkcs11*"     "lsb-cprocsp-pkcs11"

    apt-get install -y pcsc-lite-rutokens pcsc-lite-ccid 2>/dev/null \
        && log_ok "pcsc-lite-rutokens, pcsc-lite-ccid установлены" \
        || log_warn "Не удалось установить дополнительные пакеты pcsc"
    echo ""
fi

# 3. JaCarta
if $INSTALL_JACARTA; then
    log_info "--- JaCarta ---"
    install_packages "cprocsp-rdr-jacarta*"    "cprocsp-rdr-jacarta"
    echo ""
fi

# 4. PKCS#11
if $INSTALL_CRYPTOKI; then
    log_info "--- Носители с неизвлекаемыми ключами (PKCS#11) ---"
    install_packages "cprocsp-rdr-cryptoki*"   "cprocsp-rdr-cryptoki"
    echo ""
fi

# 5. Сертификаты ГУЦ
if $INSTALL_CA_CERTS; then
    log_info "--- Сертификаты Главного удостоверяющего центра ---"
    install_packages "lsb-cprocsp-ca-certs*"   "lsb-cprocsp-ca-certs"
    echo ""
fi

# 6. Cptools
if $INSTALL_CPTOOLS; then
    log_info "--- Графические инструменты КриптоПро ---"
    install_packages "cprocsp-cptools*"        "cprocsp-cptools"
    echo ""
fi

# 7. CAdES
if $INSTALL_CADES; then
    log_info "--- CAdES плагин ---"
    install_packages "cprocsp-pki-cades*"      "cprocsp-pki-cades"
    install_packages "cprocsp-pki-plugin*"     "cprocsp-pki-plugin"
    echo ""
fi

# 8. Браузеры
if $SETUP_CHROMIUM; then
    log_info "--- Симлинк для Chromium ---"
    if [[ -d /usr/share/chromium-browser/extensions ]]; then
        ln -sf /usr/share/chromium-browser/extensions /usr/lib64/chromium/extensions \
            && log_ok "Симлинк для Chromium создан" \
            || log_warn "Не удалось создать симлинк для Chromium"
    else
        log_warn "Папка расширений Chromium не найдена."
    fi
fi

if $SETUP_FIREFOX; then
    log_info "--- Симлинк для Firefox (64-бит) ---"
    NPCADES_LIB="/opt/cprocsp/lib/amd64/libnpcades.so.2.0.0"
    FIREFOX_PLUGINS="/usr/lib64/browser-plugins"
    if [[ -f "$NPCADES_LIB" ]]; then
        mkdir -p "$FIREFOX_PLUGINS"
        ln -sf "$NPCADES_LIB" "$FIREFOX_PLUGINS/libnpcades.so" \
            && log_ok "Симлинк для Firefox создан" \
            || log_warn "Не удалось создать симлинк для Firefox"
    else
        log_warn "Библиотека $NPCADES_LIB не найдена."
    fi
fi

# 9. Служба
echo ""
log_info "--- Запуск и проверка службы КриптоПро ---"
if systemctl enable cprocsp 2>/dev/null && systemctl restart cprocsp 2>/dev/null; then
    log_ok "Служба cprocsp запущена через systemctl"
elif service cprocsp restart 2>/dev/null; then
    log_ok "Служба cprocsp запущена через service"
else
    log_warn "Не удалось перезапустить службу автоматически."
fi

# Вывод версии
if [[ -x /opt/cprocsp/bin/amd64/csptest ]]; then
    echo ""
    log_info "Версия КриптоПро:"
    /opt/cprocsp/bin/amd64/csptest -header 2>/dev/null | head -5 || true
fi

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}   Установка завершена!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""