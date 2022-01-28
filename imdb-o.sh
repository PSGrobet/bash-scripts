#!/usr/bin/env bash
# Author: Alexander Epstein https://github.com/alexanderepstein

currentVersion="1.22.1"
configuredClient=""
configuredPython=""
detail=false

## This function determines which http get tool the system has installed and returns an error if there isnt one
getConfiguredClient()
{
  if  command -v curl &>/dev/null; then
    configuredClient="curl"
  elif command -v wget &>/dev/null; then
    configuredClient="wget"
  elif command -v http &>/dev/null; then
    configuredClient="httpie"
  elif command -v fetch &>/dev/null; then
    configuredClient="fetch"
  else
    echo "Error: This tool requires either curl, wget, httpie or fetch to be installed." >&2
    return 1
  fi
}

## Allows to call the users configured client without if statements everywhere
httpGet()
{
  case "$configuredClient" in
    curl)  curl -A curl -s "$@" ;;
    wget)  wget -qO- "$@" ;;
    httpie) http -b GET "$@" ;;
    fetch) fetch -q "$@" ;;
  esac
}

getConfiguredPython()
{
  if  command -v python2 &>/dev/null ; then
    configuredPython="python2"
  elif command -v python &>/dev/null ; then
    configuredPython="python"
  else
    echo "Error: This tool requires python 2 to be installed."
    return 1
  fi
}

if [[ $(uname) != "Darwin" ]]; then
  python()
  {
    case "$configuredPython" in
      python2) python2 "$@";;
      python) python "$@";;
    esac
  }
fi

checkInternet()
{
  httpGet github.com > /dev/null 2>&1 || { echo "Error: no active internet connection" >&2; return 1; } # query github with a get request
}

## This function grabs information about a movie and using python parses the
## JSON response to extrapolate the information for storage
getMovieInfo()
{
  apiKey=946f500a # try not to abuse this it is a key that came from the ruby-scripts repo I link to.
  movie=$( (echo "$@" | tr " " + ) | sed 's/-d+//g' ) ## format the inputs to use for the api. Added sed command to filter -d flag.
  export PYTHONIOENCODING=utf8 #necessary for python in some cases
  movieInfo=$(httpGet "http://www.omdbapi.com/?t=$movie&apikey=$apiKey") > /dev/null # query the server and get the JSON response
  checkResponse=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Response']" 2> /dev/null)
  if [[ $checkResponse == "False" ]]; then { echo "No movie found" ; return 1 ;} fi ## check to see if the movie was found
  # The rest of the code is just extrapolating the data with python from the JSON response
  title=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Title']" 2> /dev/null)
  year=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Year']" 2> /dev/null)
  runtime=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Runtime']" 2> /dev/null)
  imdbScore=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Ratings'][0]['Value']" 2> /dev/null)
  tomatoScore=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Ratings'][1]['Value']" 2> /dev/null)
  rated=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Rated']" 2> /dev/null)
  genre=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Genre']" 2> /dev/null)
  director=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Director']" 2> /dev/null)
  actors=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Actors']" 2> /dev/null)
  plot=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Plot']" 2> /dev/null)
  
  if $detail; then
    awards=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Awards']" 2> /dev/null)
    boxOffice=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['BoxOffice']" 2> /dev/null)
    metacriticScore=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Ratings'][2]['Value']" 2> /dev/null)
    production=$(echo $movieInfo | python -c "import sys, json; print json.load(sys.stdin)['Production']" 2> /dev/null)
  fi
}

# Prints the movie information out in a human readable format
printMovieInfo()
{
  echo
  echo '=================================================='
  echo "| Title: $title"
  echo "| Year: $year"
  echo "| Runtime: $runtime"
  if [[ $imdbScore != "" ]]; then echo "| IMDB: $imdbScore"; fi
  if [[ $tomatoScore != "" ]]; then echo "| Tomato: $tomatoScore"; fi
  if $detail; then
    if [[ $metacriticScore != "" ]]; then echo "| Metascore: $metacriticScore"; fi
  fi
  if [[ $rated != "N/A" && $rated != "" ]]; then echo "| Rated: $rated"; fi
  echo "| Genre: $genre"
  echo "| Director: $director"
  echo "| Actors: $actors"
  if [[ $plot != "N/A" && $plot != "" ]]; then echo "| Plot: $plot"; fi
  if $detail; then
    if [[ $boxOffice != "" ]]; then echo "| Box Office: $boxOffice"; fi
    if [[ $production != "" ]]; then echo "| Production: $production"; fi
    if [[ $awards != "" ]]; then echo "| Awards: $awards"; fi
  fi
  echo '=================================================='
  echo
}

