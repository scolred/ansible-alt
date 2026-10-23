#!/bin/sh
# =============================================================================
# КриптоПро CSP — Менеджер установки и лицензий
# ALT Linux / Debian / RPM совместимый (POSIX sh)
# Кладётся рядом с папкой с пакетами КриптоПро
# Запуск: sudo sh cryptopro_manager.sh
#
# Проверено на основе: https://www.altlinux.org/КриптоПро
# Устанавливает: cryptopro-preinstall, базовые пакеты, cptools, CAdES
# =============================================================================

# --- Цвета (только если терминал поддерживает) ---
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# КРИТИЧНО: переходим в директорию скрипта — здесь лежат все RPM-файлы
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

PYTHON_HELPER="$SCRIPT_DIR/cryptopro_helper.py"
CSP_BIN_64="/opt/cprocsp/bin/amd64/csptest"
CSP_BIN_32="/opt/cprocsp/bin/ia32/csptest"
CERTMGR_64="/opt/cprocsp/bin/amd64/certmgr"
CERTMGR_32="/opt/cprocsp/bin/ia32/certmgr"
CPCONFIG_64="/opt/cprocsp/sbin/amd64/cpconfig"
CPCONFIG_32="/opt/cprocsp/sbin/ia32/cpconfig"

log_info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
log_ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
log_err()   { printf "${RED}[ОШИБКА]${NC} %s\n" "$1"; }
log_head()  { printf "\n${BOLD}${CYAN}>>> %s${NC}\n" "$1"; }

press_enter() {
    printf "\nНажмите Enter для продолжения..."
    read DUMMY
}

# =============================================================================
# ОПРЕДЕЛЕНИЕ АРХИТЕКТУРЫ
# =============================================================================
detect_arch() {
    MACHINE_ARCH=$(uname -m)
    case "$MACHINE_ARCH" in
        x86_64|amd64)
            BITS=64
            BITS_POSTFIX="-64"
            ARCH_DIR="amd64"
            CSP_BIN="$CSP_BIN_64"
            CERTMGR="$CERTMGR_64"
            CPCONFIG="$CPCONFIG_64"
            ;;
        i386|i486|i586|i686)
            BITS=32
            BITS_POSTFIX=""
            ARCH_DIR="ia32"
            CSP_BIN="$CSP_BIN_32"
            CERTMGR="$CERTMGR_32"
            CPCONFIG="$CPCONFIG_32"
            ;;
        *)
            BITS=64
            BITS_POSTFIX="-64"
            ARCH_DIR="amd64"
            CSP_BIN="$CSP_BIN_64"
            CERTMGR="$CERTMGR_64"
            CPCONFIG="$CPCONFIG_64"
            ;;
    esac
}

# =============================================================================
# ПРОВЕРКА PYTHON
# =============================================================================
check_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        log_warn "python3 не найден — установка..."
        apt-get install -y python3 2>/dev/null || true
    fi
    if ! python3 -c "import pdfplumber" 2>/dev/null; then
        log_warn "pdfplumber не найден — установка..."
        pip3 install pdfplumber --break-system-packages -q 2>/dev/null || \
        pip install pdfplumber --break-system-packages -q 2>/dev/null || true
    fi
    if ! python3 -c "import openpyxl" 2>/dev/null; then
        log_warn "openpyxl не найден — установка..."
        pip3 install openpyxl --break-system-packages -q 2>/dev/null || \
        pip install openpyxl --break-system-packages -q 2>/dev/null || true
    fi
}

# =============================================================================
# ОПРЕДЕЛЕНИЕ ТИПА СИСТЕМЫ
# =============================================================================
detect_system_type() {
    IS_DEBIAN=0
    IS_ALTLINUX=0

    if [ -f /etc/altlinux-release ]; then
        IS_ALTLINUX=1
        IS_DEBIAN=0
        log_info "Система: ALT Linux"
    elif [ -f /etc/debian_version ] || [ -f /etc/mcst_version ]; then
        IS_DEBIAN=1
        log_info "Система: Debian/Ubuntu"
    elif grep -q Ubuntu /etc/lsb-release 2>/dev/null; then
        IS_DEBIAN=1
        log_info "Система: Ubuntu"
    else
        # По умолчанию считаем RPM-систему
        log_info "Система: RPM-based (RHEL/SUSE/другое)"
    fi

    # Команда apt-get есть на ALT Linux и Debian-based
    if command -v apt-get >/dev/null 2>&1; then
        HAS_APT=1
    else
        HAS_APT=0
    fi

    # Команда rpm
    if command -v rpm >/dev/null 2>&1; then
        HAS_RPM=1
    else
        HAS_RPM=0
    fi

    log_info "apt-get: $([ $HAS_APT -eq 1 ] && echo 'есть' || echo 'нет') | rpm: $([ $HAS_RPM -eq 1 ] && echo 'есть' || echo 'нет')"
}

# =============================================================================
# УСТАНОВКА ОДНОГО RPM-ПАКЕТА
# Алгоритм:
#   1. Ищем файл в текущей директории
#   2. Устанавливаем через apt-get install ./файл.rpm (ALT/Debian)
#      или через rpm -Uvh --force --nodeps (pure RPM)
# =============================================================================
install_one_pkg() {
    PKG_NAME="$1"   # имя пакета без версии, например: lsb-cprocsp-base
    DESC="$2"

    FILE=""

    # Паттерны для поиска: сначала с суффиксом архитектуры, потом без
    for pattern in \
        "./${PKG_NAME}${BITS_POSTFIX}-"*".rpm" \
        "./${PKG_NAME}-"*".rpm" \
        "./${PKG_NAME}_"*".rpm" \
        "./${PKG_NAME}"*".rpm" \
        "./${PKG_NAME}${BITS_POSTFIX}-"*".deb" \
        "./${PKG_NAME}-"*".deb" \
        "./${PKG_NAME}"*".deb"
    do
        # shellcheck disable=SC2086
        FOUND=$(ls $pattern 2>/dev/null | head -1)
        if [ -n "$FOUND" ]; then
            FILE="$FOUND"
            break
        fi
    done

    if [ -z "$FILE" ]; then
        log_warn "$DESC — файл пакета не найден (${PKG_NAME}*)"
        return 1
    fi

    log_info "Устанавливаю: $DESC ($FILE)"

    # На ALT Linux и Debian: apt-get install умеет ставить локальные .rpm/.deb
    if [ $HAS_APT -eq 1 ]; then
        apt-get install -y "$FILE" 2>&1
        INST_RET=$?
        if [ $INST_RET -eq 0 ]; then
            log_ok "$DESC — готово (apt-get)"
            return 0
        else
            log_warn "$DESC — apt-get вернул ошибку ($INST_RET), пробую rpm..."
        fi
    fi

    # Fallback: прямой rpm
    if [ $HAS_RPM -eq 1 ]; then
        rpm -Uvh --force --nodeps "$FILE" 2>&1
        INST_RET=$?
        if [ $INST_RET -eq 0 ]; then
            log_ok "$DESC — готово (rpm)"
            return 0
        else
            log_warn "$DESC — rpm вернул ошибку ($INST_RET)"
            return 1
        fi
    fi

    log_err "$DESC — нет ни apt-get ни rpm для установки"
    return 1
}

# =============================================================================
# СКАЧИВАНИЕ ФАЙЛА
# =============================================================================
get_downloader() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        DOWNLOADER=""
    fi
}

download_file() {
    URL="$1"
    OUTFILE="$2"
    get_downloader
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -fsSL -o "$OUTFILE" "$URL"
        return $?
    elif [ "$DOWNLOADER" = "wget" ]; then
        wget -q -O "$OUTFILE" "$URL"
        return $?
    else
        log_err "Нет curl или wget"
        return 1
    fi
}

# Проверяет наличие локального файла пакета
pkg_exists_locally() {
    PKG_NAME="$1"
    ls ./"${PKG_NAME}"*.rpm 2>/dev/null | grep -q . || \
    ls ./"${PKG_NAME}"*.deb 2>/dev/null | grep -q .
    return $?
}

