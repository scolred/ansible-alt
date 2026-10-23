#!/bin/sh

# Copyright(C) 2005-2017
#
# Этот файл содержит информацию, являющуюся
# собственностью компании Крипто-Про.
#
# Любая часть этого файла не может быть скопирована,
# исправлена, переведена на другие языки,
# локализована или модифицирована любым способом,
# откомпилирована, передана по сети с или на
# любую компьютерную систему без предварительного
# заключения соглашения с компанией Крипто-Про.
#
# This is proprietary information of
# Crypto-Pro company.
#
# Any part of this file can not be copied,
# corrected, translated into other languages,
# localized or modified by any means,
# compiled, transferred over a network from or to
# any computer system without preliminary
# agreement with Crypto-Pro company

WIDTH=78
HEIGHT=20

# Exit codes.
SUCCESS=0
FAILURE=1
PACKAGES_NOT_AVAILABLE=2

localize() {
    if test "$LANG" = "ru_RU.UTF-8"; then
	TITLE="Установщик КриптоПро CSP"
	BUTTON_next="Далее"
	BUTTON_exit="Выход"
	BUTTON_yes="Да"
	BUTTON_no="Нет"
	BUTTON_back="Назад"
	BUTTON_cancel="Отмена"
	BUTTON_enter_license="Ввести лицензию"
	BUTTON_later="Позже"
	BUTTON_install="Установить"
	BUTTON_reinstall="Переустановить"
	BUTTON_uninstall="Удалить"
	BUTTON_enter_serial="Ввести"
	BUTTON_select="Выбрать"
	BUTTON_add="Добавить"

	MENU_reinstall="Переустановить пакеты КриптоПро CSP"
	MENU_uninstall="Удалить пакеты КриптоПро CSP"
	MENU_license="Ввести или проверить лицензию"

	SHORT_kc1="Криптопровайдер KC1"
	SHORT_kc2="Провайдер KC2 (только по необходимости)"
	SHORT_gui="Графические диалоги"
	SHORT_readers="Поддержка токенов и смарт-карт"
	SHORT_cptools="cptools, многоцелевое графическое приложение"
	SHORT_stunnel="stunnel, SSL/TLS туннель с поддержкой ГОСТ"
	SHORT_pkcs11="Библиотека PKCS #11 (для gosuslugi.ru)"
	SHORT_import_ca="Импортировать корневые сертификаты из ОС"
	DESCR_kc1="Криптопровайдер KC1"
	DESCR_kc2="Криптопровайдер KC2"

	TEXT_main_menu="Добро пожаловать в мастер установки КриптоПро CSP

Мастер установки позволит установить, переустановить и удалить КриптоПро CSP с компьютера. Нажмите $BUTTON_next для продолжения или $BUTTON_exit для выхода из мастера установки."
	TEXT_install_confirmation_head="Будут установлены:
"
	TEXT_install_confirmation_tail="Нажмите $BUTTON_install, чтобы начать установку. Чтобы вернуться и изменить настройки, нажмите $BUTTON_back."
	TEXT_select_packages="Выберите набор для установки.

Нажимайте на элементы списка ниже, чтобы выбрать набор для установки. Не устанавливайте пакеты без необходимости: это усложнит настройку и может снизить производительность."
	TEXT_reinstall_cut="
Эти пакеты будут удалены. Продолжить переустановку?"
	TEXT_reinstall_confirm="Переустановить КриптоПро CSP

Вы выбрали переустановить текущую установку КриптоПро CSP.

Нажмите $BUTTON_reinstall, чтобы переустановить КритпоПро CSP. Если вы хотите проверить или изменить настройки установки, нажмите $BUTTON_back."
	TEXT_uninstall_confirm="Удаление КриптоПро CSP

Вы выбрали удалить КриптоПро CSP с компьютера.

Нажмите $BUTTON_uninstall, чтобы удалить КриптоПро CSP с компьютера. Если вы хотите проверить или изменить настройки установки, нажмите $BUTTON_back."
	TEXT_wrong_packages="Должен быть выбран хотя бы один из этих пакетов:

* $DESCR_kc1
* $DESCR_kc2"
	TEXT_set_license="Хотите ввести лицензионный ключ сейчас или сделать это позже?"
	TEXT_license_ok="Лицензия успешно проверена
"
	TEXT_license_bad="Ошибка проверки лицензии
"
	TEXT_license_enter="
Введите серийный номер лицензии:"
	TEXT_license_set="Лицензия установлена
"
	TEXT_license_notset="Ошибка при установке лицензии
"
	TEXT_choose_activity="Выберите операцию, которую нужно выполнить."

	ERROR_root="Ошибка: этот скрипт надо запускать от имени root или с помощью sudo"
    else	
	TITLE="CryptoPro CSP Setup"
	BUTTON_next="Next"
	BUTTON_exit="Exit"
	BUTTON_yes="Yes"
	BUTTON_no="No"
	BUTTON_back="Back"
	BUTTON_cancel="Cancel"
	BUTTON_enter_license="Enter the license now"
	BUTTON_later="Later"
	BUTTON_install="Install"
	BUTTON_reinstall="Reinstall"
	BUTTON_uninstall="Uninstall"
	BUTTON_enter_serial="Enter"
	BUTTON_select="Select"
	BUTTON_add="Add"

	MENU_reinstall="Reinstall CryptoPro CSP packages"
	MENU_uninstall="Uninstall CryptoPro CSP packages"
	MENU_license="Enter or check license"

	SHORT_kc1="KC1 Cryptographic Service Provider"
	SHORT_kc2="KC2 Provider (skip if not sure)"
	SHORT_gui="GUI dialogs component"
	SHORT_readers="Smart Card and Token support modules"
	SHORT_cptools="cptools, GUI application for various tasks"
	SHORT_stunnel="stunnel, SSL/TLS tunnel with GOST support"
	SHORT_pkcs11="PKCS #11 library (for gosuslugi.ru)"
	SHORT_import_ca="Import OS root certificates in CSP"
	DESCR_kc1="KC1 Cryptographic Service Provider"
	DESCR_kc2="KC2 Cryptographic Service Provider"

     	TEXT_main_menu="Welcome to the CryptoPro CSP Setup Wizard

The Setup Wizard will allow you to install, reinstall or remove CryptoPro CSP from your computer. Click $BUTTON_next to continue or $BUTTON_exit to exit the Setup Wizard."
	TEXT_install_confirmation_head="The following features will be installed:
"
	TEXT_install_confirmation_tail="Click $BUTTON_install to begin the installation. If you want to change your installation settings, click $BUTTON_back."
	TEXT_select_packages="Select the way you want features to be installed.

Click on the list items below to change the way features will be installed. Do not install unnecessary items: it will make configuration difficult and may impact performance."
	TEXT_reinstall_cut="
These packages will be removed. Proceed with the reinstallation?"
	TEXT_reinstall_confirm="Reinstall CryptoPro CSP

You have chosen to reinstall your current CryptoPro CSP installation.

Click $BUTTON_reinstall to reinstall CryptoPro CSP. If you want to review or change any of your installation changes, click $BUTTON_back."
	TEXT_uninstall_confirm="Uninstall CryptoPro CSP

You have chosen to uninstall the program from your computer.

Click $BUTTON_uninstall to uninstall CryptoPro CSP from your computer. If you want to review or change any of your installation changes, click $BUTTON_back."
	TEXT_wrong_packages="At least one of the following packages must be selected:

* $DESCR_kc1
* $DESCR_kc2"
	TEXT_set_license="Would you like to enter the license now, or postpone it for a while?"
	TEXT_license_ok="License check success
"
	TEXT_license_bad="License check error
"
	TEXT_license_enter="
Enter license serial number:"
	TEXT_license_set="License was set
"
	TEXT_license_notset="Error setting license
"
	TEXT_choose_activity="Select the operation you wish to perform."

	ERROR_root="Error: this script must be run as root or via sudo"
    fi
}

