"""
Migration vers EasyUI (à lancer jeu FERMÉ).

1. Sauvegarde puis fusionne les réglages des anciens addons (Bartender4, Quartz,
   Bagnon, Bagnon_Forever, MoveAnything, Clique) dans EasyUI.lua, pour chaque
   compte et chaque personnage.
2. Déplace les anciens dossiers d'addons hors de Interface\\AddOns (dans
   Interface\\AddOns_desactives_par_EasyUI) pour qu'ils ne se chargent plus.

Rien n'est supprimé : les fichiers d'origine restent en place / dans les sauvegardes.
Usage : python migrer_vers_EasyUI.py [dossier racine du jeu]
"""
import os, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
ADDONS = os.path.join(GAME, "Interface", "AddOns")
DISABLED = os.path.join(GAME, "Interface", "AddOns_desactives_par_EasyUI")
WTF = os.path.join(GAME, "WTF", "Account")

OLD_ADDONS = ["Bartender4", "Quartz", "Bagnon", "Bagnon_Config", "Bagnon_Forever",
              "Bagnon_Tooltips", "Bagnon_GuildBank", "MoveAnything", "Clique", "OmniCC", "OmniCC_Config",
              "Details", "Details_Compare2", "Details_DataStorage", "Details_EncounterDetails",
              "Details_RaidCheck", "Details_Streamer", "Details_TargetCaller", "Details_TinyThreat", "SexyMap"]
ACCOUNT_SV = ["Bartender4", "Quartz", "Bagnon", "Bagnon_Forever", "MoveAnything", "Clique", "OmniCC",
              "Details", "Details_DataStorage", "Details_Streamer", "SexyMap"]
CHAR_SV = ["Bagnon", "Details", "Details_EncounterDetails"]
STAMP = time.strftime("%Y%m%d-%H%M%S")


def game_running():
    try:
        out = subprocess.run(["tasklist"], capture_output=True, text=True, errors="replace").stdout.lower()
        return "arden.exe" in out or "wow.exe" in out
    except Exception:
        return False


def read(path):
    with open(path, "rb") as f:
        data = f.read()
    if data.startswith(b"\xef\xbb\xbf"):
        data = data[3:]
    return data


def merge_dir(sv_dir, names, label):
    """Fusionne <name>.lua dans EasyUI.lua pour un dossier SavedVariables."""
    sources = [n for n in names if os.path.isfile(os.path.join(sv_dir, n + ".lua"))]
    if not sources:
        return
    backup = os.path.join(sv_dir, "_sauvegarde_avant_EasyUI_" + STAMP)
    os.makedirs(backup, exist_ok=True)
    target = os.path.join(sv_dir, "EasyUI.lua")
    parts = []
    if os.path.isfile(target):
        shutil.copy2(target, backup)
        parts.append(read(target))
    for n in sources:
        src = os.path.join(sv_dir, n + ".lua")
        shutil.copy2(src, backup)
        parts.append(b"\n-- importe depuis " + n.encode() + b".lua\n" + read(src))
    with open(target, "wb") as f:
        f.write(b"\n".join(parts))
    # évite une double importation si le script est relancé (copie dans la sauvegarde)
    for n in sources:
        src = os.path.join(sv_dir, n + ".lua")
        os.replace(src, src + ".importe_dans_EasyUI")
    print("  [%s] EasyUI.lua <- %s" % (label, ", ".join(sources)))


def main():
    if game_running():
        print("Le jeu est encore ouvert : ferme-le complètement puis relance ce script.")
        sys.exit(1)
    if not os.path.isdir(os.path.join(ADDONS, "EasyUI")):
        print("EasyUI introuvable dans", ADDONS)
        sys.exit(1)

    print("Réglages :")
    for account in sorted(os.listdir(WTF)):
        acc_dir = os.path.join(WTF, account)
        if not os.path.isdir(acc_dir):
            continue
        merge_dir(os.path.join(acc_dir, "SavedVariables"), ACCOUNT_SV, account)
        for realm in os.listdir(acc_dir):
            realm_dir = os.path.join(acc_dir, realm)
            if not os.path.isdir(realm_dir) or realm == "SavedVariables":
                continue
            for char in os.listdir(realm_dir):
                sv = os.path.join(realm_dir, char, "SavedVariables")
                if os.path.isdir(sv):
                    merge_dir(sv, CHAR_SV, "%s/%s" % (realm, char))

    print("Anciens addons :")
    os.makedirs(DISABLED, exist_ok=True)
    for name in OLD_ADDONS:
        src = os.path.join(ADDONS, name)
        if os.path.isdir(src):
            dst = os.path.join(DISABLED, name)
            if os.path.exists(dst):
                dst = dst + "_" + STAMP
            shutil.move(src, dst)
            print("  déplacé :", name)
    print("Terminé. Lance le jeu : tout est dans EasyUI (/eui).")


if __name__ == "__main__":
    main()