# =============================================================================
# ШАГ 0: УСТАНОВКА cryptopro-preinstall (ALT Linux)
# Этот пакет устанавливает все зависимости КриптоПро:
# libpangox-compat, opensc, pcsc-lite, pcsc-lite-rutokens, pcsc-lite-ccid, newt52
# =============================================================================
install_preinstall() {
    if [ $HAS_APT -eq 0 ]; then
        return 0  # Только для apt-based систем
    fi

    log_head "ШАГ 0: ПРЕДУСТАНОВКА ЗАВИСИМОСТЕЙ"

    # Проверяем установлен ли уже
    if rpm -q cryptopro-preinstall >/dev/null 2>&1 || \
       dpkg -l cryptopro-preinstall 2>/dev/null | grep -q "^ii"; then
        log_ok "cryptopro-preinstall уже установлен"
        return 0
    fi

    log_info "Устанавливаю cryptopro-preinstall (зависимости КриптоПро)..."
    log_info "Это установит: libpangox-compat, opensc, pcsc-lite, pcsc-lite-rutokens, pcsc-lite-ccid, newt52"

    apt-get install -y cryptopro-preinstall 2>&1
    if [ $? -eq 0 ]; then
        log_ok "cryptopro-preinstall установлен"
    else
        log_warn "cryptopro-preinstall недоступен в репозитории — устанавливаю зависимости вручную"
        # Устанавливаем важные зависимости вручную
        apt-get install -y libpangox-compat opensc pcsc-lite pcsc-lite-rutokens pcsc-lite-ccid newt52 2>/dev/null || \
        apt-get install -y libpangox-compat opensc pcscd libpcsclite1 2>/dev/null || true

        # Устанавливаем compat-пакет из нашей директории
        if [ -f /etc/altlinux-release ]; then
            install_one_pkg "cprocsp-compat-altlinux" "cprocsp-compat-altlinux (LSB compat)"
        elif grep -q SUSE /etc/os-release 2>/dev/null; then
            install_one_pkg "cprocsp-compat-suse" "cprocsp-compat-suse"
        fi
    fi
}

# =============================================================================
# ОСНОВНАЯ УСТАНОВКА КРИПТОПРО
# =============================================================================
install_cryptopro() {
    log_head "УСТАНОВКА КРИПТОПРО CSP"

    # Проверяем наличие пакетов
    if ! ls ./lsb-cprocsp-base*.rpm >/dev/null 2>&1 && \
       ! ls ./lsb-cprocsp-base*.deb >/dev/null 2>&1; then
        log_err "Базовые пакеты КриптоПро не найдены в: $(pwd)"
        log_warn "Скопируйте содержимое linux-amd64.tgz в директорию со скриптом"
        press_enter
        return 1
    fi

    log_info "Архитектура: ${BITS}-бит (${MACHINE_ARCH})"
    detect_system_type

    # ШАГ 0: предустановка зависимостей
    install_preinstall

    # --- МЕТОД 1: родной install.sh (если есть в директории) ---
    if [ -f "./install.sh" ]; then
        log_head "ШАГ 1: УСТАНОВКА ЧЕРЕЗ install.sh"
        log_info "Найден install.sh — использую его для установки"

        printf "\n${YELLOW}Установить поддержку Рутокен/JaCarta/токенов? [y/N]:${NC} "
        read ANS_RDR
        printf "${YELLOW}Установить PKCS11 (для Госуслуг/браузера)? [y/N]:${NC} "
        read ANS_PKCS

        EXTRA_PKGS=""
        case "$ANS_RDR" in [yYдД]*)
            EXTRA_PKGS="$EXTRA_PKGS cprocsp-rdr-gui-gtk cprocsp-rdr-rutoken cprocsp-rdr-pcsc cprocsp-rdr-jacarta"
        esac
        case "$ANS_PKCS" in [yYдД]*)
            EXTRA_PKGS="$EXTRA_PKGS lsb-cprocsp-pkcs11"
        esac

        log_info "Запускаю: sh ./install.sh kc1 $EXTRA_PKGS"
        # shellcheck disable=SC2086
        sh ./install.sh kc1 $EXTRA_PKGS
        INST_RESULT=$?

        if [ $INST_RESULT -eq 0 ]; then
            log_ok "Базовая установка через install.sh завершена"
        else
            log_warn "install.sh вернул код $INST_RESULT — дополнительно устанавливаю пакеты напрямую"
            _install_base_packages
        fi
    else
        # --- МЕТОД 2: прямая установка ---
        log_head "ШАГ 1: ПРЯМАЯ УСТАНОВКА ПАКЕТОВ"
        _install_base_packages
    fi

    # ШАГ 2: Инструменты КриптоПро (cptools)
    log_head "ШАГ 2: ИНСТРУМЕНТЫ КРИПТОПРО (cptools)"
    printf "${YELLOW}Установить графические Инструменты КриптоПро (cptools)? [Y/n]:${NC} "
    read ANS_CPTOOLS
    case "$ANS_CPTOOLS" in
        [nNнН]*) log_info "cptools пропущен" ;;
        *)
            install_one_pkg "cprocsp-cptools-gtk" "Инструменты КриптоПро (cptools-gtk)" || \
            install_one_pkg "cprocsp-cptools"     "Инструменты КриптоПро (cptools)"
            ;;
    esac

    # ШАГ 3: CAdES плагин для браузера
    log_head "ШАГ 3: CADES ПЛАГИН (ЭЦП в браузере)"
    printf "${YELLOW}Установить CAdES плагин (нужен для ЭЦП на сайтах)? [Y/n]:${NC} "
    read ANS_CADES
    case "$ANS_CADES" in
        [nNнН]*) log_info "CAdES пропущен" ;;
        *) _install_cades ;;
    esac

    # ШАГ 4: Настройка считывателя HDIMAGE
    _setup_hdimage_reader

    # ШАГ 5: Запуск служб
    _start_services

    log_ok "======================================="
    log_ok "Установка КриптоПро завершена!"
    log_ok "======================================="
    printf "\n${BOLD}Следующие шаги:${NC}\n"
    printf "  1. Активируйте лицензию (пункт меню 'Активировать лицензию')\n"
    printf "  2. Запустите браузер и проверьте: https://www.cryptopro.ru/sites/default/files/products/cades/demopage/cades_bes_sample.html\n"
    printf "  3. Для работы с токеном запустите: systemctl start pcscd\n"
    press_enter
}

# =============================================================================
# БАЗОВЫЕ ПАКЕТЫ (прямая установка)
# Порядок важен! capilite нужен до остальных
# =============================================================================
_install_base_packages() {
    log_info "Установка базовых пакетов КриптоПро..."

    # Compat для ALT Linux (обязателен если нет LSB)
    if [ -f /etc/altlinux-release ]; then
        install_one_pkg "cprocsp-compat-altlinux" "cprocsp-compat-altlinux (LSB compat для ALT)"
    elif grep -q SUSE /etc/os-release 2>/dev/null; then
        install_one_pkg "cprocsp-compat-suse" "cprocsp-compat-suse"
    fi

    # Базовые пакеты в правильном порядке (base → capilite → kc1 → rdr → curl → ca-certs)
    install_one_pkg "lsb-cprocsp-base"      "lsb-cprocsp-base (ядро КриптоПро)"
    install_one_pkg "lsb-cprocsp-capilite"  "lsb-cprocsp-capilite (CAPI Lite)"

    if [ "$BITS" = "64" ]; then
        install_one_pkg "lsb-cprocsp-kc1-64"   "lsb-cprocsp-kc1-64 (криптопровайдер KC1)"
        install_one_pkg "lsb-cprocsp-rdr-64"   "lsb-cprocsp-rdr-64 (поддержка ридеров)"
    else
        install_one_pkg "lsb-cprocsp-kc1"      "lsb-cprocsp-kc1 (криптопровайдер KC1)"
        install_one_pkg "lsb-cprocsp-rdr"      "lsb-cprocsp-rdr (поддержка ридеров)"
    fi

    install_one_pkg "cprocsp-curl"          "cprocsp-curl (libcurl с ГОСТ)"
    install_one_pkg "lsb-cprocsp-ca-certs"  "lsb-cprocsp-ca-certs (сертификаты ГУЦ)"

    # Дополнительные компоненты
    printf "\n${YELLOW}Установить GUI ридеров (нужен для диалогов ввода пароля)? [Y/n]:${NC} "
    read ANS
    case "$ANS" in [nNнН]*) ;; *)
        install_one_pkg "cprocsp-rdr-gui-gtk" "cprocsp-rdr-gui-gtk (GUI диалоги)"
    esac

    printf "${YELLOW}Установить поддержку Рутокен? [y/N]:${NC} "
    read ANS
    case "$ANS" in [yYдД]*)
        install_one_pkg "cprocsp-rdr-rutoken" "cprocsp-rdr-rutoken (Рутокен)"
        install_one_pkg "cprocsp-rdr-pcsc"    "cprocsp-rdr-pcsc (PC/SC ридеры)"
        # Драйверы Рутокен из нашего дистрибутива
        install_one_pkg "ifd-rutokens"         "ifd-rutokens (конфигурация Рутокен)"
        if [ $HAS_APT -eq 1 ]; then
            apt-get install -y pcsc-lite-rutokens pcsc-lite-ccid 2>/dev/null || true
        fi
    esac

    printf "${YELLOW}Установить поддержку JaCarta? [y/N]:${NC} "
    read ANS
    case "$ANS" in [yYдД]*)
        install_one_pkg "cprocsp-rdr-jacarta" "cprocsp-rdr-jacarta (JaCarta)"
    esac

    printf "${YELLOW}Установить PKCS11 (для работы через браузер/Госуслуги)? [Y/n]:${NC} "
    read ANS
    case "$ANS" in [nNнН]*) ;; *)
        install_one_pkg "lsb-cprocsp-pkcs11" "lsb-cprocsp-pkcs11 (PKCS#11)"
    esac
}