test_whiptail_and_scripts() {
    if ! command -v whiptail >/dev/null 2>&1 ; then
        echo "Error: whiptail wasn't found" >&2
        if [ -f /etc/debian_version ] ||
           [ -f /etc/mcst_version ] ||
            grep Ubuntu /etc/lsb-release >/dev/null 2>&1
        then
            echo "Please run 'sudo apt-get install whiptail'" >&2
        elif [ -f /etc/altlinux-release ] ; then
            echo "Please run 'sudo apt-get install newt52'" >&2
        else
            echo "Please run 'sudo yum install newt'" >&2
        fi
        exit "${FAILURE}"
    fi
    if ! ls ./install.sh ./uninstall.sh > /dev/null 2>&1 ; then
        echo "Error: necessary scripts were not found"
        exit "${FAILURE}"
    fi
    # shellcheck disable=SC2016
    if ! grep '"$1" = "--list"' ./uninstall.sh > /dev/null 2>&1 ; then
        echo "Error: uninstall script doesn't support querying packages"
        exit "${FAILURE}"
    fi
    if ! grep 'from-repo' ./install.sh > /dev/null 2>&1 ; then
        echo "Error: install script doesn't support installing from repository"
        exit "${FAILURE}"
    fi
}

check_license() {
    license="$(/opt/cprocsp/sbin/"${ARCH}"/cpconfig -license -view 2>&1)"
    if [ "$?" -eq "${SUCCESS}" ] ; then
        license_output="$TEXT_license_ok
${license}"
    else
        license_output="$TEXT_license_bad
${license}"
    fi
}

