#!/bin/bash

_php_versions=(
    '5.6' '7.0' '7.1' '7.2'
)

_php_exts=(
    'bcmath' 'bz2' 'cli' 'common' 'curl' 'dba' 'fpm' 'gd' 'imap'
    'interbase' 'intl' 'json' 'ldap' 'mbstring'
    'mcrypt'
    'mysql' 'opcache' 'pgsql'
    'readline' 'soap' 'sqlite3' 'xml' 'xmlrpc' 'xsl' 'zip'
)

_php_ext_shared=(
    'redis' 'imagick' 'geoip'
)

args=("$@")

# Messages

export NC='\033[0m' # No Color
export COLOR_WHITE='\033[1;37m'
export COLOR_BLUE='\033[0;34m'
export COLOR_GREEN='\033[0;32m'
export COLOR_RED='\033[0;31m'

export STYLE_BOLD=$(tput bold)
export STYLE_NORMAL=$(tput sgr0)

indent() {
    printf '%*s' $@
}

echoe() {
    echo -e $@
}

echo_li ()
{
    indent 2 && echoe " - $@"
}

msg_error()
{
    local msg=${1:-An Error Occured.}

    msg=${msg}

    echoe ""

    indent 1 && \
    echoe "${STYLE_BOLD}${COLOR_RED}ERROR: ${COLOR_WHITE}${msg}${NC}" >&2
}

msg_info()
{
    local msg=${1:-Info}

    msg=${msg}

    echoe ""
    indent 1 && \
    echoe "${STYLE_BOLD}${COLOR_BLUE}  ✔ ${COLOR_WHITE}${msg}${NC}" >&2
}


php-switch-add-repo () {

    if find /etc/apt/ -name *.list | xargs cat | grep ondrej/php | grep -q .
    then
        echo "- Repo already ppa:ondrej/php installed"
    else
        echo "- Updating repos ..."
        sudo apt-get update > /dev/null

        echo "- Installing Repo ppa:ondrej/php ..."
        sudo apt-get install -y software-properties-common > /dev/null
        sudo add-apt-repository -y ppa:ondrej/php > /dev/null

        echo "- Updating repos ..."
        sudo apt-get update
    fi
}

php-switch-repo-pkg () {

    local repo='/var/lib/apt/lists/ppa.launchpad.net_ondrej_php_ubuntu_dists_xenial_main_binary-i386_Packages'
    local php_ver=${args[1]}

    case ${php_ver} in
        5.6|7.0|7.1|7.2)
            msg_info "Available Packages for ${php_ver}: \n"

            grep "Package: php${php_ver}-" "${repo}" | sed -n "s/Package:/  /p"
            echo ""
        ;;

        all)
            echo "Uninstalling All PHP Versions"

            for i in ${_php_versions[*]}; do
                php-switch-repo-pkg "${i}"
            done

            php-switch-repo-pkg "shared"
        ;;
        shared)
            msg_info "Available Shared Packages: "

            grep "Package: php-" "${repo}" | sed -n "s/Package:/ /p"
            echo ""

        ;;
        *)
            msg_error "Unknown PHP Version"
        ;;
    esac
}

php-switch-info () {
    php-switch-ver

    msg_info "Avaialble PHP Versions :"
    for i in ${_php_versions[*]}; do
        echo_li "$i"
    done

    echo -e ""

    msg_info "Avaialble Extentions :"
    for i in ${_php_exts[*]}; do
        echo_li "$i"
    done

    echo -e ""
}

php-switch-uninstall () {
    echo ""
    local php_ver=${args[1]}

    case ${php_ver} in
        5.6|7.0|7.1|7.2)
            msg_info "Uninstalling PHP " ${php_ver} "\n"
            echo ""

            sudo apt-get remove -y php${php_ver}-*
            sudo apt-get purge -y php${php_ver}-*
            sudo apt-get remove -y libapache2-mod-php${php_ver}
            sudo apt-get purge -y libapache2-mod-php${php_ver}
        ;;

        all)
            msg_info "Uninstalling All PHP Versions"

            for i in ${_php_versions[*]}; do
                php-switch-uninstall "${i}"
            done
        ;;
        *)
            msg_error "Unknown PHP Version"
        ;;
    esac
}

