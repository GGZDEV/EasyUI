# EasyUI

Interface tout-en-un pour World of Warcraft 3.3.5 : barres d'action, cadres d'unité et de raid,
barres d'incantation, temps de recharge, compteur de dégâts, sacs, cadres Blizzard, minimap,
courrier, messagerie, hôtel des ventes et click-casting, réglés depuis un seul panneau.

## Installation

Copier les dossiers `EasyUI` et `EasyUI_*` dans `Interface/AddOns` du jeu, puis relancer le jeu.

## Commandes

- `/eui` : ouvrir / fermer le panneau
- `/eui edit` : mode édition (déplacer l'interface, grille, aimantation)
- `/eui lock` : tout verrouiller
- `/eui <page>` : ouvrir une page (barres, incantation, recharge, sacs, cadres, clique, profils, options)
- `/eui reset` : recentrer la fenêtre

## Modules

| Dossier | Module |
| --- | --- |
| `EasyUI` | Cœur : panneau, mode édition, cadres d'unité et de raid |
| `EasyUI_Bars` | Barres d'action |
| `EasyUI_Castbars` | Barres d'incantation |
| `EasyUI_Cooldowns` | Temps de recharge |
| `EasyUI_Damage` | Compteur de dégâts |
| `EasyUI_Bags` | Sacs |
| `EasyUI_Frames` | Cadres Blizzard |
| `EasyUI_Minimap` | Minimap |
| `EasyUI_Mail` | Courrier |
| `EasyUI_Chat` | Messagerie |
| `EasyUI_Auction` | Hôtel des ventes |
| `EasyUI_Clique` | Click-casting |

Chaque module s'active ou se désactive depuis le tableau de bord (`/eui`), au prochain rechargement.