# =============================================================================
# УСТАНОВКА CADES + PLUGIN
# Ключевой компонент для ЭЦП в браузере
# =============================================================================
_install_cades() {
    log_info "Установка CAdES плагина..."

    # Проверяем наличие локальных файлов
    CADES_FOUND=0
    PLUGIN_FOUND=0
    pkg_exists_locally "cprocsp-pki-cades"  && CADES_FOUND=1
    pkg_exists_locally "cprocsp-pki-plugin" && PLUGIN_FOUND=1

    if [ $CADES_FOUND -eq 0 ] || [ $PLUGIN_FOUND -eq 0 ]; then
        log_warn "Пакеты CAdES не найдены локально"
        printf "${YELLOW}Попытаться скачать с cryptopro.ru? [Y/n]:${NC} "
        read ANS_DL
        case "$ANS_DL" in
            [nNнН]*) ;;
            *) _download_cades ;;
        esac
    fi

    # Устанавливаем что нашли
    pkg_exists_locally "cprocsp-pki-cades" && \
        install_one_pkg "cprocsp-pki-cades"  "cprocsp-pki-cades (CAdES ЭЦП)" || \
        log_warn "cprocsp-pki-cades не установлен"

    pkg_exists_locally "cprocsp-pki-plugin" && \
        install_one_pkg "cprocsp-pki-plugin" "cprocsp-pki-plugin (браузерный плагин)" || \
        log_warn "cprocsp-pki-plugin не установлен"

    # Создаём симлинки для браузеров
    _setup_browser_symlinks

    log_info ""
    log_info "После установки CAdES:"
    log_info "  1. Перезапустите браузер"
    log_info "  2. Установите расширение КриптоПро из магазина браузера"
    log_info "  3. Проверьте: https://www.cryptopro.ru/sites/default/files/products/cades/demopage/"
}

# =============================================================================
# СКАЧИВАНИЕ CADES С CRYPTOPRO.RU
# =============================================================================
_download_cades() {
    log_info "Скачиваю пакеты CAdES..."
    get_downloader
    if [ -z "$DOWNLOADER" ]; then
        log_err "Нет curl или wget: apt-get install curl"
        return 1
    fi

    # Актуальные URL для CAdES 2.0 (публичные, без авторизации)
    # Версии: 2.0.14892 (новая), 2.0.14815 (старая — уже есть в директории)

    CADES_URLS="
https://cryptopro.ru/sites/default/files/products/cades/2.0.14892/cprocsp-pki-cades-64-2.0.14892-1.amd64.rpm
https://cryptopro.ru/sites/default/files/products/cades/current_release_2_0/cprocsp-pki-cades-64-2.0-amd64.rpm
https://cryptopro.ru/sites/default/files/products/cades/2.0.14815/cprocsp-pki-cades-64-2.0.14815-1.amd64.rpm
"
    PLUGIN_URLS="
https://cryptopro.ru/sites/default/files/products/cades/2.0.14892/cprocsp-pki-plugin-64-2.0.14892-1.amd64.rpm
https://cryptopro.ru/sites/default/files/products/cades/current_release_2_0/cprocsp-pki-plugin-64-2.0-amd64.rpm
https://cryptopro.ru/sites/default/files/products/cades/2.0.14815/cprocsp-pki-plugin-64-2.0.14815-1.amd64.rpm
"

    if ! pkg_exists_locally "cprocsp-pki-cades"; then
        DOWNLOADED=0
        for URL in $CADES_URLS; do
            [ -z "$URL" ] && continue
            OUTFILE="cprocsp-pki-cades-64-downloaded.amd64.rpm"
            log_info "Скачиваю: $URL"
            if download_file "$URL" "$OUTFILE" && [ -s "$OUTFILE" ]; then
                # Проверяем что это валидный RPM
                if file "$OUTFILE" 2>/dev/null | grep -qi "RPM\|rpm"; then
                    log_ok "cprocsp-pki-cades скачан → $OUTFILE"
                    DOWNLOADED=1
                    break
                else
                    log_warn "Скачан невалидный файл (возможно, требуется авторизация)"
                    rm -f "$OUTFILE"
                fi
            else
                rm -f "$OUTFILE" 2>/dev/null
            fi
        done
        [ $DOWNLOADED -eq 0 ] && log_warn "Скачать cprocsp-pki-cades не удалось. Ссылка: https://cryptopro.ru/products/cades/downloads"
    fi

    if ! pkg_exists_locally "cprocsp-pki-plugin"; then
        DOWNLOADED=0
        for URL in $PLUGIN_URLS; do
            [ -z "$URL" ] && continue
            OUTFILE="cprocsp-pki-plugin-64-downloaded.amd64.rpm"
            log_info "Скачиваю: $URL"
            if download_file "$URL" "$OUTFILE" && [ -s "$OUTFILE" ]; then
                if file "$OUTFILE" 2>/dev/null | grep -qi "RPM\|rpm"; then
                    log_ok "cprocsp-pki-plugin скачан → $OUTFILE"
                    DOWNLOADED=1
                    break
                else
                    rm -f "$OUTFILE"
                fi
            else
                rm -f "$OUTFILE" 2>/dev/null
            fi
        done
        [ $DOWNLOADED -eq 0 ] && log_warn "Скачать cprocsp-pki-plugin не удалось."
    fi
}

# =============================================================================
# СОЗДАНИЕ СИМЛИНКОВ ДЛЯ БРАУЗЕРОВ (CAdES)
# =============================================================================
_setup_browser_symlinks() {
    log_info "Настройка браузерных плагинов..."

    # Ищем libnpcades.so
    NPCADES=""
    for P in \
        "/opt/cprocsp/lib/amd64/libnpcades.so.2.0.0" \
        "/opt/cprocsp/lib/amd64/libnpcades.so" \
        "/opt/cprocsp/lib/ia32/libnpcades.so.2.0.0" \
        "/opt/cprocsp/lib/ia32/libnpcades.so"
    do
        [ -f "$P" ] && NPCADES="$P" && break
    done

    if [ -n "$NPCADES" ]; then
        log_ok "Найден плагин: $NPCADES"
        # Создаём симлинки для Firefox/Mozilla
        for PLUGDIR in \
            "/usr/lib64/browser-plugins" \
            "/usr/lib/browser-plugins" \
            "/usr/lib/mozilla/plugins" \
            "/usr/lib64/mozilla/plugins" \
            "/usr/lib/firefox/browser/plugins"
        do
            mkdir -p "$PLUGDIR" 2>/dev/null || continue
            ln -sf "$NPCADES" "$PLUGDIR/libnpcades.so" 2>/dev/null && \
                log_ok "Симлинк Firefox: $PLUGDIR/libnpcades.so"
        done
    else
        log_warn "libnpcades.so не найден — симлинки не созданы"
        log_warn "Установите расширение из магазина браузера вручную"
    fi

    # Для современных браузеров (Chromium Manifest V3) нужно расширение из магазина
    log_info "Для Chromium/Chrome: установите расширение 'КриптоПро ЭЦП' из Chrome Web Store"
    log_info "Для Firefox: установите дополнение с extensions.cryptopro.ru"
}

