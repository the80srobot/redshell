# # SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# This file provides functions to monitor system stats and write them to a log.

if [[ -z "${_REDSHELL_MONITOR}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_MONITOR=1

function __load_stats_worker() {
    local d="$2"
    case "$1" in
        proc_stats)
            while true; do
                proc_stats
                sleep "$d"
            done
        ;;
        net_stats)
            stream_net_stats "$d"
        ;;
        top_stats)
            stream_top_stats "$d"
        ;;
        tick)
            __stream_tick "$d"
        ;;
    esac
}

function __stream_tick() {
    while true; do
        echo -e "TICK\t$(date +%s)\t$1"
        sleep "$1"
    done
}

function stream_load_stats() {
    local d="$1"
    [[ -z "$d" ]] && d=1
    export -f proc_stats stream_top_stats stream_net_stats __stream_tick
    export -f __parse_top_header __parse_nettop __load_stats_worker __parse_units __stream_net_stats_worker
    {
        echo "proc_stats"
        echo "net_stats"
        echo "top_stats"
        echo "tick"
    } | xargs -J{} -P4 -n1 bash -c '__load_stats_worker "${@}"' _ {} "$d"
}

export STATS_LOG_DIR="${HOME}/.logs"
export STATS_LOG_FILE="${STATS_LOG_DIR}/load_stats.log"

function __write_load_stats_worker() {
    local d="$1"
    local task="$2"
    local rotate_interval
    (( rotate_interval = 10 * d ))

    case "${task}" in
        stream)
            mkdir -p "${STATS_LOG_DIR}"
            stream_load_stats "$d" >> "${STATS_LOG_FILE}"
        ;;
        rotate)
            while true; do
                sleep "${rotate_interval}"
                rm -f "${STATS_LOG_FILE}.2" || true
                2> /dev/null mv "${STATS_LOG_FILE}.1" "${STATS_LOG_FILE}.2" || true
                cp "${STATS_LOG_FILE}" "${STATS_LOG_FILE}.1"
                : > "${STATS_LOG_FILE}"
            done
        ;;
    esac
}

function load_hist() {
    local chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
    cat ${STATS_LOG_FILE}.2 ${STATS_LOG_FILE}.1 ${STATS_LOG_FILE}
}

function latest_load_stats() {
    local ps ns ts t
    while IFS= read line; do
        IFS=$'\t' read -r -a cols <<< "${line}"
        
        case "${cols[0]}" in
            TICK)
                t="${line}"
            ;;
            PROC_STATS)
                ps="${line}"
            ;;
            NET_STATS)
                ns="${line}"
            ;;
            TOP_STATS)
                ts="${line}"
            ;;
            *)
                2> echo "BAD LINE PREAMBLE ${cols[0]}"
            ;;
        esac
    done <<< "$(cat ${STATS_LOG_FILE}.1 ${STATS_LOG_FILE})"

    {
        [[ -z "${t}" ]] || \
            echo "${t}" && \
            echo "${ps}" && \
            echo "${ns}" && \
            echo "${ts}"
    } | __parse_load_stats "${@}"
}

