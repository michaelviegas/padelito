#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# TieSports API Request Script with Retry Logic
# Reads configuration from /home/pi/padelito.data
# Usage: ./bookcourt.sh

# players
#     180022: Hugo Martins
#     173264: Darcy Mendes
#     179439: Mário Clara
#     210556: Mario Casinhas
#     210797: Jose Carlos Viegas
#     118546: Joao Ramos
#     177693: João Duarte
#     200771: Bruno Da Silva
#     183187: José Miguel Manhoso
#     186340: Luís Cristo
#     180408: Monia Bernardo
#     198962: Renato Coelho
#     90787: Sónia Cristina Palma
#     177730: Telmo Manuel Machado Pinto
#     244858: Rickie Grosso
#     176860: Hugo Ranito
#     219949: Goncalo Ferreira
#     4395: Olga Shilova
#     7020: Rui Soares
#     172642: Diogo Dias
#     91874: Duarte Meneses
#     25734: Lana
#     219289: Alec
#     85701: Antonio Oliveira
#     168820: Joao Vila Verde
#     3960: Jorge Bartolomeu
#     211265: Daniela Abreu
#     221708: Diogo Fernandes
#     366688: Simao Arriaga
#     242465: Diogo Barbosa
#     79506: Eduardo Moscao
#     165636: Alexis Deulabert
#     19962: Paulo Santos
#     198156: Eurico Pimenta

# Vilamoura
# clubId = 1633
# courts
#   1039: campo 1
#   6861: campo 2
#   14: campo 3
#   714: campo 4
#   737: campo 5
#   373: campo 6
#   2288: campo 7
#   7634: campo 8
#   9678: campo 9

# Alsakia
# clubId = 47410;
# courts
#   6353: campo 1
#   6354: campo 2
#   6355: campo 3

# Configuration file path
CONFIG_FILE="${PADELITO_DATA:-/app/padelito.data}"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Source the configuration file
source "$CONFIG_FILE"

# Verify all required variables are set
if [ -z "$TOKEN_ID" ] || [ -z "$CLUB_ID" ] || [ -z "$DAYS_TO_ADD" ] || [ -z "$COURT_IDS" ] || [ -z "$HOURS" ] || [ -z "$BOT_ID" ] || [ -z "$CHAT_ID" ]; then
    echo "Error: Missing required configuration in $CONFIG_FILE"
    echo "Required variables: TOKEN_ID, CLUB_ID, DAYS_TO_ADD, COURT_IDS, HOURS, BOT_ID, CHAT_ID"
    exit 1
fi

# Calculate the day
DAY=$(date -d "+${DAYS_TO_ADD} days" +"%Y-%m-%d")

echo "=== TieSports Match Booking Script ==="
echo "Token: ${TOKEN_ID}"
echo "Club ID: ${CLUB_ID}"
echo "Date: ${DAY} (current date + ${DAYS_TO_ADD} days)"
echo "Time: ${HOURS}"
echo "Court IDs to try: ${COURT_IDS}"
echo "======================================"
echo ""

# Convert comma-separated court IDs to array
IFS=',' read -ra COURTS <<< "$COURT_IDS"

# Maximum number of attempts per court
MAX_ATTEMPTS=10

# Function to send telegram message
send_telegram_message() {
    local message=$1
    local url="https://api.telegram.org/bot${BOT_ID}/sendMessage"

    echo "Sending to Telegram API..."
    response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\":\"${CHAT_ID}\",\"text\":\"${message}\"}")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    echo "Telegram API Response (HTTP ${http_code}):"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
    echo ""
}