# =============================================================================
# НАСТРОЙКА СЧИТЫВАТЕЛЯ HDIMAGE (хранилище ключей на жёстком диске)
# =============================================================================
_setup_hdimage_reader() {
    log_head "ШАГ 4: НАСТРОЙКА СЧИТЫВАТЕЛЯ HDIMAGE"
    log_info "HDIMAGE — локальное хранилище контейнеров (/var/opt/cprocsp/keys/)"

    CPCONFIG_BIN=""
    [ -x "$CPCONFIG" ] && CPCONFIG_BIN="$CPCONFIG"
    [ -z "$CPCONFIG_BIN" ] && [ -x "$CPCONFIG_64" ] && CPCONFIG_BIN="$CPCONFIG_64"
    [ -z "$CPCONFIG_BIN" ] && [ -x "$CPCONFIG_32" ] && CPCONFIG_BIN="$CPCONFIG_32"

    if [ -z "$CPCONFIG_BIN" ]; then
        log_warn "cpconfig не найден — пропускаем настройку HDIMAGE"
        log_warn "(КриптоПро может быть не установлен или служба не запущена)"
        return
    fi

    # Проверяем есть ли уже HDIMAGE
    if "$CPCONFIG_BIN" -hardware reader -view 2>/dev/null | grep -q "HDIMAGE"; then
        log_ok "Считыватель HDIMAGE уже настроен"
    else
        log_info "Добавляю считыватель HDIMAGE..."
        "$CPCONFIG_BIN" -hardware reader -add HDIMAGE store 2>&1 && \
            log_ok "HDIMAGE добавлен" || \
            log_warn "Не удалось добавить HDIMAGE (перезапустите службу и попробуйте снова)"
    fi

    # Проверяем FLASH
    if "$CPCONFIG_BIN" -hardware reader -view 2>/dev/null | grep -q "FLASH"; then
        log_ok "Считыватель FLASH уже настроен"
    else
        "$CPCONFIG_BIN" -hardware reader -add FLASH store 2>/dev/null && \
            log_ok "FLASH добавлен" || true
    fi
}

# =============================================================================
# ЗАПУСК СЛУЖБ
# =============================================================================
_start_services() {
    log_head "ШАГ 5: ЗАПУСК СЛУЖБ"

    # Служба КриптоПро
    log_info "Запускаю cprocsp..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable cprocsp 2>/dev/null || true
        systemctl restart cprocsp 2>/dev/null && log_ok "cprocsp запущен (systemd)" || {
            log_warn "systemd не смог запустить cprocsp"
            /etc/init.d/cprocsp start 2>/dev/null && log_ok "cprocsp запущен (init.d)" || true
        }
    elif [ -x /etc/init.d/cprocsp ]; then
        /etc/init.d/cprocsp start 2>/dev/null && log_ok "cprocsp запущен" || true
    else
        log_warn "Не удалось определить способ запуска cprocsp"
        log_warn "Попробуйте вручную: /etc/init.d/cprocsp start"
    fi

    # Служба PC/SC (для токенов)
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable pcscd 2>/dev/null || true
        systemctl start pcscd 2>/dev/null && log_ok "pcscd запущен (PC/SC для токенов)" || true
    fi
}

# =============================================================================
# УДАЛЕНИЕ КРИПТОПРО
# =============================================================================
remove_cryptopro() {
    log_head "УДАЛЕНИЕ КРИПТОПРО CSP"
    printf "${RED}Вы уверены? Это удалит все пакеты КриптоПро! [y/N]:${NC} "
    read ANS
    case "$ANS" in [yYдД]*)
        log_info "Останавливаю службы..."
        systemctl stop cprocsp 2>/dev/null || service cprocsp stop 2>/dev/null || true
        systemctl stop pcscd 2>/dev/null || true

        # Через uninstall.sh если есть
        if [ -f "./uninstall.sh" ]; then
            log_info "Удаляю через uninstall.sh..."
            sh ./uninstall.sh 2>/dev/null && log_ok "Удалено через uninstall.sh" && { press_enter; return; }
        fi

        # Через apt-get
        if [ $HAS_APT -eq 1 ]; then
            log_info "Удаляю через apt-get..."
            apt-get remove -y lsb-cprocsp-base 2>/dev/null && \
                log_ok "КриптоПро удалён через apt-get" || true
        fi

        # Через rpm напрямую
        if [ $HAS_RPM -eq 1 ]; then
            rpm -qa | grep -iE "cprocsp|lsb-cprocsp" | xargs rpm -e --nodeps 2>/dev/null || true
        fi

        # Очистка lock-файла (известная проблема ALT Linux)
        rm -f /var/opt/cprocsp/tmp/.registry_lock 2>/dev/null || true

        log_ok "КриптоПро удалён"
    esac
    press_enter
}

# =============================================================================
# ПРОВЕРКА СОСТОЯНИЯ
# =============================================================================
check_cryptopro_status() {
    CP_INSTALLED=0
    CP_LICENSE_OK=0
    CP_LICENSE_SERIAL=""
    CP_LICENSE_EXPIRES=""
    CADES_INSTALLED=0
    CPTOOLS_INSTALLED=0

    # Инициализируем IS_DEBIAN и HAS_APT/HAS_RPM если ещё не определены
    : "${IS_DEBIAN:=0}"
    : "${HAS_APT:=0}"
    : "${HAS_RPM:=0}"
    if command -v apt-get >/dev/null 2>&1; then HAS_APT=1; fi
    if command -v rpm >/dev/null 2>&1; then HAS_RPM=1; fi

    # Проверяем установку
    if [ -x "$CSP_BIN" ] || [ -x "$CSP_BIN_64" ] || [ -x "$CSP_BIN_32" ]; then
        CP_INSTALLED=1
        [ -x "$CSP_BIN_64" ] && CSP_BIN="$CSP_BIN_64"
        [ -x "$CSP_BIN_32" ] && CSP_BIN="$CSP_BIN_32"
        [ -x "$CPCONFIG_64" ] && CPCONFIG="$CPCONFIG_64"
        [ -x "$CPCONFIG_32" ] && CPCONFIG="$CPCONFIG_32"
    elif [ $HAS_RPM -eq 1 ] && rpm -qa 2>/dev/null | grep -q "lsb-cprocsp-base"; then
        CP_INSTALLED=1
    elif [ $HAS_APT -eq 1 ] && (dpkg -l 2>/dev/null | grep -q "lsb-cprocsp-base" || \
         rpm -qa 2>/dev/null | grep -q "lsb-cprocsp-base"); then
        CP_INSTALLED=1
    fi

    # Проверяем лицензию
    if [ $CP_INSTALLED -eq 1 ]; then
        CPCONFIG_BIN=""
        [ -x "$CPCONFIG" ] && CPCONFIG_BIN="$CPCONFIG"
        [ -z "$CPCONFIG_BIN" ] && [ -x "$CPCONFIG_64" ] && CPCONFIG_BIN="$CPCONFIG_64"
        [ -z "$CPCONFIG_BIN" ] && [ -x "$CPCONFIG_32" ] && CPCONFIG_BIN="$CPCONFIG_32"

        if [ -n "$CPCONFIG_BIN" ]; then
            LIC_OUT=$("$CPCONFIG_BIN" -license -view 2>&1) || true
            if echo "$LIC_OUT" | grep -qiE "OK|valid|действительна|Expires"; then
                CP_LICENSE_OK=1
                CP_LICENSE_SERIAL=$(echo "$LIC_OUT" | grep -oE '[0-9A-Z]{5}-[0-9A-Z]{5}-[0-9A-Z]{5}-[0-9A-Z]{5}-[0-9A-Z]{5}' | head -1)
                CP_LICENSE_EXPIRES=$(echo "$LIC_OUT" | grep -i "Expires\|истекает" | head -1 | sed 's/.*Expires[: ]*//' | tr -d '\n')
            fi
        fi
    fi

    # Проверяем CAdES
    if [ $HAS_RPM -eq 1 ] && rpm -qa 2>/dev/null | grep -q "cprocsp-pki-cades"; then
        CADES_INSTALLED=1
    elif [ $HAS_APT -eq 1 ] && dpkg -l 2>/dev/null | grep -q "cprocsp-pki-cades"; then
        CADES_INSTALLED=1
    fi

    # Проверяем cptools
    if [ $HAS_RPM -eq 1 ] && rpm -qa 2>/dev/null | grep -q "cprocsp-cptools"; then
        CPTOOLS_INSTALLED=1
    elif [ -x "/opt/cprocsp/bin/amd64/cptools" ] || [ -x "/opt/cprocsp/bin/ia32/cptools" ]; then
        CPTOOLS_INSTALLED=1
    fi
}

