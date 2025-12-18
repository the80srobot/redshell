# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# CalDAV calendar fetching utilities.
#
# Passwords are stored under CalDAV/Accounts/$account, URLs under CalDAV/URLs/$account.

if [[ -z "${_REDSHELL_CALDAV}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_CALDAV=1

# List configured CalDAV accounts.
#
# Usage: caldav_accounts
function caldav_accounts() {
    pass ls Redshell/CalDAV/Accounts 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep '\.var$' \
        | awk '{print $NF}' \
        | sed 's/\.var$//'
}

# Get default account if exactly one is configured.
function __caldav_default_account() {
    local accounts
    accounts="$(caldav_accounts)"
    local count
    count="$(echo "${accounts}" | grep -c .)"
    if [[ "${count}" -eq 1 ]]; then
        echo "${accounts}"
        return 0
    fi
    return 1
}

# Fetch a CalDAV calendar and output its contents.
#
# Usage: caldav_fetch [-a|--account ACCOUNT] [-u|--username USER] [URL]
#
# Options:
#   -a, --account ACCOUNT  Account name for password lookup via keys_var CalDAV/$account.
#                          If omitted and exactly one account exists, uses that.
#   -u, --username USER    Username for authentication. Defaults to account name.
#
# The password is retrieved from pass using: keys_var CalDAV/$account
# If URL is not provided, it is retrieved using: keys_var CalDAV/URLs/$account
#
# Example:
#   caldav_fetch -a fastmail -u user@fastmail.com https://caldav.fastmail.com/dav/calendars/user/...
#   caldav_fetch -a fastmail  # URL loaded from keys_var CalDAV/URLs/fastmail
function caldav_fetch() {
    local account=""
    local username=""
    local url=""

    while [[ "${#}" -ne 0 ]]; do
        case "${1}" in
            -a|--account)
                account="${2}"
                shift
                ;;
            -u|--username)
                username="${2}"
                shift
                ;;
            *)
                url="${1}"
                ;;
        esac
        shift
    done

    if [[ -z "${account}" ]]; then
        account="$(__caldav_default_account)" || {
            >&2 echo "Error: No account specified and multiple accounts exist"
            >&2 echo "Available accounts: $(caldav_accounts | tr '\n' ' ')"
            >&2 echo "Usage: caldav_fetch [-a|--account ACCOUNT] [-u|--username USER] [URL]"
            return 1
        }
    fi

    if [[ -z "${url}" ]]; then
        url="$(keys_var "CalDAV/URLs/${account}")" || {
            >&2 echo "Error: URL not provided and not found in CalDAV/URLs/${account}"
            >&2 echo "Usage: caldav_fetch [-a|--account ACCOUNT] [-u|--username USER] [URL]"
            >&2 echo "Set URL with: keys_var CalDAV/URLs/${account} YOUR_URL"
            return 1
        }
    fi

    if [[ -z "${username}" ]]; then
        username="${account}"
    fi

    local password
    password="$(keys_var "CalDAV/Accounts/${account}")" || {
        >&2 echo "Error: Failed to retrieve password for CalDAV/Accounts/${account}"
        >&2 echo "Set password with: keys_var CalDAV/Accounts/${account} YOUR_PASSWORD"
        return 1
    }

    curl -s -u "${username}:${password}" "${url}"
}

