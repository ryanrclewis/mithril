#!/bin/bash

# Mithril - bash_functions.sh
# Helper functions for the Mithril DNS filter container
# Forked from pi-hole/docker-pi-hole with adult content blocking focus

#######################
# returns value from FTLs config file using pihole-FTL --config
#
# Takes one argument: key
# Example getFTLConfigValue dns.piholePTR
#######################
getFTLConfigValue() {
    pihole-FTL --config -q "${1}"
}

#######################
# sets value in FTLs config file using pihole-FTL --config
#
# Takes two arguments: key and value
# Example setFTLConfigValue dns.piholePTR PI.HOLE
#######################
setFTLConfigValue() {
    pihole-FTL --config "${1}" "${2}" >/dev/null
}

set_uid_gid() {
    echo "  [i] Checking user and group settings"
    
    currentUid=$(id -u pihole)
    currentGid=$(id -g pihole)
    
    if [ -n "${PIHOLE_UID}" ]; then
        if [[ ${currentUid} -ne ${PIHOLE_UID} ]]; then
            echo "  [i] Changing ID for user: pihole (${currentUid} => ${PIHOLE_UID})"
            usermod -o -u "${PIHOLE_UID}" pihole
        else
            echo "  [i] ID for user pihole is already ${PIHOLE_UID}, no need to change"
        fi
    else
        echo "  [i] PIHOLE_UID not set in environment, using default (${currentUid})"
    fi

    if [ -n "${PIHOLE_GID}" ]; then
        if [[ ${currentGid} -ne ${PIHOLE_GID} ]]; then
            echo "  [i] Changing ID for group: pihole (${currentGid} => ${PIHOLE_GID})"
            groupmod -o -g "${PIHOLE_GID}" pihole
        else
            echo "  [i] ID for group pihole is already ${PIHOLE_GID}, no need to change"
        fi
    else
        echo "  [i] PIHOLE_GID not set in environment, using default (${currentGid})"
    fi
    echo ""
}

install_additional_packages() {
    if [ -n "${ADDITIONAL_PACKAGES}" ]; then
        echo "  [i] Additional packages requested: ${ADDITIONAL_PACKAGES}"
        echo "  [i] Fetching APK repository metadata."
        if ! apk update; then
            echo "  [i] Failed to fetch APK repository metadata."
        else
            echo "  [i] Installing additional packages: ${ADDITIONAL_PACKAGES}."
            # shellcheck disable=SC2086
            if ! apk add --no-cache ${ADDITIONAL_PACKAGES}; then
                echo "  [i] Failed to install additional packages."
            fi
        fi
        echo ""
    fi
}

start_cron() {
    echo "  [i] Starting crond for scheduled scripts. Randomizing times for gravity and update checker"
    # Randomize gravity update time
    sed -i "s/59 1 /$((1 + RANDOM % 58)) $((3 + RANDOM % 2))/" /crontab.txt
    # Randomize update checker time
    sed -i "s/59 17/$((1 + RANDOM % 58)) $((12 + RANDOM % 8))/" /crontab.txt
    /usr/bin/crontab /crontab.txt

    /usr/sbin/crond
    echo ""
}

install_logrotate() {
    echo "  [i] Ensuring logrotate script exists in /etc/pihole"
    install -Dm644 -t /etc/pihole /etc/.pihole/advanced/Templates/logrotate
    echo ""
}

migrate_gravity() {
    echo "  [i] Gravity migration checks"
    gravityDBfile=$(getFTLConfigValue files.gravity)

    # MITHRIL MODIFICATION: Use adult content blocklists instead of ad blocklists
    if [[ ! -f /etc/pihole/adlists.list ]]; then
        echo "  [i] No adlist file found, creating one with Mithril adult content blocklists"
        cat > /etc/pihole/adlists.list << 'EOF'
# ===================================
# MITHRIL - Adult Content Blocklists
# ===================================
# These lists block adult/NSFW content to keep your network safe

# StevenBlack's Unified Hosts with Porn Extension (comprehensive)
https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts

# OISD NSFW Blocklist (well-maintained, frequently updated)
https://nsfw.oisd.nl/

# StevenBlack Porn-only extension
https://raw.githubusercontent.com/StevenBlack/hosts/master/extensions/porn/clefspeare13/hosts
https://raw.githubusercontent.com/StevenBlack/hosts/master/extensions/porn/sinfonietta/hosts
https://raw.githubusercontent.com/StevenBlack/hosts/master/extensions/porn/tiuxo/hosts

# Chad Mayfield's Porn blocklist (Top 1M sites)
https://raw.githubusercontent.com/chadmayfield/my-pihole-blocklists/master/lists/pi_blocklist_porn_top1m.list

# Sinfonietta's pornography blocklist
https://raw.githubusercontent.com/Sinfonietta/hostfiles/master/pornography-hosts

# BigDargon's hostsVN adult list
https://raw.githubusercontent.com/bigdargon/hostsVN/master/extensions/adult/hosts

# Energized Porn blocking
https://block.energized.pro/porn/formats/hosts.txt
EOF
    fi

    if [ ! -f "${gravityDBfile}" ]; then
        echo "  [i] ${gravityDBfile} does not exist (Likely due to a fresh volume). This is a required file for Mithril to operate."
        echo "  [i] Gravity will now be run to create the database with adult content blocklists"
        pihole -g
    else
        echo "  [i] Existing gravity database found - schema will be upgraded if necessary"
        source /etc/.pihole/advanced/Scripts/database_migration/gravity-db.sh
        local upgradeOutput
        upgradeOutput=$(upgrade_gravityDB "${gravityDBfile}" "/etc/pihole")
        printf "%b" "${upgradeOutput}\\n" | sed 's/^/     /'
    fi
    echo ""
}

