#!/bin/bash

# Mithril - start.sh
# Container entrypoint script
# DNS-based adult content filter

if [ ! -x /bin/sh ]; then
    echo "Executable test for /bin/sh failed. Your Docker version is too old to run Alpine 3.14+ and Mithril. You must upgrade Docker.";
    exit 1;
fi

if [ "${PH_VERBOSE:-0}" -gt 0 ]; then
    set -x
fi

trap stop TERM INT QUIT HUP ERR

CAPSH_PID=""
TRAP_TRIGGERED=0

start() {
    echo ""
    echo "  ┌──────────────────────────────────────────────────────────────┐"
    echo "  │                                                              │"
    echo "  │   ⚔️  MITHRIL - Adult Content DNS Filter                     │"
    echo "  │                                                              │"
    echo "  │   Protecting your network with DNS-based content filtering   │"
    echo "  │                                                              │"
    echo "  └──────────────────────────────────────────────────────────────┘"
    echo ""

    # The below functions are all contained in bash_functions.sh
    # shellcheck source=/dev/null
    . /usr/bin/bash_functions.sh

    # If the file /etc/pihole/setupVars.conf exists, but /etc/pihole/pihole.toml does not, then we are migrating v5->v6
    if [[ -f /etc/pihole/setupVars.conf && ! -f /etc/pihole/pihole.toml ]]; then
        echo "  [i] v5 files detected that have not yet been migrated to v6"
        echo ""
        migrate_v5_configs
    fi

    # ===========================
    # Initial checks
    # ===========================

    # If PIHOLE_UID is set, modify the pihole user's id to match
    set_uid_gid

    # Configure FTL with any environment variables if needed
    echo "  [i] Starting FTL configuration"
    ftl_config

    # Install additional packages inside the container if requested
    install_additional_packages

    # Start crond for scheduled scripts (logrotate, pihole flush, gravity update etc)
    start_cron

    # Install the logrotate config file
    install_logrotate

    # Migrate Gravity Database if needed
    migrate_gravity

    echo "  [i] pihole-FTL pre-start checks"
    # Run the post stop script to cleanup any remaining artifacts from a previous run
    sh /opt/pihole/pihole-FTL-poststop.sh

    fix_capabilities
    sh /opt/pihole/pihole-FTL-prestart.sh

    # Get the FTL log file path from the config
    FTLlogFile=$(getFTLConfigValue files.log.ftl)

    # Get the EOF position of the FTL log file so that we can tail from there later.
    local startFrom
    startFrom=$(stat -c%s "${FTLlogFile}")

    echo "  [i] Starting pihole-FTL ($FTL_CMD) as ${DNSMASQ_USER}"
    echo ""

    capsh --user="${DNSMASQ_USER}" --keep=1 -- -c "/usr/bin/pihole-FTL $FTL_CMD >/dev/null" &

    # We need the PID of the capsh process so that we can wait for it to finish
    CAPSH_PID=$!

    # Wait for FTL to start by monitoring the FTL log file for the "FTL started" line
    if ! timeout 30 tail -F -c +$((startFrom + 1)) -- "${FTLlogFile}" | grep -q '########## FTL started'; then
        echo "  [!] ERROR: Did not find 'FTL started' message in ${FTLlogFile} in 30 seconds, stopping container"
        exit 1
    fi

    pihole updatechecker
    local versionsOutput
    versionsOutput=$(pihole -v)
    echo "  [i] Version info:"
    printf "%b" "${versionsOutput}\\n" | sed 's/^/      /'
    echo ""

    echo "  ┌──────────────────────────────────────────────────────────────┐"
    echo "  │  ⚔️  Mithril is now running!                                 │"
    echo "  │                                                              │"
    echo "  │  Web Interface: http://pi.hole/admin                         │"
    echo "  │  DNS Server:    $(hostname -i | awk '{print $1}'):53                               │"
    echo "  └──────────────────────────────────────────────────────────────┘"
    echo ""

    if [ "${TAIL_FTL_LOG:-1}" -eq 1 ]; then
        # Start tailing the FTL log file from the EOF position we recorded on container start
        tail -F -c +$((startFrom + 1)) -- "${FTLlogFile}" &
    else
        echo "  [i] FTL log not being tailed, set TAIL_FTL_LOG=1 to enable"
        echo ""
    fi

    # Wait for the FTL process to finish
    wait $CAPSH_PID
}

stop() {
    if [ $TRAP_TRIGGERED -eq 1 ]; then
        echo "  [i] Stop already triggered, waiting..."
        return
    fi
    TRAP_TRIGGERED=1

    echo ""
    echo "  [i] Caught signal, stopping Mithril..."

    if [ -n "$CAPSH_PID" ]; then
        # Send SIGTERM to the capsh process
        kill -TERM "$CAPSH_PID" 2>/dev/null

        # Wait for FTL to exit gracefully (up to 30 seconds)
        local count=0
        while kill -0 "$CAPSH_PID" 2>/dev/null && [ $count -lt 30 ]; do
            sleep 1
            ((count++))
        done

        if kill -0 "$CAPSH_PID" 2>/dev/null; then
            echo "  [i] FTL did not exit gracefully, sending SIGKILL"
            kill -KILL "$CAPSH_PID" 2>/dev/null
        fi
    fi

    # Run the post stop script
    sh /opt/pihole/pihole-FTL-poststop.sh

    echo "  [i] Mithril stopped"
    exit 0
}

start