ask_about_license() {
    whiptail --title "$TITLE" \
        --yesno "$TEXT_set_license" \
        --yes-button "$BUTTON_enter_license" --no-button "$BUTTON_later" \
        "${HEIGHT}" "${WIDTH}" 
    if [ "$?" -ne "${SUCCESS}" ] ; then
        choose_activity${FROM_REPO_FUNC}
        return
    fi
    check_license
    license_menu
}

install_notification() {
    whiptail --title "$TITLE" \
        --msgbox "${install_log}" \
        --ok-button "Ok" \
        "${HEIGHT}" "${WIDTH}"
    if [ "${install_status}" -eq "${SUCCESS}" ] ; then
        ask_about_license
    else
        main_menu
    fi
}

wrong_packages() {
    whiptail --title "$TITLE" \
        --msgbox "$TEXT_wrong_packages" \
        --ok-button "Ok" \
        "${HEIGHT}" "${WIDTH}"
    select_packages${SUITE}
}

install_confirmation_rich() {
    whiptail --title "$TITLE" \
        --yesno "$TEXT_install_confirmation_head
${feature_descriptions}
$TEXT_install_confirmation_tail" \
        --yes-button "$BUTTON_install" --no-button "$BUTTON_back" \
        "${HEIGHT}" "${WIDTH}" 
    if [ "$?" -ne "${SUCCESS}" ] ; then
        select_packages${SUITE}
        return
    fi
    packages=""
    for feature_key in ${feature_keys} ; do
        case "${feature_key}" in
            "rdr-gui-gtk")
                packages="${packages} cprocsp-rdr-gui-gtk"
                ;;
            "readers")
                packages="${packages} cprocsp-rdr-pcsc cprocsp-rdr-emv cprocsp-rdr-inpaspot cprocsp-rdr-kst cprocsp-rdr-mskey cprocsp-rdr-novacard cprocsp-rdr-edoc cprocsp-rdr-rutoken cprocsp-rdr-cloud cprocsp-rdr-cpfkc cprocsp-rdr-infocrypt cprocsp-rdr-rosan cprocsp-rdr-cryptoki"
                ;;
            "pkcs11")
                packages="${packages} lsb-cprocsp-pkcs11"
                ;;
            "import-ca-certs")
                packages="${packages} lsb-cprocsp-import-ca-certs"
                ;;
            *)
                packages="${packages} ${feature_key}"
                ;;
        esac
    done
    if echo "${packages}" | grep -v kc1 | grep kc2 > /dev/null 2>&1 ; then
        kc="kc2"
    else
        kc="kc1"
    fi
    # shellcheck disable=SC2086
    install_log="$(sh ./install.sh ${FROM_REPO_OPT} ${kc} ${packages})"
    install_status="$?"
    install_notification
}