php-switch-install () {
    echo ""
    local php_ver=${args[1]}
    local pkgs

    case ${php_ver} in
        5.6|7.0|7.1|7.2)
            msg_info "Installing PHP " ${php_ver}
            echo ""

            pkgs=$(printf  "php${php_ver}-%s " "${_php_exts[@]}")

            if [[ "7.2" == "${php_ver}" ]]; then
                msg_info "Skip mcrypt ...."
                pkgs=`echo -e ${pkgs} | sed -n "s/php${php_ver}-mcrypt//p"`
            fi

            sudo apt-get install -y --ignore-missing ${pkgs}

            sudo apt install libapache2-mod-php${php_ver}

            echo ""
            # msg_info "Installing Shared PHP Extensions"

            # for i in ${_php_ext_shared[*]}; do
            #     php-switch-install ext "${i}"
            # done
        ;;
        all)
            msg_info "Installing All PHP Versions"

            for i in ${_php_versions[*]}; do
                php-switch-install "${i}"
            done
        ;;
        ext)
            msg_info "Installing PHP Ext ${args[1]}..."

            sudo apt-get install -y --ignore-missing "php-${args[1]}"
        ;;
        *)
            msg_error "Unknown PHP Version"

        ;;
    esac

}

php-switch-ver () {
    local VERSION
    VERSION="$(php --version | head -n 1 | cut -d " " -f 2 | cut -c 1,3)"

    printf "\n"

    msg_info "$COLOR_GREEN PHP Version $NC ${VERSION}"
    echo ""
}


php-switch-to () {

    local php_ver=${args[1]}

    if [[ $@ ]]; then

        if [[ ! -f "/usr/bin/php${php_ver}" ]]; then
            msg_error "PHP ${php_ver} Not installed \n ${NC}"
            echo_li "Use php-switch-install ${php_ver}"
            return
        fi

        msg_info  "Switching to PHP Version $php_ver ... \n"

        if [[ $(sudo service --status-all | grep "apache2") ]]; then
            msg_info "Disabling Apache Modules ..."

            for i in ${_php_versions[*]}; do
                if [[ -f "/usr/bin/php${i}" ]]; then
                    msg_info "Disabling Apache Module php${i}"
                    sudo a2dismod php${i} > /dev/null
                fi
            done

            echo ""
            msg_info "Enabling  Apache Module php${php_ver}"
            sudo a2enmod php${php_ver} > /dev/null

            echo ""
            msg_info "Restarting Apache ..."
            sudo service apache2 restart

        else
            echo ""
            msg_info "Apache Missing : Skip \n"
        fi

        if [[ $(sudo service --status-all | grep "php") ]]; then
            echo ""
            msg_info "Disabling PHP-FPM Services ..."

            for i in ${_php_versions[*]}; do
                if [[ -f "/usr/bin/php${i}" ]]; then
                    msg_info "Disabling PHP FPM php${i}"
                    # sudo service php${i}-fpm stop
                    sudo systemctl stop php${i}-fpm.service --no-pager
                    sudo systemctl disable php${i}-fpm.service --no-pager
                fi
            done

            echo ""
            msg_info "Enabling  PHP FPM ${php_ver} ..."
            # sudo service php${php_ver}-fpm start
            sudo systemctl enable php${i}-fpm.service --no-pager
            sudo systemctl start php${i}-fpm.service --no-pager
        fi

        msg_info "Updating PHP Cli ..."
        sudo update-alternatives --set php "/usr/bin/php${php_ver}" > /dev/null

        if [[ $(sudo update-alternatives --get-selections \
                | grep "phpize") ]]; then

            msg_info  "Updating PHPize ..."
            sudo update-alternatives \
                --set phpize "/usr/bin/phpize${php_ver}" > /dev/null
        fi

        if [[ $(sudo update-alternatives --get-selections \
                | grep "php-config") ]]; then

            msg_info "Updating PHP Config ... "
            sudo update-alternatives \
                --set php-config "/usr/bin/php-config${php_ver}" > /dev/null
        fi

        php-switch-ver
    else
        msg_error "No version specified"
    fi
}

php-switch-help() {
    echo ""
    indent 2
    echo "Usage: php-switch.sh [ver|info|install|uninstall|repo-pkg|add-repo]"
    echo ""
    indent 2
    echo "Example : php-switch.sh install 7.0"
    indent 2
    echo "Example : php-switch.sh to 7.0"
}

cmd=${args[0]}

if [ "$cmd" = "ver" ]; then
    php-switch-ver
elif [ "$cmd" = "repo-pkg" ]; then
    php-switch-repo-pkg
elif [ "$cmd" = "add-repo" ]; then
    php-switch-add-repo
elif [ "$cmd" = "info" ]; then
    php-switch-info
elif [ "$cmd" = "install" ]; then
    php-switch-install
elif [ "$cmd" = "uninstall" ]; then
    php-switch-uninstall
elif [ "$cmd" = "to" ]; then
    php-switch-to
else
    php-switch-help
    php-switch-info
fi