ftl_config() {
    # Force a check of pihole-FTL --config
    getFTLConfigValue >/dev/null

    # If FTLCONF_files_macvendor is not set
    if [[ -z "${FTLCONF_files_macvendor:-}" ]]; then
        setFTLConfigValue "files.macvendor" "/macvendor.db"
        chown pihole:pihole /macvendor.db
    fi

    # If getFTLConfigValue "dns.upstreams" returns [], default to Cloudflare Family DNS
    # MITHRIL MODIFICATION: Use Cloudflare Family DNS (blocks malware & adult content)
    if [[ $(getFTLConfigValue "dns.upstreams") == "[]" ]]; then
        echo "  [i] No DNS upstream set, defaulting to Cloudflare Family DNS (1.1.1.3 - blocks malware & adult content)"
        setFTLConfigValue "dns.upstreams" "[\"1.1.1.3\", \"1.0.0.3\"]"
    fi

    setup_web_password
}

migrate_v5_configs() {
    echo "  [i] Migrating dnsmasq configuration files"
    
    V6_CONF_MIGRATION_DIR="/etc/pihole/migration_backup_v6"
    mkdir -p "${V6_CONF_MIGRATION_DIR}"
    chown pihole:pihole "${V6_CONF_MIGRATION_DIR}"

    mv /etc/dnsmasq.d/0{1,2,4,5}-pihole*.conf "${V6_CONF_MIGRATION_DIR}/" 2>/dev/null || true
    mv /etc/dnsmasq.d/06-rfc6761.conf "${V6_CONF_MIGRATION_DIR}/" 2>/dev/null || true
    echo ""

    local FTLoutput
    FTLoutput=$(pihole-FTL migrate v6)

    printf "%b" "${FTLoutput}\\n" | sed 's/^/      /' | sed 's/      Migrating config to Pi-hole v6.0 format/  [i] Migrating config to Pi-hole v6.0 format/' | sed 's/- 0 entries are forced through environment//'

    echo ""
}

setup_web_password() {
    if [ -z "${FTLCONF_webserver_api_password+x}" ] && [ -n "${WEBPASSWORD_FILE}" ] && [ -r "/run/secrets/${WEBPASSWORD_FILE}" ]; then
        echo "  [i] Setting FTLCONF_webserver_api_password from file"
        export FTLCONF_webserver_api_password=$(<"/run/secrets/${WEBPASSWORD_FILE}")
    fi

    if [ -z "${FTLCONF_webserver_api_password+x}" ]; then
        if [[ $(pihole-FTL --config webserver.api.pwhash) ]]; then
            echo "  [i] Password already set in config file"
            return
        else
            RANDOMPASSWORD=$(tr -dc _A-Z-a-z-0-9 </dev/urandom | head -c 8)
            echo "  [i] No password set in environment or config file, assigning random password: $RANDOMPASSWORD"

            { set +x; } 2>/dev/null

            pihole-FTL --config webserver.api.password "$RANDOMPASSWORD" >/dev/null

            if [ "${PH_VERBOSE:-0}" -gt 0 ]; then
                set -x
            fi
        fi
    else
        echo "  [i] Assigning password defined by Environment Variable"
    fi
}

fix_capabilities() {
    echo "  [i] Setting capabilities on pihole-FTL where possible"
    capsh --has-p=cap_chown 2>/dev/null && CAP_STR+=',CAP_CHOWN'
    capsh --has-p=cap_net_bind_service 2>/dev/null && CAP_STR+=',CAP_NET_BIND_SERVICE'
    capsh --has-p=cap_net_raw 2>/dev/null && CAP_STR+=',CAP_NET_RAW'
    capsh --has-p=cap_net_admin 2>/dev/null && CAP_STR+=',CAP_NET_ADMIN' || DHCP_READY='false'
    capsh --has-p=cap_sys_nice 2>/dev/null && CAP_STR+=',CAP_SYS_NICE'
    capsh --has-p=cap_sys_time 2>/dev/null && CAP_STR+=',CAP_SYS_TIME'

    if [[ ${CAP_STR} ]]; then
        echo "  [i] Applying the following caps to pihole-FTL:"
        IFS=',' read -ra CAPS <<<"${CAP_STR:1}"
        for i in "${CAPS[@]}"; do
            echo "        * ${i}"
        done

        setcap "${CAP_STR:1}"+ep "$(which pihole-FTL)" || ret=$?

        if [[ $DHCP_READY == false ]] && [[ $FTLCONF_dhcp_active == true ]]; then
            echo "ERROR: DHCP requested but NET_ADMIN is not available. DHCP will not be started."
            echo "      Please add cap_net_admin to the container's capabilities or disable DHCP."
            setFTLConfigValue dhcp.active false
        fi

        if [[ $ret -ne 0 && "${DNSMASQ_USER:-pihole}" != "root" ]]; then
            echo "  [!] ERROR: Unable to set capabilities for pihole-FTL. Cannot run as non-root."
            echo "            If you are seeing this error, please set the environment variable 'DNSMASQ_USER' to the value 'root'"
            exit 1
        fi
    else
        echo "  [!] ERROR: Unable to set capabilities for pihole-FTL."
        echo "            Please ensure that the container has the required capabilities."
        exit 1
    fi
    echo ""
}
