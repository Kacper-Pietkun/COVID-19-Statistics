#!/bin/bash
# Author           : Kacper Pietkun ( kacper.pietkun00@gmail.com )
# Created On       : 11.04.2020r.
# Last Modified By : Kacper Pietkun ( kacper.pietkun00@gmail.com )
# Last Modified On : 14.05.2020r. 
# Version          : wersja 1.0
#
# Description      : COVID-19 statistics. Programme allows to check how many people were infected, died or recovered.
# Opis               User can check worldwide statistic or can search by country.
#                    Statistics are downlanded from https://www.worldometers.info/coronavirus/?
#                    User is able to search Countries by their English or Polish name, to translate user's input programme
#                    downloads source of https://pl.bab.la/slownik/polski-angielski/
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details
# or contact # the Free Software Foundation for a copy)


menu() {
    until [[ "$MENU_ODP" == "Exit" || "$MENU_ODP" == "" ]]; do
        MENU_ODP=`zenity --list --column Menu "${MENU[@]}" --height 250 --width 400`
        chosen_option
    done
}

chosen_option() {
    case "$MENU_ODP" in
    "Check worldwide statistics") print_world_info;;
    "Check statistics for a specific country") choose_country;;
    "Update statistics") update_data;;
    *);;
    esac
}

print_world_info() {
    if [[ ! -f "$ALL_CASES_FILE" ]]; then
        zenity --warning --width 200 --text "Something is wrong. Some files are missing. Check internet connection."
        return;
    fi
    get_all_infected
    get_all_recovered
    get_all_deaths
    zenity --info --title "Worldwide statistics" --height 100 --width 220 --text "Total cases: $ALL_INFECTED_CASES\nTotal deaths: $ALL_DEATH_CASES\nTotal recovered: $ALL_RECOVERED_CASES"
}

get_all_infected() {
    ALL_INFECTED_CASES=`pcregrep -M --buffer-size=100000  "<h1>Coronavirus Cases:</h1>\n<div class=\"maincounter-number\">\n<span style=\"color:#aaa\">.*</span>" $ALL_CASES_FILE`
    ALL_INFECTED_CASES=`echo $ALL_INFECTED_CASES | cut -d ">" -f 5 | sed 's/[^0-9]//g'`
}

get_all_recovered() {
    ALL_RECOVERED_CASES=`pcregrep -M --buffer-size=100000  "<h1>Recovered:</h1>\n<div class=\"maincounter-number\" style=\"color:#8ACA2B \">\n<span>.*</span>" $ALL_CASES_FILE`
    ALL_RECOVERED_CASES=`echo $ALL_RECOVERED_CASES | cut -d ">" -f 5 | sed 's/[^0-9]//g'`
}

get_all_deaths() {
    ALL_DEATH_CASES=`pcregrep -M --buffer-size=100000  "<h1>Deaths:</h1>\n<div class=\"maincounter-number\">\n<span>.*</span>" $ALL_CASES_FILE`
    ALL_DEATH_CASES=`echo $ALL_DEATH_CASES | cut -d ">" -f 5 | sed 's/[^0-9]//g'`
}

update_data() {
    wget -O "$ALL_CASES_FILE" $URL_ALL_CASES
    [ $? -ne 0 ] && zenity --warning --width 200 --text "Something is wrong. Some files are missing. Check internet connection." || get_country_list
}

get_country_list() {
    sed "s/>\s*</>0</" $ALL_CASES_FILE  | grep "<td" | sed "s/<\/td>// ; s/<\/a>// ; s/<td.*>// ; s/<td.*$// ; /^$/ d;" > $COUNTRY_LIST_FILE
}

choose_country() {
    if [[ ! -f "$COUNTRY_LIST_FILE" ]]; then
        zenity --warning --width 200 --text "Something is wrong. Some files are missing. Check internet connection."
        return;
    fi
    while [[ "$FOUND_COUNTRY" == "FALSE" ]]; do
        COUNTRY=`zenity --entry --title "" --text "Type name of the country"`
        if [[ $? -eq 1 ]]; then return; fi
        change_coutry_to_fit_pattern
        check_country_on_the_list
        [ "$FOUND_COUNTRY" == "FALSE" ] && download_translation_site

        if [[ "$FOUND_COUNTRY" == "FALSE" ]]; then
            zenity --warning --title "Try again" --text "There is no such country" --width 150
        fi
    done
    
    get_country_info
    print_country_info
    FOUND_COUNTRY="FALSE"
}

change_coutry_to_fit_pattern() {
    COUNTRY=`echo $COUNTRY | tr '[:upper:]' '[:lower:]'`
    COUNTRY=`echo "${COUNTRY^}"`
}