function __parse_load_stats() {
    local line
    local cols

    local tick
    local cores=`nproc`
    
    local cores_util
    local phys_util
    local rss
    local highest_cpu
    local highest_cpu_pid
    local highest_cpu_comm
    local highest_rss
    local highest_rss_pid
    local highest_rss_comm

    local highest_net_in_bytes
    local highest_net_out_bytes
    local highest_net_comm
    local highest_net_pid

    local proc_count
    local awake_count
    local thread_count
    local avg1 avg5 avg15
    local cpu_user
    local cpu_sys
    local bytes_in packets_in
    local bytes_out packets_out
    local reads read_bytes
    local writes written_bytes

    while IFS= read line; do
        IFS=$'\t' read -r -a cols <<< "${line}"

        case "${cols[0]}" in
            TICK)
                tick="${cols[1]}"
            ;;
            PROC_STATS)
                cores_util="${cols[1]}"
                phys_util="${cols[2]}"
                rss="${cols[3]}"
                highest_cpu="${cols[8]}"
                highest_cpu_pid="${cols[6]}"
                highest_cpu_comm="${cols[7]}"
                highest_rss="${cols[11]}"
                highest_rss_pid="${cols[9]}"
                highest_rss_comm="${cols[10]}"
            ;;
            NET_STATS)
                highest_net_in_bytes="${cols[6]}"
                highest_net_out_bytes="${cols[7]}"
                highest_net_comm="${cols[4]}"
                highest_net_pid="${cols[5]}"
            ;;
            TOP_STATS)
                proc_count="${cols[1]}"
                awake_count="${cols[2]}"
                thread_count="${cols[3]}"
                avg1="${cols[4]}"
                avg5="${cols[5]}"
                avg15="${cols[6]}"
                cpu_user="${cols[7]}"
                cpu_sys="${cols[8]}"
                packets_in="${cols[9]}"
                bytes_in="${cols[10]}"
                packets_out="${cols[11]}"
                bytes_out="${cols[12]}"
                reads="${cols[13]}"
                read_bytes="${cols[14]}"
                writes="${cols[15]}"
                written_bytes="${cols[16]}"
            ;;
        esac
    done

    local now=`date +%s`
    if (( now - tick > 5 )); then
        # echo "(load stats $(( now - tick )) s stale)"
        return 1
    fi

    local phys_mem highest_mem
    ((phys_mem = rss * 1024))
    ((highest_mem = highest_rss * 1024))

    local args="${@}"
    if [[ "$#" == 0 ]]; then
        args=(--color)
        if awk "BEGIN{exit ${avg1} < ${cores}*0.8}"; then
            args+=("LOAD" load)
        fi

        if awk "BEGIN{exit ${cpu_user} + ${cpu_sys} < 20}"; then
            args+=("CPU" cpu)
        fi

        if [[ "${args[${#args[@]}-1]}" == "load" || "${args[${#args[@]}-1]}" == "cpu" ]]; then
            args+=(topcpu)
        fi
        
        if awk "BEGIN{exit ${phys_util} < 70}"; then
            args+=("MEM" mem topmem)
        fi

        if (( bytes_in > 1024 || bytes_out > 1024 )); then
            args+=("NET" net topnet)
        fi
        
    fi

    [[ "$1" == "all" ]] && args=(--color P procs L load C cpu topcpu M mem topmem N net topnet I io)

    local color=""
    local bold=""
    local norm=""
    local rst=""
    for arg in "${args[@]}"; do
        case "${arg}" in
            --color)
                color="color"
                bold="$(tput smso)"
                norm="$(tput rmso)"
                rst="$(tput sgr0)"
                continue
            ;;
            procs)
                [[ "${color}" ]] && tput setaf 4
                printf "%d P %d A %d T" "${proc_count}" "${awake_count}" "${thread_count}"
            ;;
            load)
                [[ "${color}" ]] && tput setaf 5
                printf "%s %s %s" "${avg1}" "${avg5}" "${avg15}"
            ;;
            cpu)
                [[ "${color}" ]] && tput setaf 6
                printf "%s%% U %s%% S" "${cpu_user}" "${cpu_sys}"
            ;;
            mem)
                [[ "${color}" ]] && tput setaf 3
                printf "%s%% %s" "${phys_util}" "$(human_size -hh "${phys_mem}")"
            ;;
            net)
                [[ "${color}" ]] && tput setaf 2
                printf "%d/%s D %d/%s U" \
                    "${packets_in}" "$(human_size -bb "${bytes_in}")" "${packets_out}" "$(human_size -bb "${bytes_out}")"
            ;;
            io)
                [[ "${color}" ]] && tput setaf 1
                printf "%d/%s R %d/%s W" \
                    "${reads}" "$(human_size -hh "${read_bytes}")" "${writes}" "$(human_size -hh "${written_bytes}")"
            ;;
            topcpu)
                [[ "${color}" ]] && tput setaf 6
                printf "${bold}%s.%d${norm} %s%%" \
                    "${highest_cpu_comm}" "${highest_cpu_pid}" "${highest_cpu}"
            ;;
            topmem)
                [[ "${color}" ]] && tput setaf 3
                printf "${bold}%s.%d${norm} %s" \
                    "${highest_rss_comm}" "${highest_rss_pid}" "$(human_size -hh "${highest_mem}")"
            ;;
            topnet)
                [[ "${color}" ]] && tput setaf 2
                printf "${bold}%s.%d${norm} %s D %s U" \
                    "${highest_net_comm}" "${highest_net_pid}" \
                    "$(human_size -bb "${highest_net_in_bytes}")" \
                    "$(human_size -bb "${highest_net_out_bytes}")"
            ;;
            *)
                echo -n "${arg}"
        esac
        echo -ne "${rst} "
    done
    echo -ne "${rst}"
    echo
}

