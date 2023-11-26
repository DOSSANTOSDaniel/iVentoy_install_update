#!/bin/bash
#************************************************#                    
# Auteur:  <dossantosjdf@gmail.com>              
# Date:    26/11/2023                                                               
#                                                
# Rôle:                                          
# Ce script permet d'automatiser l'intallation et la mise à jour d'iVentoy.
#
# Usage:   ./upinst_iventoy.sh
#************************************************#

# Variables ###
local_user="$USER"
work_directory="$HOME"

iv_dir_regex="iventoy-[0-9]*\.[0-9]*\.[0-9]*$"
found_iv_dir=""

gh_iv_user='ventoy'
gh_api_base='https://api.github.com'
gh_v3_accept='Accept: application/vnd.github.symmetra-preview+json'

iv_latest_release="$(curl -s -f -H "${gh_v3_accept}" "${gh_api_base}/repos/${gh_iv_user}/PXE/releases" | jq -r .[0].assets[].browser_download_url | grep "linux")"
iv_latest_sha="$(curl -s -f -H "${gh_v3_accept}" "${gh_api_base}/repos/${gh_iv_user}/PXE/releases" | jq -r .[0].assets[].browser_download_url | grep "sha256.txt")"

new_gh_targz="$(basename "$iv_latest_release")"
new_iv_dir="$(echo "$new_gh_targz" | awk -F '-linux-' '{print $1}')"

gh_latest_ver="$(basename "$iv_latest_release" | cut -d'-' -f2 | tr -d '.')"

# Functions ###
Check_Extract_iVentoy() {
  echo -e "\n Vérification de la somme de contrôle \n"
  check_sum_sha="$(grep 'linux' "${work_directory}/sha256.txt" | awk '{print $1}')"
  check_sum_tar="$(sha256sum "${work_directory}/${new_gh_targz}" | awk '{print $1}')"

  if [[ "$check_sum_sha" != "$check_sum_tar" ]]
  then
    echo "La validation de la somme de contrôle du fichier ${work_directory}/${new_gh_targz} a échoué !!!"
    exit 1
  else
    echo "Validation de la somme de contrôle sha256 Réussie !!!"
  fi
  echo -e "\n Décompression du fichier ${work_directory}/${new_gh_targz} \n"
  tar xzvf "${work_directory}/${new_gh_targz}" -C "${work_directory}"
  rm "${work_directory}"/{"${new_gh_targz}",sha256.txt}
}

Create_Info_File() {
  echo -e "\n Création du fichier d'informations ${work_directory}/${new_iv_dir}/.iventoy-infos \n"
  
  {
  echo "Install_date $(date)"
  echo "Install_User $local_user"
  echo "Install_Directory $work_directory"
  echo "iVentoy_Name_Directory $new_iv_dir"
  echo "iVentoy_Version_id $gh_latest_ver"
  } > "${work_directory}/${new_iv_dir}/.iventoy-infos"
}

InstallIventoy() {
  echo -e "\n Installation d'iVentoy \n"
  if wget -P "$work_directory" "$iv_latest_release" "$iv_latest_sha"
  then
    Check_Extract_iVentoy
    Create_Info_File
  else
    echo "Erreur de téléchargement URLs: $iv_latest_release  $iv_latest_sha"
    exit 1
  fi
}

UpdateIventoy() {
  echo -e "\n Mise à jour d'iVentoy \n"
  if wget -P "$work_directory" "$iv_latest_release" "$iv_latest_sha"
  then
    Check_Extract_iVentoy
    echo -e "\n Copie des données de configuration vers le nouveau dossier ${work_directory}/${new_iv_dir}/data/ \n"
    if [[ -f "${work_directory}/${iv_local_dir}/data/config.dat" ]]
    then
      cp "${work_directory}/${iv_local_dir}/data/config.dat" "${work_directory}/${new_iv_dir}/data/config.dat"
    fi
    mv "${work_directory}/${iv_local_dir}/iso" "${work_directory}/${new_iv_dir}"
    Create_Info_File
    echo -e "\n Création d'un dossier de sauvegarde de l'ancienne version d'iVentoy dans :${work_directory}/iVentoy_Backup \n"
    mkdir -p "${work_directory}/iVentoy_Backup"
    mv "${work_directory}/${iv_local_dir}" "${work_directory}/iVentoy_Backup/${iv_local_dir}_$(date +%F_%H%M%S)_old"
  else
    echo "Erreur de téléchargement URLs: $iv_latest_release  $iv_latest_sha"
    exit 1
  fi
}

ReconfIventoy() {
  echo -e "\n Un dossier de iVentoy existe déjà !, reconfiguration du dossier \n"
  
  iv_found_id="$(basename "$found_iv_dir" | awk -F '-' '{print $2}' | tr -d '.')"
  iv_found_relative_path="$(basename "$found_iv_dir")"
  
  echo -e "\n Création du fichier d'informations ${found_iv_dir}/.iventoy-infos \n"
  
  {
  echo "Check_date $(date)"
  echo "Check_User $local_user"
  echo "Directory $work_directory"
  echo "iVentoy_Name_Directory $iv_found_relative_path"
  echo "iVentoy_Version_id $iv_found_id"
  } > "${found_iv_dir}/.iventoy-infos"
  
  $0
}

Rename_Other_File() {
  mkdir -p "${work_directory}/iVentoy_Backup"
  
  old_basename="$(basename "$found_iv_dir")"
  new_basename="${old_basename}_$(date +%F_%H%M%S)_bak"
  
  echo -e "\n Le dossier d'installation $old_basename n'est pas approprié ! \n"
  echo -e "\n Le dossier $old_basename sera renomé en $new_basename !!! \n"

  mv "${work_directory}/${old_basename}" "${work_directory}/iVentoy_Backup/${new_basename}"
}

End_Config() {
  echo -e "\n Fin du script / Informations !!! \n"
  if [[ -z "$found_iv_dir" || -n ${new_iv_dir} ]]
  then
    cat "${work_directory}/${new_iv_dir}/.iventoy-infos"
  else
    cat "${found_iv_dir}/.iventoy-infos"
  fi
  exit 0
}

# Main ###
for dir in "${work_directory}"/*
do
  if [[ "$dir" =~ ${work_directory}/${iv_dir_regex} ]]
  then
    found_iv_dir="$dir"
    break
  fi
done

if [[ -z "$found_iv_dir" ]]
then
  InstallIventoy
else
  if [[ -n $(ls "$found_iv_dir") ]]
  then
    size_iv_dir="$(du -sk "$found_iv_dir" | awk '{print $1}')"
    if [[ "$size_iv_dir" -lt '26244' ]]
    then
      Rename_Other_File
      InstallIventoy
    else
      if [[ -f "${found_iv_dir}/.iventoy-infos" ]]
      then
        iv_local_version="$(grep 'iVentoy_Version_id' "${found_iv_dir}/.iventoy-infos" | awk '{print $2}')"
        iv_local_dir="$(grep 'iVentoy_Name_Directory' "${found_iv_dir}/.iventoy-infos" | awk '{print $2}')"
        if [[ "$gh_latest_ver" -gt "$iv_local_version" ]]
        then
          UpdateIventoy
        else
          echo -e "\n Votre version d'iVentoy est déjà à jour ! \n"
          End_Config
        fi
      else
        ReconfIventoy
      fi
    fi
  else
    Rename_Other_File
    InstallIventoy
  fi
fi
End_Config