check_country_on_the_list() {
    grep -q -E "^$COUNTRY$" $COUNTRY_LIST_FILE
    [ $? -eq 0 ] && FOUND_COUNTRY="TRUE" || FOUND_COUNTRY="FALSE"
}

download_translation_site() {
    wget -O "$TRANSLATION_FILE" ${TRANSLATE_URL}${COUNTRY}
    [ $? -ne 0 ] && zenity --warning --width 200 --text "Something is wrong. Some files are missing. Check internet connection."  || translate_country
}

translate_country() {
    COUNTRY_TEMP=`grep -Eo "quot; po polsku\">.*</a>" $TRANSLATION_FILE  | grep -v "strong" | grep -Eo ">.*<" | sed "s/>// ; s/<//"`
    
    # Translator may return more than one name
    for COUNTRY_NAME in $COUNTRY_TEMP; do
        COUNTRY=$COUNTRY_NAME
        check_country_on_the_list
        [ "$FOUND_COUNTRY" == "TRUE" ] && return 1
    done
}

get_country_info() {
    COUNTRY_INFO=`awk  "/^$COUNTRY$/"' {for(i=1; i<=11; i++) {getline; print}}' $COUNTRY_LIST_FILE`
    I=0
    COUNTRY_ARRAY_INFO=()
    for INFO in $COUNTRY_INFO; do
        COUNTRY_ARRAY_INFO[$I]=$INFO
        I=$((I+1))
    done
}

print_country_info() {
    zenity --info --title "Statistics for: $COUNTRY" --height 200 --width 300 --text "Total cases: ${COUNTRY_ARRAY_INFO[0]}\nNew cases: ${COUNTRY_ARRAY_INFO[1]}\nTotal deaths: ${COUNTRY_ARRAY_INFO[2]}\nTotal recovered: ${COUNTRY_ARRAY_INFO[3]}\nCritical cases: ${COUNTRY_ARRAY_INFO[5]}\nTotal cases / 1M people: ${COUNTRY_ARRAY_INFO[6]}\nTotal deaths / 1M people: ${COUNTRY_ARRAY_INFO[7]}\nTotal tests: ${COUNTRY_ARRAY_INFO[8]}\nTotal tests / 1M people: ${COUNTRY_ARRAY_INFO[9]}"
}

delete_files() {
    rm $ALL_CASES_FILE 
    rm $COUNTRY_LIST_FILE 
    rm $TRANSLATION_FILE
}

help_me() {
    echo "COVID-19 statistics. Programme allows to check how many people were infected, died or recovered. You can check worldwide statistic or you can search by country."
    echo ""
    echo "   -v - prints version of the programme"
    echo ""
    echo "   Menu:"
    echo "   Check worldwide statistics                --- Shows statistic for the whole world."
    echo "   Cehck statistics for a specific country   --- User has to type name of the country"
    echo "                                                 (English or Polish) and then they"
    echo "                                                 will see statistics for the given country."
    echo "   Update statistics                         --- There is a possibility that statistic can"    
    echo "                                                 change when programme is opened, this option"
    echo "                                                 allows user to update information."    
    echo "   Exit                                      --- Exits the programme."
    OTHEROPTION="TRUE"
}

version() {
    echo "Version $1"
    OTHEROPTION="TRUE"
}

error() {
    OTHEROPTION="TRUE"
}


URL_ALL_CASES="https://www.worldometers.info/coronavirus/?"

ALL_CASES_FILE="/tmp/covid_statistics_all_cases.$$"
ALL_INFECTED_CASES=0
ALL_DEATH_CASES=0
ALL_RECOVERED_CASES=0

FOUND_COUNTRY="FALSE"
COUNTRY="brak"
COUNTRY_INFO=
COUNTRY_ARRAY_INFO=()
COUNTRY_LIST_FILE="/tmp/covid_statistics_country_list.$$"
COUNTRY_INFECTED_CASES=0
COUNTRY_DEATH_CASES=0
COUNTRY_RECOVERED_CASES=0

MENU=("Check worldwide statistics" "Check statistics for a specific country" "Update statistics" "Exit")
MENU_ODP="."

TRANSLATE_URL="https://pl.bab.la/slownik/polski-angielski/"
TRANSLATION_FILE="/tmp/covid_statistics_translation.$$"

VERSION="1.0"


OTHEROPTION="FALSE"
while getopts hv OPT; do
    case $OPT in
        h) help_me;;
        v) version $VERSION;;
        *) error;;
    esac    
done

if [[ "$OTHEROPTION" == "TRUE" ]]; then
    exit;
fi


update_data
menu
delete_files