function write_load_stats() {
    local d="$1"
    [[ -z "$d" ]] && d=1

    export -f proc_stats stream_top_stats stream_net_stats __stream_tick
    export -f __parse_top_header __parse_nettop __load_stats_worker __parse_units __stream_net_stats_worker
    export -f __write_load_stats_worker stream_load_stats
    {
        echo "stream"
        echo "rotate"
    } | xargs -J{} -P2 -n1 bash -c '__write_load_stats_worker "${@}"' _ "$d" {}
}

function stream_top_stats {
    local d="$1"
    [[ -z "$d" ]] && d=1
    top -d -o cpu -l0 -n0 -s "$d" | while true; do
        __parse_top_header
    done
}

# Outputs:
# 1. Process count
# 2. Of which awake
# 3. Thread count
# 4. Load avg 1 minute
# 5. Load avg 5 minutes
# 6. Load avg 15 minutes
# 7. CPU util in user
# 8. CPU util in kernel
# 9. Packets in
# 10. Data in
# 11. Packets out
# 12. Data out
# 13. Reads
# 14. Data read
# 15. Writes
# 16. Data written
function __parse_top_header {
    local line cols

    local nproc nproc_awake
    local nthread
    local load1 load5 load15
    local ucpu scpu
    local packets_in packets_out bytes_in bytes_out unit_in unit_out
    local reads bytes_read units_read
    local writes bytes_written units_written

    # Seek to the start of top output.
    while IFS= read line; do
        grep -qE "^Processes:" <<< "${line}" && break;
    done

    # Process counts
    IFS=$'\t' read -r -a cols <<< "$(perl -pe 's/^Processes:.*?(\d+) total.*?(\d+) running.*?(\d+) threads.*/$1\t$2\t$3/' <<< "${line}")" 
    nproc="${cols[0]}"
    nproc_awake="${cols[1]}"
    nthread="${cols[2]}"

    # Skip - just the date
    IFS= read line

    # Load averages
    IFS= read line
    IFS=$'\t' read -r -a cols <<< "$(perl -pe 's/^Load Avg:.*?(\d+\.\d+).*?(\d+\.\d+).*?(\d+\.\d+).*/$1\t$2\t$3/' <<< "${line}")" 
    load1="${cols[0]}"
    load5="${cols[1]}"
    load15="${cols[2]}"

    # CPU usage
    IFS= read line
    IFS=$'\t' read -r -a cols <<< "$(perl -pe 's/^CPU usage:.*?(\d+\.\d+)%.*?(\d+\.\d+)%.*/$1\t$2/' <<< "${line}")" 
    ucpu="${cols[0]}"
    scpu="${cols[1]}"

    # Skip shared libs
    IFS= read line
    # Skip mem regions
    IFS= read line
    # Skip physical memory
    IFS= read line
    # Skip VM
    IFS= read line

    # Network
    IFS= read line
    IFS=$'\t' read -r -a cols <<< "$(perl -pe 's/^Networks:.*?(\d+)\/(\d+)(\w).*?(\d+)\/(\d+)(\w).*$/$1\t$2\t$3\t$4\t$5\t$6/' <<< "${line}")"
    packets_in="${cols[0]}"
    bytes_in="${cols[1]}"
    units_in="${cols[2]}"
    packets_out="${cols[3]}"
    bytes_out="${cols[4]}"
    units_out="${cols[5]}"

    # Disk
    IFS= read line
    IFS=$'\t' read -r -a cols <<< "$(perl -pe 's/^Disks:\s*(\d+)\/(\d+)(\w).*?(\d+)\/(\d+)(\w).*$/$1\t$2\t$3\t$4\t$5\t$6/' <<< "${line}")"
    reads="${cols[0]}"
    bytes_read="${cols[1]}"
    units_read="${cols[2]}"
    writes="${cols[3]}"
    bytes_written="${cols[4]}"
    units_written="${cols[5]}"

    printf "TOP_STATS\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n" \
        "${nproc}" \
        "${nproc_awake}" \
        "${nthread}" \
        "${load1}" \
        "${load5}" \
        "${load15}" \
        "${ucpu}" \
        "${scpu}" \
        "${packets_in}" \
        "$(__parse_units "${bytes_in}" "${units_in}")" \
        "${packets_out}" \
        "$(__parse_units "${bytes_out}" "${units_out}")" \
        "${reads}" \
        "$(__parse_units "${bytes_read}" "${units_read}")" \
        "${writes}" \
        "$(__parse_units "${bytes_written}" "${units_written}")"
}

