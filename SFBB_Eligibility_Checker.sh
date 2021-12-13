#!/bin/bash

# Commands
JQ_COMMAND="/opt/homebrew/bin/jq" # Added whole path because crontab does not recognize it otherwise

# Script arguments
ZIP_CODE="$1"
STREET="$2"
STREET_NUMBER="$3"
DAY_OF_MONTH_LIVELINESS="$4"

# Request related
STREET_URL_ENCODED=$(echo ${STREET} | $JQ_COMMAND -sRr @uri | sed 's/%CE%/%u03/g' | sed 's/%20/+/g' | sed 's/%0A//g')
SFBB="https://submit.sfbb.gr/EligibilityCheck.aspx"
SFBB_QUERY="${SFBB}?zip=${ZIP_CODE}&address=${STREET_URL_ENCODED}"

# Notification messages
NOTIFICATION_SUCCESS_TITLE="Great news! SFBB Eligibility! :)"
NOTIFICATION_SUCCESS_SUB="Opening new Safari tab...."
NOTIFICATION_SUCCESS="${STREET} ${STREET_NUMBER}, ${ZIP_CODE} is eligible for Fiber to the Home!"
NOTIFICATION_NO_OFFER_TITLE="You're close for SFBB Eligibility! :)"
NOTIFICATION_NO_OFFER_SUB="Openind new Safari tab..."
NOTIFICATION_NO_OFFER="${STREET} ${STREET_NUMBER}, ${ZIP_CODE} is eligible for Fiber to the Home but no offer is available yet!"
NOTIFICATION_NOT_ELIGIBLE_TITLE="Be patient..."
NOTIFICATION_NOT_ELIGIBLE_SUB=""
NOTIFICATION_NOT_ELIGIBLE="${STREET} ${STREET_NUMBER}, ${ZIP_CODE} is still not eligible for Fiber to the Home."
NOTIFICATION_ERROR_TITLE="CAUTION: Error executing script"
NOTIFICATION_ERROR_SUB="${STREET} ${STREET_NUMBER}, ${ZIP_CODE}"
NOTIFICATION_ERROR="There was an error while executing your script for Fiber to the Home eligibility."

check_string_in_response(){
  echo $RESPONSE | grep -q "$1"
  if [[ "$?" -eq 0 ]]
  then
    echo "Response contains ${1}"
  else
    echo "Response does not contain ${1}"
    exit 1
  fi
}

osascript_notification(){
    osascript -e "display notification \"$1\" with title \"$2\" subtitle \"$3\" sound name \"Blow\""
}

notify_desktop(){
  local MODE="$1"
  if [[ "$MODE" == success ]]
  then
    osascript_notification "$NOTIFICATION_SUCCESS" "$NOTIFICATION_SUCCESS_TITLE" "$NOTIFICATION_SUCCESS_SUB"
  elif [[ "$MODE" == eligible_no_offer ]]
  then
    osascript_notification "$NOTIFICATION_NO_OFFER" "$NOTIFICATION_NO_OFFER_TITLE" "$NOTIFICATION_NO_OFFER_SUB"
  elif [[ "$MODE" == not_eligible ]]
  then
    osascript_notification "$NOTIFICATION_NOT_ELIGIBLE" "$NOTIFICATION_NOT_ELIGIBLE_TITLE" "$NOTIFICATION_NOT_ELIGIBLE_SUB"
  elif [[ "$MODE" == error  ]]
  then
    osascript_notification "$NOTIFICATION_ERROR" "$NOTIFICATION_ERROR_TITLE" "$NOTIFICATION_ERROR_SUB"
  fi
}

notify_browser(){
  open -a Safari $SFBB
}

log_locally(){
  echo 'The script could not find if you are eligible for SFBB'
  echo "ZIP CODE: ${ZIP_CODE}"
  echo "STREET: ${STREET}"
  echo "SREET URL ENCODED: ${STREET_URL_ENCODED}"
  echo "STREET NUMBER: ${STREET_NUMBER}"
  check_string_in_response "Έχετε επιλέξει τον ταχυδρομικό κωδικό: ${ZIP_CODE}"
  check_string_in_response "Έχετε επιλέξει την οδό: ${STREET}"
  check_string_in_response 'Βήμα 3: Εισάγετε τον αριθμό της οδού'
  echo "RESPONSE WAS:"
  echo $RESPONSE
}

notify(){
  local MODE="$1"
  if [[ "$MODE" == success ]] || [[ "$MODE" == eligible_no_offer ]]
  then
    notify_desktop $MODE
    notify_browser
  elif [[ "$MODE" == not_eligible ]]
  then
    notify_desktop $MODE
  elif [[ "$MODE" == error ]]
  then
    notify_desktop $MODE
    log_locally
  fi
}


check_eligibility(){
  echo $RESPONSE | grep -q 'Στη διεύθυνση που δηλώσατε υπάρχουν διαθέσιμες προσφορές SFBB'
  if [[ "$?" -eq 0 ]]
  then
    notify success
    exit 0
  fi
  echo $RESPONSE | grep -q 'Στη διεύθυνση που δηλώσατε δεν υπάρχουν υποδομές ικανές να προσφέρουν SFBB υπηρεσίες.'
  if [[ "$?" -eq 0 ]]
  then
    if [[ "$(date +%A)" == "$DAY_OF_MONTH_LIVELINESS" ]]
    then
      notify not_eligible
    fi
    exit 0
  fi
  echo $RESPONSE | grep -q 'Η διεύθυνση που δηλώσατε περιλαμβάνεται στις περιοχές όπου θα προσφέρονται SFBB υπηρεσίες, αλλά ακόμη δεν υπάρχει καμία διαθέσιμη προσφορά.'
  if [[ "$?" -eq 0 ]]
  then
    notify eligible_no_offer
    exit 0
  fi
  notify error
  exit 1
}


RESPONSE=$(curl -s --location --request POST "${SFBB_QUERY}" \
--header 'Content-Type: application/x-www-form-urlencoded' \
--header 'Cookie: ; ACIDPERSIST=srvC|YYQEE|YYPeg' \
--data-urlencode '__EVENTTARGET=' \
--data-urlencode "ctl00\$cphMain\$txtStreetNumber=${STREET_NUMBER}" \
--data-urlencode 'ctl00$cphMain$btnCheckEligibility=Έλεγχος')

check_eligibility
