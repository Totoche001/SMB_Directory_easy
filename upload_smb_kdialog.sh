#!/bin/bash

# Pour executer:
# chmod +x upload_smb_kdialog.sh
# ./upload_smb_kdialog.sh

# === PARAMÈTRES FIXES ===
SERVER="ip"
SHARE="Partage/"
USER="name"
PASSWORD="msp"
DEFAULT_REMOTE_FOLDER="dossier_par_defaut"

# === VÉRIFICATION DES DÉPENDANCES ===
if ! command -v smbclient &> /dev/null || ! command -v kdialog &> /dev/null; then
    kdialog --error "smbclient ou kdialog n'est pas installé."
    exit 1
fi

# === AFFICHAGE DES INFORMATIONS ===
MESSAGE="Souhaitez-vous utiliser les paramètres par défaut ?

📡 Serveur : $SERVER
📂 Partage : $SHARE
👤 Utilisateur : $USER
🗂️ Dossier distant : $DEFAULT_REMOTE_FOLDER

Cliquer sur \"Non\" pour spécifier un autre dossier distant."
kdialog --yesno "$MESSAGE"
if [ $? -eq 0 ]; then
    REMOTE_FOLDER="$DEFAULT_REMOTE_FOLDER"
else
    REMOTE_FOLDER=$(kdialog --inputbox "Entrez le nom du dossier distant (il sera créé s'il n'existe pas) :")
    if [ -z "$REMOTE_FOLDER" ]; then
        kdialog --error "Aucun dossier distant spécifié. Opération annulée."
        exit 1
    fi
fi

# === SÉLECTION DE FICHIERS OU DOSSIERS ===
CHOICE=$(kdialog --title "Sélectionnez fichiers ou dossiers à envoyer" \
                 --getopenfilename ~ "*" --multiple --separate-output)

if [ -z "$CHOICE" ]; then
    kdialog --error "Aucun élément sélectionné."
    exit 1
fi

# === NOM DE L’ARCHIVE PERSONNALISÉE ===
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEFAULT_NAME="upload_${TIMESTAMP}.tar.gz"
ARCHIVE_NAME=$(kdialog --inputbox "Entrez le nom de l'archive à créer :" "$DEFAULT_NAME")

if [ -z "$ARCHIVE_NAME" ]; then
    kdialog --error "Aucun nom d’archive défini. Opération annulée."
    exit 1
fi

# === CRÉATION DU DOSSIER TEMPORAIRE ET COPIE DES FICHIERS ===
TMPDIR=$(mktemp -d)
for path in $CHOICE; do
    rsync -a "$path" "$TMPDIR/" 2>/dev/null
done

# === ARCHIVAGE ===
ARCHIVE_PATH="$TMPDIR/$ARCHIVE_NAME"
tar -czf "$ARCHIVE_PATH" -C "$TMPDIR" .

# === ENVOI VERS LE SERVEUR SMB ===
smbclient "//$SERVER/$SHARE" "$PASSWORD" -U "$USER" <<EOF
mkdir "$REMOTE_FOLDER"
cd "$REMOTE_FOLDER"
put "$ARCHIVE_PATH" "$ARCHIVE_NAME"
quit
EOF

# === NETTOYAGE ===
rm -rf "$TMPDIR"

# === MESSAGE FINAL ===
kdialog --msgbox "✅ Archive envoyée avec succès : $ARCHIVE_NAME\n📁 Dossier distant : //$SERVER/$SHARE/$REMOTE_FOLDER"