# Function to get available courts
get_available_courts() {
    echo "  Fetching available courts..."
    
    response=$(curl -s -w "\n%{http_code}" -X GET \
        "https://api.tiesports.com/clubs.asmx/get_courts_for_booking_by_club?token=${TOKEN_ID}&club_id=${CLUB_ID}&day=${DAY}&start_time=${HOURS}&sport_id=2" \
        -H "Host: api.tiesports.com" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Accept-Language: en-GB,en;q=0.9" \
        -H "Connection: keep-alive" \
        -H "Accept-Encoding: gzip, deflate, br" \
        -H "User-Agent: TiePlayer/339 CFNetwork/3860.400.51 Darwin/25.3.0" \
        --compressed)

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 200 ]; then
        # Extract court IDs where slots array is not empty
        available_courts=$(echo "$body" | python3 -c "
import sys
import json
try:
    data = json.load(sys.stdin)
    courts = data.get('list', [])
    available = [str(court['court_id']) for court in courts if court.get('slots', [])]
    print(' '.join(available))
except Exception as e:
    print('', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

        if [ -n "$available_courts" ]; then
            echo "  Available courts: ${available_courts}"
            echo "$available_courts"
        else
            echo "  No courts available at this time"
            echo ""
        fi
    else
        echo "  ✗ Failed to fetch available courts (HTTP ${http_code})"
        echo ""
    fi
}

# Function to make API request
make_request() {
    local court_id=$1

    response=$(curl -s -w "\n%{http_code}" -X GET \
        "https://api.tiesports.com/set_a_match.asmx/save_match_v7?token=${TOKEN_ID}&club_id=${CLUB_ID}&sport_id=2&day=${DAY}&hours=${HOURS}&duration_minutes=90&court_id=${court_id}&gender=3&min_rating=10&max_rating=320&min_age=5&max_age=99&list_players_ids=&singles=false&get_players_from_friends=false&get_players_from_club=false&get_players_from_last_matches=false&get_players_from_near=false&chat_room_ids=&chat_room_request_players=false&max_players=4&go_booking=true&booking_with_lighting=true&is_public=false&promoted_match_guid=&match_title=" \
        -H "Host: api.tiesports.com" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Accept-Language: en-GB,en;q=0.9" \
        -H "Connection: keep-alive" \
        -H "Accept-Encoding: gzip, deflate, br" \
        -H "User-Agent: TiePlayer/339 CFNetwork/3860.400.51 Darwin/25.3.0" \
        --compressed)

    # Split response body and status code
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    echo "$http_code|$body"
}

# Main loop
success=false
successful_court_id=""

for attempt in $(seq 1 $MAX_ATTEMPTS); do
    if [ "$success" = true ]; then
        break
    fi

    echo "=== Attempt ${attempt}/${MAX_ATTEMPTS} ==="
    
    # Get available courts for this attempt
    AVAILABLE_COURTS=$(get_available_courts)
    
    if [ -z "$AVAILABLE_COURTS" ]; then
        echo "  No courts available, waiting before next attempt..."
        echo ""
        sleep 1
        continue
    fi
    
    echo ""

    for court_id in "${COURTS[@]}"; do
        if [ "$success" = true ]; then
            break
        fi

        # Check if this court is in the available courts list
        if echo "$AVAILABLE_COURTS" | grep -qw "$court_id"; then
            echo "  Trying Court ID: ${court_id}..."

            result=$(make_request "$court_id")
            http_code=$(echo "$result" | cut -d'|' -f1)
            body=$(echo "$result" | cut -d'|' -f2-)

            # Check if HTTP request was successful
            if [ "$http_code" -eq 200 ]; then
                # Try to parse JSON status field
                status=$(echo "$body" | grep -o '"status":[0-9]*' | cut -d':' -f2)

                if [ "$status" = "1" ]; then
                    echo ""
                    echo "✓ SUCCESS! Booking confirmed for Court ID: ${court_id}"

                    # Extract SET_a_MATCH_id from the response
                    set_a_match_id=$(echo "$body" | grep -o '"SET_a_MATCH_id":[0-9]*' | cut -d':' -f2)

                    if [ -n "$set_a_match_id" ]; then
                        echo "Match ID: ${set_a_match_id}"
                        echo ""
                        echo "Fetching match details..."

                        # Fetch match details
                        match_details=$(curl -s -X GET \
                            "https://api.tiesports.com/set_a_match.asmx/get_Set_a_Match?token=${TOKEN_ID}&set_a_match_id=${set_a_match_id}" \
                            -H "Host: api.tiesports.com" \
                            -H "Accept: application/json, text/plain, */*" \
                            -H "Accept-Language: en-GB,en;q=0.9" \
                            -H "Connection: keep-alive" \
                            -H "Accept-Encoding: gzip, deflate, br" \
                            -H "User-Agent: TiePlayer/339 CFNetwork/3860.400.51 Darwin/25.3.0" \
                            --compressed)

                        # Extract the share message from match details
                        share_message=$(echo "$match_details" | python3 -c "
import sys
import json
try:
    data = json.load(sys.stdin)
    message = data.get('obj', {}).get('share_match', {}).get('message', '')
    if message:
        print(message)
    else:
        print('${DAY} ${HOURS} ${court_id} SUCCESS')
except:
    print('${DAY} ${HOURS} ${court_id} SUCCESS')
" 2>/dev/null)

                        # Fallback if extraction failed
                        if [ -z "$share_message" ]; then
                            share_message="${DAY} ${HOURS} ${court_id} SUCCESS"
                        fi
                    else
                        # Fallback if no match ID found
                        share_message="${DAY} ${HOURS} ${court_id} SUCCESS"
                    fi

                    echo "=== Initial Response ==="
                    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
                    echo "========================"
                    echo ""

                    success=true
                    successful_court_id="$court_id"

                    # Send telegram notification with share message
                    echo "Sending Telegram notification..."
                    echo "Message: ${share_message}"
                    send_telegram_message "$share_message"

                    break
                else
                    echo "    ✗ Status: ${status:-unknown} (not successful)"
                fi
            else
                echo "    ✗ HTTP Error: ${http_code}"
            fi
        else
            echo "  Court ID ${court_id} not available (skipping)"
        fi
    done

    if [ "$success" = false ]; then
        echo ""
        # Small delay between full rounds
        sleep 1
    fi
done

if [ "$success" = false ]; then
    echo "❌ Failed to book after trying all courts with ${MAX_ATTEMPTS} attempts each"

    # Send telegram notification for failure
    message="${DAY} ${HOURS} FAILED"
    echo ""
    echo "Sending Telegram notification: ${message}"
    send_telegram_message "$message"

    exit 1
else
    echo ""
    echo "✓ Booking process completed successfully!"
    exit 0
fi
