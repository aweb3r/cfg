#!/bin/bash

debug=false;
version="0.2";
#fixing installation folder if user is root
if [ $(whoami) = "root" ];
  then
    home="/root";
  else
    home=$HOME;
fi
cfgname=".cfg";
bkpname="backup.cfg";
gitrepo="git@bitbucket.org:durdn/cfg.git";
gitrepo_ro="https://bitbucket.org/durdn/cfg.git";
ignored="install.py|install.pyc|install.sh|.git$|.gitmodule|.gitignore|README|bin";
merge=".atom";

#----debug setup----
#home=$1
#gitrepo=$2;
#------------------

cfg_folder=$home/$cfgname;
backup_folder=$home/$bkpname;

md5prog() {
  if [ $(uname) = "Darwin" ]; then
    md5 -q $1
  fi
  if [ $(uname) = "Linux" ]; then
    md5sum $1 | awk {'print $1'}
  fi
}

link_assets() {
  for asset in $assets ;
  do
    if [ ! -e $home/$asset ];
      then
        #asset does not exist, can just copy it
        echo "N [new] $home/$asset";
        if [ $debug = false ];
          then ln -s $cfg_folder/$asset $home/$asset;
          else echo ln -s $cfg_folder/$asset $home/$asset;
        fi
      else
        #asset is there already
        if [ -d $home/$asset ];
          then
            if [ -h $home/$asset ];
              then echo "Id[ignore dir] $home/$asset";
              else
                if [ $asset = $merge ];
                  then
                    echo "Md[conflict dir] $home/$asset";
                    conflicting=$(ls -A1 $cfg_folder/$asset | xargs);
                    for cf in $conflicting ;
                    do
                      mkdir -p $backup_folder/$asset;
                      mv $home/$asset/$cf $backup_folder/$asset/$cf;
                      ln -s $cfg_folder/$asset/$cf $home/$asset/$cf;
                    done
                  else
                    echo "Cd[conflict dir] $home/$asset";
                    mv $home/$asset $backup_folder/$asset;
                    ln -s $cfg_folder/$asset $home/$asset;
                fi
            fi
          else
            ha=$(md5prog $home/$asset);
            ca=$(md5prog $cfg_folder/$asset);
            if [ $ha = $ca ];
              #asset is exactly the same
              then
                if [ -h $home/$asset ];
                  #asset is exactly the same and as link, all good
                  then echo "I [ignore] $home/$asset";
                  else
                    #asset must be relinked
                    echo "L [re-link] $home/$asset";
                    if [ $debug = false ];
                      then
                        mv $home/$asset $backup_folder/$asset;
                        ln -s $cfg_folder/$asset $home/$asset;
                      else
                        echo mv $home/$asset $backup_folder/$asset;
                        echo ln -s $cfg_folder/$asset $home/$asset;
                    fi
                fi
              else
                #asset exist but is different, must back it up
                echo "C [conflict] $home/$asset";
                if [ $debug = false ];
                  then
                    mv $home/$asset $backup_folder/$asset;
                    ln -s $cfg_folder/$asset $home/$asset;
                  else
                    echo mv $home/$asset $backup_folder/$asset;
                    echo ln -s $cfg_folder/$asset $home/$asset;
                fi
            fi
        fi
    fi
  done
}

download_archive() {
  echo "|* ssh not available downloading zip file from backup repo..."
  curl -LsO https://github.com/durdn/cfg/archive/master.tar.gz
  tar zxvf master.tar.gz
  mv cfg-master $home/.cfg
  rm master.tar.gz
}

echo "|* cfg version" $version
echo "|* debug is" $debug
echo "|* home is" $home
echo "|* backup folder is" $backup_folder
echo "|* cfg folder is" $cfg_folder

if [ ! -e $backup_folder ];
  then mkdir -p $backup_folder;
fi

#clone config folder if not present, update if present
if [ ! -e $cfg_folder ];
  then 
    if [ -z $(command -v ssh) ]
      then
        download_archive
    else
      if [ -z $(command -v git) ]
        then
          download_archive
      else
        #git is available, clone from repo
        echo "|-> git clone from repo $gitrepo"
        git clone $gitrepo $cfg_folder;
        if [ ! -e $cfg_folder ];
          then
            echo "!!! ssh key not installed on Bitbucket for this box, cloning read only repo"
            git clone $gitrepo_ro $cfg_folder
            echo "|* changing remote origin to read/write repo: $gitrepo"
            cd $cfg_folder && git config remote.origin.url $gitrepo
            if [ -e $home/.ssh/id_rsa.pub  ];
              then
                echo "|* please copy your public key below to Bitbucket or you won't be able to commit";
                echo
                cat $home/.ssh/id_rsa.pub
              else
                echo "|* please generate your public/private key pair with the command:"
                echo
                echo "ssh-keygen"
                echo
                echo "|* and copy the public key to Bitbucket"
            fi
        fi
      fi
    fi
  else
    echo "|-> cfg already cloned to $cfg_folder"
    echo "|-> pulling origin master"
    cd $cfg_folder && git pull origin master
fi

assets=$(ls -A1 $cfg_folder | egrep -v $ignored | xargs);
echo "|* tracking assets: [ $assets ] "
echo "|* linking assets in $home"
link_assets