select_packages_rich() {
    feature_keys="$(
        whiptail --title "$TITLE" \
            --checklist "$TEXT_select_packages" \
            --ok-button "$BUTTON_next" --cancel-button "$BUTTON_exit" \
            "${HEIGHT}" "${WIDTH}" 8 --notags --separate-output \
            "lsb-cprocsp-kc1" "$SHORT_kc1" "ON" \
            "lsb-cprocsp-kc2" "$SHORT_kc2" "OFF" \
            "rdr-gui-gtk" "$SHORT_gui" "ON" \
            "readers" "$SHORT_readers" "OFF" \
            "cprocsp-cptools-gtk" "$SHORT_cptools" "ON" \
            "cprocsp-stunnel" "$SHORT_stunnel" "OFF" \
            "pkcs11" "$SHORT_pkcs11" "ON" \
            "import-ca-certs" "$SHORT_import_ca" "OFF" \
            3>&1 1>&2 2>&3
    )"
    if [ "$?" -ne "${SUCCESS}" ] ; then
        exit "${SUCCESS}"
    fi
    count="$(echo "${feature_keys}" | grep -c 'kc[1-2]')"
    if [ "${count}" -ne 0 ] ; then
        feature_descriptions=""
        for feature_key in ${feature_keys} ; do
            case "${feature_key}" in
                "lsb-cprocsp-kc1")
                    description="$DESCR_kc1"
                    ;;
                "lsb-cprocsp-kc2")
                    description="$DESCR_kc2"
                    ;;
                "rdr-gui-gtk")
                    description="$SHORT_gui"
                    ;;
                "readers")
                    description="$SHORT_readers"
                    ;;
                "cprocsp-cptools-gtk")
                    description="$SHORT_cptools"
                    ;;
                "cprocsp-stunnel")
                    description="$SHORT_stunnel"
                    ;;
                "pkcs11")
                    description="$SHORT_pkcs11"
                    ;;
                "import-ca-certs")
                    description="$SHORT_import_ca"
                    ;;
            esac
            feature_descriptions="${feature_descriptions}* ${description}
"
        done
        install_confirmation${SUITE}
    else
        wrong_packages
    fi
}

install_confirmation() {
    whiptail --title "$TITLE" \
        --yesno "$TEXT_install_confirmation_head
${feature_descriptions}
$TEXT_install_confirmation_tail" \
        --yes-button "$BUTTON_install" --no-button "$BUTTON_back" \
        "${HEIGHT}" "${WIDTH}" 
    if [ "$?" -ne "${SUCCESS}" ] ; then
        select_packages${SUITE}
        return
    fi
    packages=""
    for feature_key in ${feature_keys} ; do
        case "${feature_key}" in
            "rdr-gui-gtk")
                packages="${packages} cprocsp-rdr-gui-gtk"
                ;;
            "readers")
                packages="${packages} cprocsp-rdr-pcsc cprocsp-rdr-emv cprocsp-rdr-inpaspot cprocsp-rdr-kst cprocsp-rdr-mskey cprocsp-rdr-novacard cprocsp-rdr-edoc cprocsp-rdr-rutoken cprocsp-rdr-cloud cprocsp-rdr-cpfkc cprocsp-rdr-infocrypt cprocsp-rdr-rosan cprocsp-rdr-cryptoki"
                ;;
            "pkcs11")
                packages="${packages} lsb-cprocsp-pkcs11"
                ;;
            "import-ca-certs")
                packages="${packages} lsb-cprocsp-import-ca-certs"
                ;;
            *)
                packages="${packages} ${feature_key}"
                ;;
        esac
    done
    if echo "${packages}" | grep -v kc1 | grep kc2 > /dev/null 2>&1 ; then
        kc="kc2"
    else
        kc="kc1"
    fi
    # shellcheck disable=SC2086
    install_log="$(sh ./install.sh ${FROM_REPO_OPT} ${kc} ${packages})"
    install_status="$?"
    install_notification
}

select_packages() {
    feature_keys="$(
        whiptail --title "$TITLE" \
            --checklist "$TEXT_select_packages" \
            --ok-button "$BUTTON_next" --cancel-button "$BUTTON_exit" \
            "${HEIGHT}" "${WIDTH}" 7 --notags --separate-output \
            "lsb-cprocsp-kc1" "$SHORT_kc1" "ON" \
            "lsb-cprocsp-kc2" "$SHORT_kc2" "OFF" \
            "rdr-gui-gtk" "$SHORT_gui" "ON" \
            "readers" "$SHORT_readers" "OFF" \
            "cprocsp-stunnel" "$SHORT_stunnel" "OFF" \
            "pkcs11" "$SHORT_pkcs11" "ON" \
            "import-ca-certs" "$SHORT_import_ca" "OFF" \
            3>&1 1>&2 2>&3
    )"
    if [ "$?" -ne "${SUCCESS}" ] ; then
        exit "${SUCCESS}"
    fi
    count="$(echo "${feature_keys}" | grep -c 'kc[1-2]')"
    if [ "${count}" -ne 0 ] ; then
        feature_descriptions=""
        for feature_key in ${feature_keys} ; do
            case "${feature_key}" in
                "lsb-cprocsp-kc1")
                    description="$DESCR_kc1"
                    ;;
                "lsb-cprocsp-kc2")
                    description="$DESCR_kc2"
                    ;;
                "rdr-gui-gtk")
                    description="$SHORT_gui"
                    ;;
                "readers")
                    description="$SHORT_readers"
                    ;;
                "cprocsp-stunnel")
                    description="$SHORT_stunnel"
                    ;;
                "pkcs11")
                    description="$SHORT_pkcs11"
                    ;;
                "import-ca-certs")
                    description="$SHORT_import_ca"
                    ;;
            esac
            feature_descriptions="${feature_descriptions}* ${description}