# =============================================================================
# ПОКАЗАТЬ СТАТУС
# =============================================================================
show_status() {
    log_head "ТЕКУЩЕЕ СОСТОЯНИЕ СИСТЕМЫ"
    check_cryptopro_status

    printf "\n${BOLD}=== КриптоПро CSP ===${NC}\n"
    if [ $CP_INSTALLED -eq 1 ]; then
        log_ok "КриптоПро CSP: УСТАНОВЛЕН"
        CPCONFIG_BIN=""
        [ -x "$CPCONFIG_64" ] && CPCONFIG_BIN="$CPCONFIG_64"
        [ -x "$CPCONFIG_32" ] && CPCONFIG_BIN="$CPCONFIG_32"
        if [ -n "$CPCONFIG_BIN" ]; then
            VER=$("$CPCONFIG_BIN" -ver 2>/dev/null | head -3) || true
            [ -n "$VER" ] && printf "   Версия:\n%s\n" "$VER"
        fi
        if [ $CP_LICENSE_OK -eq 1 ]; then
            log_ok "Лицензия: АКТИВНА"
            [ -n "$CP_LICENSE_SERIAL" ]  && printf "   Серийный: %s\n" "$CP_LICENSE_SERIAL"
            [ -n "$CP_LICENSE_EXPIRES" ] && printf "   Истекает: %s\n" "$CP_LICENSE_EXPIRES"
        else
            log_warn "Лицензия: НЕ АКТИВИРОВАНА или ИСТЕКЛА"
            printf "   Активируйте: %s -license -set XXXXX-XXXXX-XXXXX-XXXXX-XXXXX\n" "${CPCONFIG_BIN:-cpconfig}"
        fi
    else
        log_warn "КриптоПро CSP: НЕ УСТАНОВЛЕН"
    fi

    printf "\n${BOLD}=== Компоненты ===${NC}\n"
    if [ $CADES_INSTALLED -eq 1 ]; then
        log_ok "CAdES плагин: УСТАНОВЛЕН"
    else
        log_warn "CAdES плагин: НЕ УСТАНОВЛЕН (нужен для ЭЦП в браузере)"
    fi

    if [ $CPTOOLS_INSTALLED -eq 1 ]; then
        log_ok "Инструменты КриптоПро (cptools): УСТАНОВЛЕН"
    else
        log_warn "Инструменты КриптоПро (cptools): НЕ УСТАНОВЛЕН"
    fi

    printf "\n${BOLD}=== Файлы пакетов ===${NC}\n"
    if ls ./lsb-cprocsp-base*.rpm >/dev/null 2>&1; then
        log_ok "Пакеты КриптоПро найдены в: $(pwd)"
        RPM_COUNT=$(ls ./*.rpm 2>/dev/null | wc -l)
        printf "   RPM файлов: %s\n" "$RPM_COUNT"
    else
        log_warn "Пакеты не найдены в: $(pwd)"
    fi

    printf "\n${BOLD}=== Службы ===${NC}\n"
    if systemctl is-active cprocsp >/dev/null 2>&1; then
        log_ok "cprocsp: работает"
    else
        log_warn "cprocsp: не запущен (попробуйте: systemctl start cprocsp)"
    fi
    if systemctl is-active pcscd >/dev/null 2>&1; then
        log_ok "pcscd (PC/SC для токенов): работает"
    else
        log_warn "pcscd: не запущен (попробуйте: systemctl start pcscd)"
    fi

    printf "\n${BOLD}=== Считыватели ===${NC}\n"
    CPCONFIG_BIN=""
    [ -x "$CPCONFIG_64" ] && CPCONFIG_BIN="$CPCONFIG_64"
    [ -x "$CPCONFIG_32" ] && CPCONFIG_BIN="$CPCONFIG_32"
    if [ -n "$CPCONFIG_BIN" ]; then
        READERS=$("$CPCONFIG_BIN" -hardware reader -view 2>/dev/null) || READERS=""
        if [ -n "$READERS" ]; then
            echo "$READERS" | grep "Nick name:" | sed 's/.*Nick name: /   /'
        else
            log_warn "Считыватели не настроены или служба не запущена"
        fi
    fi

    # Лицензии из PDF
    if [ -f "$PYTHON_HELPER" ]; then
        printf "\n${BOLD}=== Лицензии ===${NC}\n"
        COUNT=$(python3 "$PYTHON_HELPER" count 2>/dev/null) || COUNT=""
        if [ -n "$COUNT" ]; then
            TOTAL=$(echo "$COUNT" | grep "^TOTAL:" | cut -d: -f2)
            USED=$(echo "$COUNT" | grep "^USED:" | cut -d: -f2)
            FREE=$(echo "$COUNT" | grep "^FREE:" | cut -d: -f2)
            printf "  В PDF: ${BOLD}%s${NC} | Назначено: ${BOLD}%s${NC} | Свободно: ${BOLD}${GREEN}%s${NC}\n" \
                "${TOTAL:-?}" "${USED:-?}" "${FREE:-?}"
        fi
    fi

    press_enter
}

# =============================================================================
# УСТАНОВКА ЛИЦЕНЗИИ
# =============================================================================
install_license() {
    log_head "УСТАНОВКА ЛИЦЕНЗИИ КРИПТОПРО"

    if [ $CP_INSTALLED -eq 0 ]; then
        log_err "КриптоПро не установлен. Сначала установите КриптоПро."
        press_enter
        return 1
    fi

    printf "\n${BOLD}Откуда взять серийный номер?${NC}\n"
    printf "  1) Из PDF файла лицензий (автоматически — свободная лицензия)\n"
    printf "  2) Ввести серийный номер вручную\n"
    printf "\nВыбор [1-2]: "
    read LSRC

    SERIAL=""
    case "$LSRC" in
        1)
            if ! [ -f "$PYTHON_HELPER" ]; then
                log_err "Вспомогательный скрипт не найден: $PYTHON_HELPER"
                press_enter; return 1
            fi
            check_python
            log_info "Ищу свободные лицензии в PDF..."
            FREE_LIST=$(python3 "$PYTHON_HELPER" list-free 2>/dev/null)
            if [ -z "$FREE_LIST" ]; then
                log_warn "Свободных лицензий не найдено!"
                press_enter; return 1
            fi
            printf "\n${BOLD}Свободные лицензии:${NC}\n"
            N=1
            echo "$FREE_LIST" | while IFS= read -r LINE; do
                printf "  %3d) %s\n" "$N" "$LINE"
                N=$((N + 1))
            done
            TOTAL_FREE=$(echo "$FREE_LIST" | wc -l)
            printf "\nВведите номер [1-%d]: " "$TOTAL_FREE"
            read LNUM
            case "$LNUM" in *[!0-9]*|'') log_err "Неверный ввод"; press_enter; return 1 ;; esac
            if [ "$LNUM" -lt 1 ] || [ "$LNUM" -gt "$TOTAL_FREE" ]; then
                log_err "Номер вне диапазона"; press_enter; return 1
            fi
            SERIAL=$(echo "$FREE_LIST" | sed -n "${LNUM}p")
            ;;
        2)
            printf "Введите серийный номер (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX): "
            read SERIAL
            SERIAL=$(echo "$SERIAL" | tr -d ' ')
            ;;
        *)
            log_err "Неверный выбор"; press_enter; return 1 ;;
    esac

    if [ -z "$SERIAL" ]; then
        log_err "Серийный номер не выбран"; press_enter; return 1
    fi

    case "$SERIAL" in
        [0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]-[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]-[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]-[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]-[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z])
            log_ok "Серийный номер: $SERIAL" ;;
        *)
            log_err "Неверный формат: $SERIAL (ожидается XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)"
            press_enter; return 1 ;;
    esac

    printf "\n${BOLD}Введите имя для записи в Excel${NC}\n"
    printf "(ФИО, инвентарный номер, кабинет): "
    read ASSIGN_NAME
    [ -z "$ASSIGN_NAME" ] && ASSIGN_NAME="$(hostname)" && log_warn "Используем hostname: $ASSIGN_NAME"

    log_info "Устанавливаю лицензию..."
    LIC_RESULT=1

    CPCONFIG_BIN=""
    [ -x "$CPCONFIG" ] && CPCONFIG_BIN="$CPCONFIG"
    [ -z "$CPCONFIG_BIN" ] && [ -x "$CPCONFIG_64" ] && CPCONFIG_BIN="$CPCONFIG_64"
    [ -z "$CPCONFIG_BIN" ] && [ -x "$CPCONFIG_32" ] && CPCONFIG_BIN="$CPCONFIG_32"

    if [ -n "$CPCONFIG_BIN" ]; then
        "$CPCONFIG_BIN" -license -set "$SERIAL" 2>&1 && LIC_RESULT=0
    fi

    if [ $LIC_RESULT -ne 0 ] && [ -x "$CERTMGR" ]; then
        "$CERTMGR" -license -serial "$SERIAL" 2>&1 && LIC_RESULT=0
    fi

    if [ $LIC_RESULT -eq 0 ]; then
        log_ok "Лицензия успешно установлена!"
        systemctl restart cprocsp 2>/dev/null || service cprocsp restart 2>/dev/null || true
        sleep 1

        if [ -n "$CPCONFIG_BIN" ]; then
            LIC_CHECK=$("$CPCONFIG_BIN" -license -view 2>&1)
            printf "%s\n" "$LIC_CHECK"
            if echo "$LIC_CHECK" | grep -qiE "OK|valid|действительна|Expires"; then
                log_ok "Лицензия подтверждена"
            else
                log_warn "Подтверждение не получено — проверьте вручную: $CPCONFIG_BIN -license -view"
            fi
        fi

        if [ -f "$PYTHON_HELPER" ]; then
            check_python
            RESULT=$(python3 "$PYTHON_HELPER" assign "$SERIAL" "$ASSIGN_NAME" 2>/dev/null)
            case "$RESULT" in
                ADDED:*|UPDATED:*) log_ok "Записано в Excel: '$ASSIGN_NAME' → $SERIAL" ;;
                *) log_warn "Не удалось записать в Excel: $RESULT" ;;
            esac
        fi
    else
        log_err "Ошибка установки лицензии!"
        [ -n "$CPCONFIG_BIN" ] && printf "  Попробуйте вручную: %s -license -set %s\n" "$CPCONFIG_BIN" "$SERIAL"
        press_enter; return 1
    fi

    press_enter
}

# =============================================================================
# ПЕРЕУСТАНОВКА
# =============================================================================
reinstall_cryptopro() {
    log_head "ПЕРЕУСТАНОВКА КРИПТОПРО CSP"
    printf "${YELLOW}Удалить и установить заново? [y/N]:${NC} "
    read ANS
    case "$ANS" in [yYдД]*)
        remove_cryptopro
        install_cryptopro
    esac
}

# =============================================================================
# ТАБЛИЦА ЛИЦЕНЗИЙ
# =============================================================================
show_license_table() {
    log_head "ТАБЛИЦА НАЗНАЧЕННЫХ ЛИЦЕНЗИЙ"
    check_python
    if ! [ -f "$PYTHON_HELPER" ]; then
        log_err "Вспомогательный скрипт не найден"; press_enter; return
    fi
    DATA=$(python3 "$PYTHON_HELPER" list-excel 2>/dev/null)
    if [ -z "$DATA" ]; then
        log_warn "Excel файл не найден или пуст"
    else
        printf "\n${BOLD}%-45s %-18s %s${NC}\n" "Название" "IP" "Серийный номер"
        printf "%s\n" "----------------------------------------------------------------------"
        echo "$DATA" | while IFS=$(printf '\t') read -r SERIAL NAME IP; do
            printf "%-45s %-18s %s\n" \
                "$(echo "$NAME" | cut -c1-44)" \
                "$(echo "$IP" | cut -c1-17)" \
                "$SERIAL"
        done
    fi
    press_enter
}

# =============================================================================
# МЕНЮ СКАЧИВАНИЯ
# =============================================================================
download_menu() {
    log_head "СКАЧИВАНИЕ КОМПОНЕНТОВ"
    printf "\n${BOLD}Что скачать?${NC}\n"
    printf "  1) CAdES плагин (cprocsp-pki-cades + cprocsp-pki-plugin)\n"
    printf "  0) Назад\n"
    printf "\nВыбор [0-1]: "
    read DCHOICE
    case "$DCHOICE" in
        1) _download_cades; press_enter ;;
        0) return ;;
        *) log_warn "Неверный выбор" ;;
    esac
}

# =============================================================================
# ГЛАВНОЕ МЕНЮ
# =============================================================================
main_menu() {
    while true; do
        clear
        check_cryptopro_status

        printf "${BOLD}${CYAN}"
        printf "╔══════════════════════════════════════════════════════╗\n"
        printf "║     КриптоПро CSP — Менеджер (ALT Linux / RPM)     ║\n"
        printf "╚══════════════════════════════════════════════════════╝\n"
        printf "${NC}"

        # Статус
        if [ $CP_INSTALLED -eq 1 ]; then
            printf "  КриптоПро: ${GREEN}УСТАНОВЛЕН${NC}"
            if [ $CP_LICENSE_OK -eq 1 ]; then
                printf "  |  Лицензия: ${GREEN}АКТИВНА${NC}"
                [ -n "$CP_LICENSE_EXPIRES" ] && printf " (%s)" "$CP_LICENSE_EXPIRES"
            else
                printf "  |  Лицензия: ${RED}НЕ АКТИВНА${NC}"
            fi
        else
            printf "  КриптоПро: ${RED}НЕ УСТАНОВЛЕН${NC}"
        fi

        if [ $CADES_INSTALLED -eq 1 ]; then
            printf "  |  CAdES: ${GREEN}ДА${NC}"
        else
            printf "  |  CAdES: ${YELLOW}НЕТ${NC}"
        fi

        if [ $CPTOOLS_INSTALLED -eq 1 ]; then
            printf "  |  cptools: ${GREEN}ДА${NC}"
        else
            printf "  |  cptools: ${YELLOW}НЕТ${NC}"
        fi
        printf "\n"

        # Директория с пакетами
        printf "  Пакеты: ${CYAN}$(pwd)${NC}"
        if ls ./lsb-cprocsp-base*.rpm >/dev/null 2>&1; then
            printf "  ${GREEN}[найдены]${NC}"
        else
            printf "  ${RED}[НЕ НАЙДЕНЫ!]${NC}"
        fi
        printf "\n\n"

        # Меню
        if [ $CP_INSTALLED -eq 0 ]; then
            printf "  ${BOLD}1)${NC} Установить КриптоПро CSP (полная установка)\n"
            printf "  ${BOLD}2)${NC} Установить КриптоПро CSP + Активировать лицензию\n"
            printf "  ${BOLD}3)${NC} Только активировать лицензию\n"
            printf "  ${BOLD}4)${NC} Установить только CAdES плагин\n"
        else
            if [ $CP_LICENSE_OK -eq 0 ]; then
                printf "  ${BOLD}1)${NC} Активировать лицензию\n"
                printf "  ${BOLD}2)${NC} Переустановить + Активировать лицензию\n"
                printf "  ${BOLD}3)${NC} Переустановить (без лицензии)\n"
                printf "  ${BOLD}4)${NC} Установить/обновить CAdES плагин\n"
                printf "  ${BOLD}5)${NC} Удалить КриптоПро\n"
            else
                printf "  ${BOLD}1)${NC} Активировать другую лицензию\n"
                printf "  ${BOLD}2)${NC} Переустановить КриптоПро\n"
                printf "  ${BOLD}3)${NC} Переустановить + Сменить лицензию\n"
                printf "  ${BOLD}4)${NC} Установить/обновить CAdES плагин\n"
                printf "  ${BOLD}5)${NC} Удалить КриптоПро\n"
            fi
        fi

        printf "\n  ${BOLD}${RED}F)${NC} ${RED}${BOLD}ПОЧИНИТЬ: 'Криптопровайдер не загружен'${NC}\n"
        printf "  ${BOLD}6)${NC} Настроить считыватели (HDIMAGE, FLASH, PC/SC)\n"
        printf "  ${BOLD}7)${NC} Скачать недостающие компоненты\n"
        printf "  ${BOLD}8)${NC} Подробный статус системы\n"
        printf "  ${BOLD}9)${NC} Таблица назначенных лицензий (Excel)\n"
        printf "  ${BOLD}0)${NC} Выход\n"
        printf "\nВыбор: "
        read CHOICE

        if [ $CP_INSTALLED -eq 0 ]; then
            case "$CHOICE" in
                1) install_cryptopro ;;
                2) install_cryptopro && install_license ;;
                3) install_license ;;
                4) detect_system_type; _install_cades; press_enter ;;
                f|F) fix_cryptoprovider ;;
                6) _setup_hdimage_reader; press_enter ;;
                7) download_menu ;;
                8) show_status ;;
                9) show_license_table ;;
                0) printf "\nДо свидания!\n"; exit 0 ;;
                *) log_warn "Неверный выбор" ;;
            esac
        else
            if [ $CP_LICENSE_OK -eq 0 ]; then
                case "$CHOICE" in
                    1) install_license ;;
                    2) reinstall_cryptopro && install_license ;;
                    3) reinstall_cryptopro ;;
                    4) detect_system_type; _install_cades; press_enter ;;
                    5) remove_cryptopro ;;
                    f|F) fix_cryptoprovider ;;
                    6) _setup_hdimage_reader; press_enter ;;
                    7) download_menu ;;
                    8) show_status ;;
                    9) show_license_table ;;
                    0) printf "\nДо свидания!\n"; exit 0 ;;
                    *) log_warn "Неверный выбор" ;;
                esac
            else
                case "$CHOICE" in
                    1) install_license ;;
                    2) reinstall_cryptopro ;;
                    3) reinstall_cryptopro && install_license ;;
                    4) detect_system_type; _install_cades; press_enter ;;
                    5) remove_cryptopro ;;
                    f|F) fix_cryptoprovider ;;
                    6) _setup_hdimage_reader; press_enter ;;
                    7) download_menu ;;
                    8) show_status ;;
                    9) show_license_table ;;
                    0) printf "\nДо свидания!\n"; exit 0 ;;
                    *) log_warn "Неверный выбор" ;;
                esac
            fi
        fi
    done
}

# =============================================================================
# ДИАГНОСТИКА И АВТОИСПРАВЛЕНИЕ: «КРИПТОПРОВАЙДЕР НЕ ЗАГРУЖЕН»
# Проверяет и исправляет все типичные причины по порядку
# =============================================================================
fix_cryptoprovider() {
    log_head "АВТОДИАГНОСТИКА: КРИПТОПРОВАЙДЕР НЕ ЗАГРУЖЕН"
    printf "${BOLD}Проверяю все возможные причины...${NC}\n\n"

    FIX_ERRORS=0
    FIX_FIXED=0

    # ---- ШАБЛОН ПРОВЕРКИ ----
    # check_step <описание> <команда-проверки> <команда-исправления>
    # Используем прямые блоки ниже для читаемости

    # ------------------------------------------------------------------
    # ШАГ 1: КриптоПро установлен?
    # ------------------------------------------------------------------
    printf "${BOLD}[1/9]${NC} Проверяю: КриптоПро CSP установлен...\n"
    if [ -x "$CPCONFIG_64" ] || [ -x "$CPCONFIG_32" ]; then
        log_ok "КриптоПро установлен"
        [ -x "$CPCONFIG_64" ] && _CPCONF="$CPCONFIG_64" || _CPCONF="$CPCONFIG_32"
        [ -x "$CSP_BIN_64" ]  && _CSPBIN="$CSP_BIN_64"  || _CSPBIN="$CSP_BIN_32"
    else
        log_err "КриптоПро НЕ установлен!"
        log_warn "→ Запустите пункт меню '1) Установить КриптоПро CSP'"
        FIX_ERRORS=$((FIX_ERRORS + 1))
        press_enter
        return 1
    fi

    # ------------------------------------------------------------------
    # ШАГ 2: Служба cprocsp запущена?
    # ------------------------------------------------------------------
    printf "\n${BOLD}[2/9]${NC} Проверяю: служба cprocsp...\n"
    SVC_OK=0
    if systemctl is-active cprocsp >/dev/null 2>&1; then
        log_ok "Служба cprocsp: работает"
        SVC_OK=1
    else
        log_warn "Служба cprocsp НЕ запущена — запускаю..."
        # Пробуем несколько способов
        if systemctl start cprocsp 2>/dev/null; then
            sleep 2
            systemctl is-active cprocsp >/dev/null 2>&1 && SVC_OK=1
        fi
        if [ $SVC_OK -eq 0 ] && [ -x /etc/init.d/cprocsp ]; then
            /etc/init.d/cprocsp start 2>/dev/null && SVC_OK=1
        fi
        if [ $SVC_OK -eq 0 ]; then
            # Принудительный перезапуск — иногда помогает
            rm -f /var/opt/cprocsp/tmp/.registry_lock 2>/dev/null
            systemctl restart cprocsp 2>/dev/null
            sleep 2
            systemctl is-active cprocsp >/dev/null 2>&1 && SVC_OK=1
        fi

        if [ $SVC_OK -eq 1 ]; then
            log_ok "Служба cprocsp запущена"
            FIX_FIXED=$((FIX_FIXED + 1))
        else
            log_err "Не удалось запустить cprocsp!"
            log_warn "Журнал: journalctl -u cprocsp -n 30"
            FIX_ERRORS=$((FIX_ERRORS + 1))
        fi
    fi

    # Включаем автозапуск
    systemctl enable cprocsp 2>/dev/null || true

    # ------------------------------------------------------------------
    # ШАГ 3: Лицензия активна?
    # ------------------------------------------------------------------
    printf "\n${BOLD}[3/9]${NC} Проверяю: лицензия...\n"
    LIC_OUT=$($_CPCONF -license -view 2>&1) || true
    if echo "$LIC_OUT" | grep -qiE "Expires|OK|valid|действительна"; then
        EXPIRES=$(echo "$LIC_OUT" | grep -i "Expires" | head -1)
        log_ok "Лицензия активна: $EXPIRES"
    else
        log_err "Лицензия НЕ активирована или истекла!"
        printf "   Вывод: %s\n" "$LIC_OUT"
        log_warn "→ Используйте пункт меню 'Активировать лицензию'"
        FIX_ERRORS=$((FIX_ERRORS + 1))
    fi

    # ------------------------------------------------------------------
    # ШАГ 4: Обязательные пакеты установлены?
    # ------------------------------------------------------------------
    printf "\n${BOLD}[4/9]${NC} Проверяю: обязательные пакеты...\n"
    MISSING_PKGS=""
    for PKG in lsb-cprocsp-base lsb-cprocsp-capilite lsb-cprocsp-kc1 cprocsp-curl; do
        if rpm -q "${PKG}" >/dev/null 2>&1 || \
           rpm -q "${PKG}-64" >/dev/null 2>&1 || \
           dpkg -l "${PKG}" 2>/dev/null | grep -q "^ii"; then
            log_ok "  $PKG — установлен"
        else
            log_warn "  $PKG — ОТСУТСТВУЕТ"
            MISSING_PKGS="$MISSING_PKGS $PKG"
        fi
    done
    if [ -n "$MISSING_PKGS" ]; then
        log_err "Не хватает пакетов:$MISSING_PKGS"
        log_warn "→ Запустите пункт меню '1) Установить КриптоПро CSP'"
        FIX_ERRORS=$((FIX_ERRORS + 1))
    else
        log_ok "Все обязательные пакеты установлены"
    fi

    # ------------------------------------------------------------------
    # ШАГ 5: Считыватель HDIMAGE настроен?
    # ------------------------------------------------------------------
    printf "\n${BOLD}[5/9]${NC} Проверяю: считыватель HDIMAGE...\n"
    READERS=$($_CPCONF -hardware reader -view 2>/dev/null) || READERS=""
    if echo "$READERS" | grep -q "HDIMAGE"; then
        log_ok "Считыватель HDIMAGE настроен"
    else
        log_warn "HDIMAGE не настроен — добавляю..."
        if $_CPCONF -hardware reader -add HDIMAGE store 2>/dev/null; then
            log_ok "HDIMAGE добавлен"
            FIX_FIXED=$((FIX_FIXED + 1))
        else
            log_warn "Не удалось добавить HDIMAGE (возможно, служба не запущена)"
        fi
    fi

    # ------------------------------------------------------------------
    # ШАГ 6: Права на /var/opt/cprocsp
    # ------------------------------------------------------------------
    printf "\n${BOLD}[6/9]${NC} Проверяю: права доступа к данным КриптоПро...\n"
    CPRO_DIR="/var/opt/cprocsp"
    if [ -d "$CPRO_DIR" ]; then
        # Снимаем залипший lock-файл
        if [ -f "$CPRO_DIR/tmp/.registry_lock" ]; then
            log_warn "Обнаружен залипший lock-файл — удаляю..."
            rm -f "$CPRO_DIR/tmp/.registry_lock" && log_ok "Lock-файл удалён" && FIX_FIXED=$((FIX_FIXED + 1))
        else
            log_ok "Lock-файлов нет"
        fi
        # Проверяем права
        chmod -R a+rw "$CPRO_DIR/tmp" 2>/dev/null || true
        chmod -R a+rw "$CPRO_DIR/keys" 2>/dev/null || true
        log_ok "Права на директории проверены"
    else
        log_warn "$CPRO_DIR не существует (КриптоПро не инициализирован)"
    fi

    # ------------------------------------------------------------------
    # ШАГ 7: Браузерный плагин (CAdES) установлен?
    # ------------------------------------------------------------------
    printf "\n${BOLD}[7/9]${NC} Проверяю: CAdES плагин...\n"
    CADES_OK=0
    if rpm -q cprocsp-pki-cades >/dev/null 2>&1 || \
       rpm -q cprocsp-pki-cades-64 >/dev/null 2>&1 || \
       dpkg -l cprocsp-pki-cades 2>/dev/null | grep -q "^ii"; then
        log_ok "cprocsp-pki-cades установлен"
        CADES_OK=1
    else
        log_warn "cprocsp-pki-cades НЕ установлен"
        log_warn "→ Используйте пункт '4) Установить CAdES плагин'"
        FIX_ERRORS=$((FIX_ERRORS + 1))
    fi

    # Проверяем симлинки плагина
    if [ $CADES_OK -eq 1 ]; then
        NPCADES=""
        for P in \
            "/opt/cprocsp/lib/amd64/libnpcades.so.2.0.0" \
            "/opt/cprocsp/lib/amd64/libnpcades.so" \
            "/opt/cprocsp/lib/ia32/libnpcades.so.2.0.0"
        do
            [ -f "$P" ] && NPCADES="$P" && break
        done

        if [ -n "$NPCADES" ]; then
            SYMLINK_OK=0
            for PLUGDIR in \
                "/usr/lib64/browser-plugins" \
                "/usr/lib/browser-plugins" \
                "/usr/lib/mozilla/plugins" \
                "/usr/lib64/mozilla/plugins"
            do
                [ -L "$PLUGDIR/libnpcades.so" ] && SYMLINK_OK=1 && break
            done

            if [ $SYMLINK_OK -eq 1 ]; then
                log_ok "Симлинк плагина для браузера создан"
            else
                log_warn "Симлинки плагина отсутствуют — создаю..."
                for PLUGDIR in \
                    "/usr/lib64/browser-plugins" \
                    "/usr/lib/browser-plugins" \
                    "/usr/lib/mozilla/plugins" \
                    "/usr/lib64/mozilla/plugins"
                do
                    mkdir -p "$PLUGDIR" 2>/dev/null || continue
                    ln -sf "$NPCADES" "$PLUGDIR/libnpcades.so" 2>/dev/null && \
                        log_ok "Симлинк создан: $PLUGDIR/libnpcades.so" && \
                        FIX_FIXED=$((FIX_FIXED + 1))
                done
            fi
        else
            log_warn "libnpcades.so не найден в /opt/cprocsp/lib/"
        fi
    fi

    # ------------------------------------------------------------------
    # ШАГ 8: Служба pcscd (для токенов)
    # ------------------------------------------------------------------
    printf "\n${BOLD}[8/9]${NC} Проверяю: служба pcscd (PC/SC для токенов)...\n"
    if systemctl is-active pcscd >/dev/null 2>&1; then
        log_ok "pcscd работает"
    else
        log_warn "pcscd не запущен — запускаю..."
        systemctl enable pcscd 2>/dev/null || true
        systemctl start pcscd 2>/dev/null && \
            log_ok "pcscd запущен" && FIX_FIXED=$((FIX_FIXED + 1)) || \
            log_warn "pcscd не удалось запустить (возможно, не установлен pcsc-lite)"
    fi

    # ------------------------------------------------------------------
    # ШАГ 9: Перезапуск cprocsp после всех исправлений
    # ------------------------------------------------------------------
    printf "\n${BOLD}[9/9]${NC} Перезапускаю cprocsp для применения изменений...\n"
    systemctl restart cprocsp 2>/dev/null || \
        service cprocsp restart 2>/dev/null || \
        { /etc/init.d/cprocsp stop 2>/dev/null; sleep 1; /etc/init.d/cprocsp start 2>/dev/null; } || true
    sleep 2

    # Финальная проверка провайдера
    if [ -x "$_CSPBIN" ]; then
        CSP_TEST=$($_CSPBIN -keyset -verifycontext 2>&1) || true
        if echo "$CSP_TEST" | grep -qi "ErrorCode: 0x00000000\|succeeded"; then
            log_ok "КриптоПровайдер ОТВЕЧАЕТ! ($_CSPBIN -keyset -verifycontext)"
            FIX_FIXED=$((FIX_FIXED + 1))
        else
            log_warn "КриптоПровайдер ещё не отвечает"
            printf "   Вывод: %s\n" "$CSP_TEST"
        fi
    fi

    # ------------------------------------------------------------------
    # ИТОГ
    # ------------------------------------------------------------------
    printf "\n"
    printf "${BOLD}════════════════════════════════════════${NC}\n"
    if [ $FIX_ERRORS -eq 0 ]; then
        printf "${GREEN}${BOLD}✓ Всё в порядке! Ошибок не найдено.${NC}\n"
        printf "  Исправлений применено: %s\n" "$FIX_FIXED"
        printf "\n${BOLD}Если браузер по-прежнему не видит провайдер:${NC}\n"
        printf "  1. Перезапустите браузер полностью (закройте все окна)\n"
        printf "  2. Установите расширение 'КриптоПро ЭЦП Browser Plug-in'\n"
        printf "     Firefox: https://cryptopro.ru/sites/default/files/products/cades/\n"
        printf "     Chrome:  расширение 'CryptoPro Extension for CAdES Browser Plug-in'\n"
        printf "  3. Разрешите расширению доступ ко всем сайтам\n"
    else
        printf "${RED}${BOLD}✗ Найдено проблем: %s${NC}\n" "$FIX_ERRORS"
        printf "${GREEN}  Автоматически исправлено: %s${NC}\n" "$FIX_FIXED"
        printf "\n${YELLOW}Нерешённые проблемы требуют ручного вмешательства (см. выше).${NC}\n"
    fi
    printf "${BOLD}════════════════════════════════════════${NC}\n"

    press_enter
}

# =============================================================================
# ТОЧКА ВХОДА
# =============================================================================
if [ "$(id -u)" -ne 0 ]; then
    printf "${RED}Скрипт необходимо запускать с правами root:${NC}\n"
    printf "  sudo sh %s\n" "$0"
    exit 1
fi

detect_arch
detect_system_type
main_menu