# Show upcoming events from a CalDAV calendar.
#
# Usage: caldav_agenda [-a|--account ACCOUNT] [-u|--username USER] [-d|--days DAYS] [URL]
#
# Options:
#   -a, --account ACCOUNT  Account name for password lookup.
#                          If omitted and exactly one account exists, uses that.
#   -u, --username USER    Username for authentication. Defaults to account name.
#   -d, --days DAYS        Number of days to show (from today). Defaults to 31.
#
# If URL is not provided, it is retrieved using: keys_var CalDAV/URLs/$account
#
# Example:
#   caldav_agenda -a fastmail -d 14 https://caldav.fastmail.com/dav/calendars/user/...
#   caldav_agenda -a fastmail  # URL loaded from keys_var CalDAV/URLs/fastmail
function caldav_agenda() {
    local account=""
    local username=""
    local url=""
    local days=31

    while [[ "${#}" -ne 0 ]]; do
        case "${1}" in
            -a|--account)
                account="${2}"
                shift
                ;;
            -u|--username)
                username="${2}"
                shift
                ;;
            -d|--days)
                days="${2}"
                shift
                ;;
            *)
                url="${1}"
                ;;
        esac
        shift
    done

    local fetch_args=()
    [[ -n "${account}" ]] && fetch_args+=(-a "${account}")
    [[ -n "${username}" ]] && fetch_args+=(-u "${username}")
    [[ -n "${url}" ]] && fetch_args+=("${url}")

    local ics_data
    ics_data="$(caldav_fetch "${fetch_args[@]}")" || return $?

    # Parse the ICS data and filter events
    # Use YYYYMMDD format for date comparison in awk
    local now_date end_date
    now_date="$(date +%Y%m%d)"
    end_date="$(date -v+${days}d +%Y%m%d 2>/dev/null || date -d "+${days} days" +%Y%m%d)"

    echo "${ics_data}" | tr -d '\r' | awk -v now_date="${now_date}" -v end_date="${end_date}" '
    BEGIN {
        in_event = 0
        split("Sun,Mon,Tue,Wed,Thu,Fri,Sat", weekdays, ",")
        output_count = 0
    }

    function dow(year, month, day) {
        # Zeller formula for day of week (0=Sun, 1=Mon, ..., 6=Sat)
        if (month < 3) {
            month += 12
            year--
        }
        k = year % 100
        j = int(year / 100)
        h = (day + int((13 * (month + 1)) / 5) + k + int(k / 4) + int(j / 4) - 2 * j) % 7
        # Convert from Zeller (0=Sat) to standard (0=Sun)
        return ((h + 6) % 7) + 1
    }

    /^BEGIN:VEVENT/ {
        in_event = 1
        event_start = ""
        event_summary = ""
        event_location = ""
        attendee_count = 0
        delete attendees
        next
    }

    /^END:VEVENT/ {
        in_event = 0
        if (event_start != "" && event_summary != "") {
            # Extract just digits from DTSTART
            start_digits = event_start
            gsub(/[^0-9]/, "", start_digits)
            if (length(start_digits) >= 8) {
                event_date = substr(start_digits, 1, 8)

                # Filter by date range
                if (event_date >= now_date && event_date <= end_date) {
                    year = substr(start_digits, 1, 4) + 0
                    month = substr(start_digits, 5, 2) + 0
                    day = substr(start_digits, 7, 2) + 0
                    hour = "00"
                    min = "00"
                    if (length(start_digits) >= 12) {
                        hour = substr(start_digits, 9, 2)
                        min = substr(start_digits, 11, 2)
                    }

                    wday = weekdays[dow(year, month, day)]

                    # Build output as single line for sorting
                    # Format: sort_key<TAB>display_lines (use RS as line separator within output)
                    sort_key = sprintf("%04d%02d%02d%s%s", year, month, day, hour, min)
                    date_str = sprintf("%s %04d-%02d-%02d %s:%s", wday, year, month, day, hour, min)
                    output = date_str " | " event_summary
                    if (event_location != "") {
                        output = output "%%NL%%                 @ " event_location
                    }
                    if (attendee_count > 0) {
                        max_show = (attendee_count > 8) ? 8 : attendee_count
                        output = output "%%NL%%                 + "
                        for (i = 1; i <= max_show; i++) {
                            if (i > 1) output = output ", "
                            output = output attendees[i]
                        }
                        if (attendee_count > 8) {
                            output = output sprintf(" (+%d more)", attendee_count - 8)
                        }
                    }
                    output_count++
                    outputs[output_count] = sort_key "\t" output
                }
            }
        }
        next
    }

    !in_event { next }

    /^DTSTART/ {
        sub(/^DTSTART[^:]*:/, "")
        event_start = $0
        next
    }

    /^SUMMARY/ {
        sub(/^SUMMARY[^:]*:/, "")
        event_summary = $0
        next
    }

    /^LOCATION/ {
        sub(/^LOCATION[^:]*:/, "")
        event_location = $0
        next
    }

    /^ATTENDEE/ {
        # Extract CN (common name) if present, otherwise use email
        line = $0
        name = ""
        if (match(line, /CN=[^;:]+/)) {
            name = substr(line, RSTART + 3, RLENGTH - 3)
        } else if (match(line, /mailto:[^@]+@/)) {
            name = substr(line, RSTART + 7, RLENGTH - 8)
        }
        if (name != "") {
            attendee_count++
            attendees[attendee_count] = name
        }
        next
    }

    END {
        for (i = 1; i <= output_count; i++) {
            print outputs[i]
        }
    }
    ' | sort -t'	' -k1,1 | cut -f2- | sed 's/%%NL%%/\
/g'
}

fi # _REDSHELL_CALDAV