function __parse_units() {
    local n="$1"
    local u="$2"

    case "$u" in
        B)
        ;;
        K)
            (( n *= 1024 ))
        ;;
        M)
            (( n *= 1024 * 1024 ))
        ;;
        G)
            (( n *= 1024 * 1024 * 1024 ))
        ;;
        *)
            return 1
        ;;
    esac
    echo "${n}"
}

function __stream_net_stats_worker() {
    local task="$1"
    local fifo="$2"
    local interval="$3"
    case "${task}" in
        nettop)
            >&2 echo "Streaming nettop to ${fifo} every ${interval} seconds"
            script -q /dev/null nettop -xdP -L0 -s"${interval}" > "${fifo}"
        ;;
        parser)
            cat "${fifo}" | {
                # Skip the first header - we use the N+1 header to stop awk on body N.
                IFS= read line
                __parse_nettop
            }
        ;;
        *)
            return 1
        ;;
    esac
}

# Outputs:
# 1. Delta bytes in
# 2. Delta bytes out
# 3. In/out delta
# 4. Comm with the highest in/out delta
# 5. PID with the highest in/out delta
# 6. Delta bytes in of the proc with the highest in/out delta
# 7. Delta bytes out of the proc  with the highest in/out delta
# 8. In/out delta of the proc with the highest in/out delta
function __parse_nettop() {
    awk 'BEGIN { FS = ","; }
    {
        if ($1 == "time") {
            match(maxproc, /\.[0-9]+$/);
            print "NET_STATS\t" \
                i "\t" \
                o "\t" \
                i + o "\t" \
                substr(maxproc, 1, RSTART-1) "\t" \
                substr(maxproc, RSTART+1, RLENGTH) "\t" \
                maxi "\t" \
                maxo "\t" \
                max;
            fflush("/dev/stdout");
            i = 0;
            o = 0;
            total = 0;
            lno = 0;
            max = 0;
        }

        lno++;
        i += $5;
        o += $6;
        
        if ($5+$6 > max) {
            max = $5+$6;
            maxi = $5;
            maxo = $6;
            maxproc = $2;
        }
    }'
}

function stream_net_stats() {
    local d="$1"
    [[ -z "$d" ]] && d=1
    # This construction forces nettop's stdout to be unbuffered. This wouldn't
    # be necessary if nettop wasn't fucking stupid, or if macOS were a real
    # operating system, but nettop is fucking stupid and macOS is not a real
    # operating system, so here we bloody are.
    local fifo
    fifo=$(mktemp -d) || return 1
    mkfifo "${fifo}/pipe" || return 2
    # >&2 echo "Using named FIFO at ${fifo}/pipe"

    export -f __stream_net_stats_worker __parse_nettop
    echo -e "nettop\nparser" | \
        xargs -o -J{} -P2 -n1 bash -c '__stream_net_stats_worker "${@}"' _ {} "${fifo}/pipe" "$d"

    >&2 echo "Done"
    rm -f "${fifo}/pipe"
}

# Outputs:
# 1. CPU util
# 2. Physical RAM util
# 3. Total RSS
# 4. User time total
# 5. System time total
# 6. PID with the highest CPU util
# 7. Comm with the highest CPU util
# 8. CPU util of the proc with the highest CPU util
# 9. PID with the highest RSS
# 10. Comm with the highest RSS
# 11. RSS of the proc with the highest RSS
function proc_stats() {
    ps -A -o 'pid %cpu %mem rss utime stime ucomm' | tail -n+2 \
    | awk '{
        cpu += $2;
        mem += $3;
        rss += $4;

        split($5, a, "[:.]")
        utime += a[1] * 60 * 100
        utime += a[2] * 100
        utime += a[3]

        split($6, a, "[:.]")
        stime += a[1] * 60 * 100
        stime += a[2] * 100
        stime += a[3]

        if ( maxcpu < $2 ) {
            maxcpu = $2;
            maxcpupid = $1;
            maxcpucomm = $7;
        }

        if ( maxrss < $4 ) {
            maxrss = $4;
            maxrsspid = $1;
            maxrsscomm = $7;
        }
    }

    END {
        print "PROC_STATS\t" \
            cpu "\t" \
            mem "\t" \
            rss "\t" \
            utime "\t" \
            stime "\t" \
            maxcpupid "\t" \
            maxcpucomm "\t" \
            maxcpu "\t" \
            maxrsspid "\t" \
            maxrsscomm "\t" \
            maxrss "\t"
    }'
}

fi # _REDSHELL_MONITOR