"
        done
        install_confirmation${SUITE}
    else
        wrong_packages
    fi
}

reinstall_notification() {
    whiptail --title "$TITLE" \
        --msgbox "${reinstall_log}" \
        --ok-button "Ok" \
        "${HEIGHT}" "${WIDTH}"
    choose_activity${FROM_REPO_FUNC}
}

reinstall_cut_package_list() {
    whiptail --title "$TITLE" \
        --yesno "${reinstall_log}
$TEXT_reinstall_cut" \
        --yes-button "$BUTTON_yes" --no-button "$BUTTON_no" \
        "${HEIGHT}" "${WIDTH}" 
    if [ "$?" -ne "${SUCCESS}" ] ; then
        choose_activity${FROM_REPO_FUNC}
        return
    fi
    # shellcheck disable=SC2063
    unavailable="$(echo "${reinstall_log}" | grep '^*' | sed 's/*//' | xargs)"
    packages="$(echo "${packages}" "${unavailable}" | xargs -n1 | sort | uniq -u | xargs)"
    # shellcheck disable=SC2086
    reinstall_log="$(sh ./install.sh ${FROM_REPO_OPT} ${kc} ${packages})"
    reinstall_notification
}

reinstall_confirmation() {
    whiptail --title "$TITLE" \
        --yesno "$TEXT_reinstall_confirm" \
        --yes-button "$BUTTON_reinstall" --no-button "$BUTTON_back" \
        "${HEIGHT}" "${WIDTH}" --defaultno
    if [ "$?" -ne "${SUCCESS}" ] ; then
        choose_activity${FROM_REPO_FUNC}
        return
    fi
    packages="$(sh ./uninstall.sh --list | grep -v compat | xargs)"
    if echo "${packages}" | grep -v kc1 | grep kc2 > /dev/null 2>&1 ; then
        kc="kc2"
    else
        kc="kc1"
    fi
    # shellcheck disable=SC2086
    reinstall_log="$(sh ./install.sh ${FROM_REPO_OPT} ${kc} ${packages})"
    reinstall_status="$?"
    if [ "${reinstall_status}" -eq "${PACKAGES_NOT_AVAILABLE}" ] ; then
        reinstall_cut_package_list
    else
        reinstall_notification
    fi
}

uninstall_notification() {
    whiptail --title "$TITLE" \
        --msgbox "${uninstall_log}" \
        --ok-button "Ok" \
        "${HEIGHT}" "${WIDTH}"
    main_menu
}

uninstall_confirmation() {
    whiptail --title "$TITLE" \
        --yesno "$TEXT_uninstall_confirm" \
        --yes-button "$BUTTON_uninstall" --no-button "$BUTTON_back" \
        "${HEIGHT}" "${WIDTH}" --defaultno
    if [ "$?" -ne "${SUCCESS}" ] ; then
        choose_activity${FROM_REPO_FUNC}
        return
    fi
    uninstall_log="$(sh ./uninstall.sh)"
    uninstall_notification
}

input_license_finished() {
    whiptail --title "$TITLE" \
        --msgbox "${license_output}" \
        --ok-button "Ok" \
        "${HEIGHT}" "${WIDTH}"
    choose_activity${FROM_REPO_FUNC}
}