update()
{
  # Author: Alexander Epstein https://github.com/alexanderepstein
  # Update utility version 2.2.0
  # To test the tool enter in the defualt values that are in the examples for each variable
  repositoryName="Bash-Snippets" #Name of repostiory to be updated ex. Sandman-Lite
  githubUserName="alexanderepstein" #username that hosts the repostiory ex. alexanderepstein
  nameOfInstallFile="install.sh" # change this if the installer file has a different name be sure to include file extension if there is one
  latestVersion=$(httpGet https://api.github.com/repos/$githubUserName/$repositoryName/tags | grep -Eo '"name":.*?[^\\]",'| head -1 | grep -Eo "[0-9.]+" ) #always grabs the tag without the v option

  if [[ $currentVersion == "" || $repositoryName == "" || $githubUserName == "" || $nameOfInstallFile == "" ]]; then
    echo "Error: update utility has not been configured correctly." >&2
    exit 1
  elif [[ $latestVersion == "" ]]; then
    echo "Error: no active internet connection" >&2
    exit 1
  else
    if [[ "$latestVersion" != "$currentVersion" ]]; then
      echo "Version $latestVersion available"
      echo -n "Do you wish to update $repositoryName [Y/n]: "
      read -r answer
      if [[ "$answer" == [Yy] ]]; then
        cd ~ || { echo 'Update Failed'; exit 1; }
        if [[ -d  ~/$repositoryName ]]; then rm -r -f $repositoryName || { echo "Permissions Error: try running the update as sudo"; exit 1; } ; fi
        echo -n "Downloading latest version of: $repositoryName."
        git clone -q "https://github.com/$githubUserName/$repositoryName" && touch .BSnippetsHiddenFile || { echo "Failure!"; exit 1; } &
        while [ ! -f .BSnippetsHiddenFile ]; do { echo -n "."; sleep 2; };done
        rm -f .BSnippetsHiddenFile
        echo "Success!"
        cd $repositoryName || { echo 'Update Failed'; exit 1; }
        git checkout "v$latestVersion" 2> /dev/null || git checkout "$latestVersion" 2> /dev/null || echo "Couldn't git checkout to stable release, updating to latest commit."
        chmod a+x install.sh #this might be necessary in your case but wasnt in mine.
        ./$nameOfInstallFile "update" || exit 1
        cd ..
        rm -r -f $repositoryName || { echo "Permissions Error: update succesfull but cannot delete temp files located at ~/$repositoryName delete this directory with sudo"; exit 1; }
      else
        exit 1
      fi
    else
      echo "$repositoryName is already the latest version"
    fi
  fi
}

usage()
{
  cat <<EOF
Movies
Description: Provides relevant information about a certain movie.
Usage: movies [flag] or movies [movieToSearch]
  -u  Update Bash-Snippet Tools
  -h  Show the help
  -v  Get the tool version
  -d  Show detailed information
Examples:
  movies Argo
  movies Inception
EOF
}

if [[ $(uname) != "Darwin" ]]; then getConfiguredPython || exit 1; fi
getConfiguredClient || exit 1


while getopts 'ud:hv' flag; do
  case "${flag}" in
    u) checkInternet || exit 1 # check if we have a valid internet connection if this isnt true the rest of the script will not work so stop here
      update
       exit 0 ;;
    d) detail=true ;;
    h) usage
       exit 0 ;;
    v) echo "Version $currentVersion"
       exit 0 ;;
    :) echo "Option -$OPTARG requires an argument." >&2
       exit 1 ;;
    *) exit 1 ;;
  esac
done

if [[ $# == 0 ]]; then
  usage
elif [[ $1 == "update" ]]; then
  checkInternet || exit 1 # check if we have a valid internet connection if this isnt true the rest of the script will not work so stop here
  update
elif [[ $1 == "help" ]]; then
  usage
else
  checkInternet || exit 1 # check if we have a valid internet connection if this isnt true the rest of the script will not work so stop here
  getMovieInfo "$@" || exit 1 ## exit if we return 1 (chances are movie was not found)
  printMovieInfo ## print out the data
fi
