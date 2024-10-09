#!/bin/bash

FILE=./.gitignore

if test -f "$FILE"; then
    echo "Found -> .gitignore"
else
    echo "Copied -> Default .gitignore"
    cp /home/mathilde/Scripts/GIT/.gitignore .
    git add .gitignore
    git commit -m "[AutoScript] [ADD] .gitignore"
    git push
fi

if [[ -z "$1" ]];
then 
    echo "Please launch script with commit message. (./auto-git.sh <commit-name>)"
    exit 1
fi

git add *
echo "Added -> * (without .gitignore files)"
git commit -m "[AutoScript] $1"
echo "Commit -> Message: $1"
git push
echo "\n\n\n-> Pushed <-"