license_menu() {
    serial_number="$(
        whiptail --title "$TITLE" \
            --inputbox "${license_output}
$TEXT_license_enter" \
            --ok-button "$BUTTON_enter_serial" --cancel-button "$BUTTON_cancel" \
            "${HEIGHT}" "${WIDTH}" \
            3>&1 1>&2 2>&3
    )"
    if [ "$?" -ne "${SUCCESS}" ] ; then
        choose_activity${FROM_REPO_FUNC}
        return
    fi
    license="$(/opt/cprocsp/sbin/"${ARCH}"/cpconfig -license -set "${serial_number}" 2>&1)"
    if [ "$?" -eq "${SUCCESS}" ] ; then
        license_output="$TEXT_license_set
${license}"
    else
        license_output="$TEXT_license_noset
${license}"
    fi
    input_license_finished
}

rmrepo_notification() {
    whiptail --title "$TITLE" \
        --msgbox "CryptoPro packages and repository have been removed" \
        --ok-button "Ok" \
        "${HEIGHT}" "${WIDTH}"
    main_menu
}

rmrepo_confirmation() {
    whiptail --title "$TITLE" \
        --yesno "Uninstall CryptoPro CSP packages and repository

Click Uninstall to uninstall CryptoPro CSP and remove the CryptoPro CSP repository from your computer. If you want to review or change any of your installation changes, click Back." \
        --yes-button "$BUTTON_uninstall" --no-button "$BUTTON_back" \
        "${HEIGHT}" "${WIDTH}" --defaultno
    if [ "$?" -ne "${SUCCESS}" ] ; then
        choose_activity${FROM_REPO_FUNC}
        return
    fi
    sh ./uninstall.sh
    sed -i '/cryptopro/d' /etc/apt/sources.list
    for _source in /etc/apt/sources.list.d/* ; do
        sed -i '/cryptopro/d' "${_source}"
    done
    [ -s /etc/apt/sources.list.d/cprocsp.list ] || rm -f /etc/apt/sources.list.d/cprocsp.list
    apt-key del "$(apt-key list | grep -B 1 CryptoPro | head -1)"
    apt-get update
    rmrepo_notification
}

choose_activity() {
    choice="$(
        whiptail --title "$TITLE" \
            --menu "$TEXT_choose_activity" \
            --ok-button "$BUTTON_select" --cancel-button "$BUTTON_exit" \
            "${HEIGHT}" "${WIDTH}" 3 --notags\
            "Reinstall" "$MENU_reinstall" \
            "Uninstall" "$MENU_uninstall" \
            "License" "$MENU_license" \
            3>&1 1>&2 2>&3
    )"
    if [ "$?" -ne "${SUCCESS}" ] ; then
        exit "${SUCCESS}"
    fi
    case "${choice}" in
        "Reinstall")
            reinstall_confirmation
            ;;
        "Uninstall")
            uninstall_confirmation
            ;;
        "License")
            check_license
            license_menu
            ;;
    esac
}

choose_activity_from_repo() {
    choice="$(
        whiptail --title "$TITLE" \
            --menu "$TEXT_choose_activity" \
            --ok-button "$BUTTON_select" --cancel-button "$BUTTON_exit" \
            "${HEIGHT}" "${WIDTH}" 4 --notags\
            "Reinstall" "$MENU_reinstall" \
            "Uninstall" "$MENU_uninstall" \
            "Rmrepo" "Uninstall CSP packages and remove CSP repository" \
            "License" "$MENU_license" \
            3>&1 1>&2 2>&3
    )"
    if [ "$?" -ne "${SUCCESS}" ] ; then
        exit "${SUCCESS}"
    fi
    case "${choice}" in
        "Reinstall")
            reinstall_confirmation
            ;;
        "Uninstall")
            uninstall_confirmation
            ;;
        "Rmrepo")
            rmrepo_confirmation
            ;;
        "License")
            check_license
            license_menu
            ;;
    esac
}

add_repo_notification() {
    whiptail --title "$TITLE" \
        --msgbox "${add_repo_notification}" \
        --ok-button "Ok" \
        "${HEIGHT}" "${WIDTH}"
    if [ "${add_repo_status}" -ne "${SUCCESS}" ] ; then
        sed -i '/cryptopro/d' /etc/apt/sources.list
        for _source in /etc/apt/sources.list.d/* ; do
            sed -i '/cryptopro/d' "${_source}"
        done
        [ -s /etc/apt/sources.list.d/cprocsp.list ] || rm -f /etc/apt/sources.list.d/cprocsp.list
        apt-key del "$(apt-key list | grep -B 1 CryptoPro | head -1)"
        apt-get update
        add_repository
        return
    fi
    if [ "$(sh ./uninstall.sh --list | wc -w)" -eq 0 ] ; then
        select_packages${SUITE}
    else
        choose_activity${FROM_REPO_FUNC}
    fi
}

ask_password() {
    password="$(
        whiptail --title "$TITLE" \
            --passwordbox "Enter your password:" \
            --ok-button "$BUTTON_enter_serial" --cancel-button "$BUTTON_cancel" \
            "${HEIGHT}" "${WIDTH}" \
            3>&1 1>&2 2>&3
    )"
    if [ "$?" -ne "${SUCCESS}" ] ; then
        add_repository
        return
    fi
    wget -q -O - https://www.cryptopro.ru/sites/default/files/products/csp/cryptopro_key.pub | apt-key add -
    echo "deb https://${username}:${password}@cryptopro.ru/repo/deb 5.0-unstable main" > /etc/apt/sources.list.d/cprocsp.list
    apt-get update
    add_repo_status="$?"
    [ "${add_repo_status}" -eq "${SUCCESS}" ] && add_repo_notification="CryptoPro repository has been added" || add_repo_notification="Failed to add CryptoPro repository. Check your username and password"
    add_repo_notification
}

ask_username() {
    username="$(
        whiptail --title "$TITLE" \
            --inputbox "Enter your username:" \
            --ok-button "$BUTTON_enter_serial" --cancel-button "$BUTTON_cancel" \
            "${HEIGHT}" "${WIDTH}" \
            3>&1 1>&2 2>&3
    )"
    if [ "$?" -ne "${SUCCESS}" ] ; then
        add_repository
        return
    fi
    ask_password
}

add_repository() {
    whiptail --title "$TITLE" \
        --yesno "You have chosen the installation from a repository which have not been added yet.

Would you like to add the repository now?" \
        --yes-button "$BUTTON_add" --no-button "$BUTTON_exit" \
        "${HEIGHT}" "${WIDTH}" 
    if [ "$?" -ne "${SUCCESS}" ] ; then
        exit "${SUCCESS}"
    fi
    ask_username
}

main_menu() {
    whiptail --title "$TITLE" \
        --yesno "$TEXT_main_menu" \
        --yes-button "$BUTTON_next" --no-button "$BUTTON_exit" \
        "${HEIGHT}" "${WIDTH}" 
    if [ "$?" -ne "${SUCCESS}" ] ; then
        exit "${SUCCESS}"
    fi
    if [ "${FROM_REPO_OPT}" = "--from-repo" ] ; then
        if ! grep cryptopro /etc/apt/sources.list > /dev/null 2>&1 &&
            ! grep -r cryptopro /etc/apt/sources.list.d/ > /dev/null 2>&1
        then
            add_repository
            return
        fi
    fi
    if [ "$(sh ./uninstall.sh --list | wc -w)" -eq 0 ] ; then
        select_packages${SUITE}
    else
        choose_activity${FROM_REPO_FUNC}
    fi
}

main() {
    localize
    if [ "$(id -u)" -ne 0 ] ; then
        echo "$ERROR_root"
        exit "${FAILURE}"
    fi
    cd "$(dirname "$0")" || exit "$?"
    test_whiptail_and_scripts
    case "$(uname -m)" in
        "x86_64"|"amd64")
            ARCH="amd64"
            ;;
        "i386"|"i486"|"i586"|"i686")
            ARCH="ia32"
            ;;
        "ppc64"|"ppc64le")
            ARCH="$(uname -m)"
            ;;
        arm*)
            ARCH="arm"
            ;;
        aarch64)
            ARCH="aarch64"
            ;;
        e2k)
            ARCH="e2k64"
            ;;
        "mips")
            ARCH="mipsel"
            ;;
        *)
            echo "Error: unsupported platform:" $(uname -m)
            exit "${FAILURE}"
            ;;
    esac
    case "$(uname -m)" in
        "x86_64"|"amd64"|"i386"|"i486"|"i586"|"i686"|arm*|aarch64|e2k)
            SUITE="_rich"
            ;;
        *)
            SUITE=""
            ;;
    esac
    if [ "$1" = "--from-repo" ] ; then
        FROM_REPO_OPT="--from-repo"
        FROM_REPO_FUNC="_from_repo"
    else
        FROM_REPO_OPT=""
        FROM_REPO_FUNC=""
    fi
    main_menu
}

main "$@"
