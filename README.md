# Distance Transports

Application React + Vite qui classe une liste d'adresses selon la facilité réelle d'accès en transports depuis une **adresse de départ unique**.

## Principe

1. Saisir une adresse de référence : elle est **toujours le départ**.
2. Coller 1 à 20 adresses de destination, une par ligne.
3. Géocoder les adresses via BAN / IGN.
4. Calculer plusieurs itinéraires réels en transports via Transitous / MOTIS.
5. Choisir pour chaque destination l'itinéraire le plus adapté aux priorités du projet.
6. Classer les destinations par recommandation.

## Filtre de zone

Avant le calcul, le sélecteur **« Zone des destinations à calculer »** limite les itinéraires à :

- **Paris** (codes postaux 75) ;
- **Île-de-France** (75, 77, 78, 91, 92, 93, 94, 95) ;
- **Toutes** (aucun filtre, par défaut).

Le tri se fait d'abord sur le code postal saisi, sans appel réseau ; une adresse sans code postal est géocodée puis vérifiée. Les adresses écartées ne sont pas calculées et sont listées au-dessus des résultats. Le choix est mémorisé dans le navigateur.

## Critères de recommandation

Chaque destination reçoit un **coût généralisé** exprimé en « minutes ressenties » (plus bas = mieux) :

| Élément | Poids |
| --- | --- |
| minute assis dans un véhicule | × 1 |
| minute de marche (départ, arrivée, correspondances) | × 1,8 |
| minute d'attente en correspondance | × 1,5 |
| minute d'attente au premier arrêt | × 1 |
| chaque véhicule pris | + 5 min |
| chaque correspondance | + 8 min |
| distance à vol d'oiseau (critère secondaire) | + 0,3 min / km |

- **Horaire de référence fixe** : les itinéraires sont calculés pour le prochain jour ouvré à 9 h (heure de Paris), et non à l'heure du clic, pour un classement reproductible.
- **Fréquence des lignes** : on simule un voyageur prêt à partir à n'importe quelle minute de l'heure qui suit ; il prend l'option la moins coûteuse (attente comprise). Le coût retenu est la moyenne : une ligne rapide mais rare est pénalisée par son attente moyenne.
- **Marche directe** : le trajet à pied calculé par MOTIS est mis en concurrence avec les transports. Une destination à 15 min à pied n'est plus battue par un bus qui impose presque autant de marche.

## Fiabilité

- **Géocodage validé** : le code postal et la ville saisis sont comparés aux candidats IGN, les adresses précises (numéro/voie) et le score IGN sont privilégiés, et un rattachement manifestement faux est rejeté avec un message clair.
- **Résilience réseau** : les appels BAN / MOTIS ont un délai maximal, des nouvelles tentatives (5xx / 429 / réseau) et un cache (mémoire + `localStorage`).
- **Cache compact** : seul l'itinéraire retenu (≈ 1 Ko) est mis en cache, pas la réponse brute de MOTIS (300 à 500 Ko). Le cache se purge au démarrage (entrées expirées et anciennes) et libère de la place si le quota du `localStorage` est atteint ; les champs du formulaire sont enregistrés sans jamais faire planter l'application.
- **Repli marche** : si aucun transport n'est pertinent (destination proche), un trajet à pied raisonnable est proposé au lieu d'une erreur.
- **Classement honnête** : le rang est partagé en cas d'égalité (mention « ex æquo ») et le pourcentage affiché est un **percentile relatif au lot comparé**, jamais une note absolue.
- **Débit Transitous respecté** : Transitous limite le débit par client (≈ 1 requête / 3 s après une rafale). Les destinations sont d'abord toutes géocodées (4 en parallèle), puis les itinéraires sont calculés 2 par 2, avec un délai de 45 s et des nouvelles tentatives espacées (`Retry-After` respecté). Compter ~1 min pour 30 destinations.
- **Jusqu'à 50 destinations calculées** à la fois, après filtre de zone.

## Carte des résultats

Après le calcul, une carte (Leaflet + OpenStreetMap) affiche l'adresse de départ et chaque destination classée :

- repères numérotés par rang, colorés selon le percentile (★ = meilleure, vert, bleu, gris) ;
- clic sur un repère : résumé du trajet retenu, tracé départ → destination et bouton « Voir la fiche » ;
- bouton « Voir sur la carte » sur chaque fiche pour centrer la carte sur la destination.
- mise en page pleine largeur : sur grand écran, la carte reste fixe à gauche pendant que la liste défile à droite (survoler une fiche met son repère en évidence) ; sous 1100 px, une seule colonne avec la carte au-dessus.

## Coller un texte (extraction d'adresses)

Le bouton **« Coller un texte »** analyse un texte libre (par ex. une fiche Doctolib) et détecte les adresses postales :

- voie et code postal / ville sur deux lignes successives ;
- adresse complète sur une seule ligne (« 67 Rue Voltaire 92300 Levallois-Perret ») ;
- préfixe avant la voie (« Adresse : 12, rue Bellot, 75019 Paris », nom d'établissement…) ;
- numéros `bis` / `ter` / `quater` / `B`, plages (« 7-11 » → « 7 »), mentions `CEDEX`, principaux types de voie ;
- abréviations développées pour le géocodeur (`bd`, `bld`, `bvd` → boulevard, `av` → avenue) ;
- voie sans numéro ou précédée d'un nom de lieu juste avant la ligne « code postal ville » (« Lycée X Avenue du 11 novembre ») ;
- compléments retirés : `BP`, `CS`, bâtiment, étage, « code porte »… (un n° de BP n'est jamais pris pour un code postal) ;
- listes longues : plus de limite à 20 à l'extraction (500 au plus) ; le filtre de zone choisit ensuite ce qui est calculé.

Les adresses détectées sont dédoublonnées puis ajoutées au champ « Adresses de destination ». L'extraction ne gère pas les lieux-dits, les adresses sans numéro (sauf après « Adresse : ») ni les adresses hors de France ; c'est ensuite le géocodage qui valide chaque adresse.

## Sources

- Géocodage : https://data.geopf.fr/geocodage/search
- Routage transports : https://transitous.org/
- Moteur MOTIS : https://github.com/motis-project/motis
- Données cartographiques : OpenStreetMap
- Vérification utilisateur : liens Google Maps et Citymapper

Transitous est utilisé pour ce projet open-source non commercial conformément à sa politique d'utilisation.

## Développement

```bash
npm install
npm run dev
```

Build :

```bash
npm run build
```

## Tests

```bash
npm test              # suite de tests
npm run test:coverage # rapport de couverture
```

Les tests couvrent le géocodage (validation, cache, erreurs), le routage (coût, repli marche), le classement (rang, ex æquo, percentile, parallélisation), la couche HTTP (timeout, retry, cache), le cache, la construction des liens Google Maps / Citymapper et l'extraction d'adresses depuis un texte.

## GitHub Pages

Le workflow `.github/workflows/deploy-pages.yml` construit et déploie automatiquement `main`.

URL : https://brahmiamine.github.io/distance/

## Hébergement VPS — distance.clubika.com

Le site est servi à la racine de **https://distance.clubika.com**, dans le
conteneur `distancecalc-web`, sur le réseau existant `clubika_internal`, derrière
le Caddy partagé de Clubika. Aucun port public supplémentaire ni base de données
n'est nécessaire. Les appels IGN et Transitous partent du navigateur.

L'image `server/Dockerfile` installe les dépendances avec `npm ci`, exécute les
tests, compile le site puis sert `dist/` avec Caddy sur le port interne 8080.
`GET /healthz` répond `ok`. Les fichiers compilés sous `/assets/` sont mis en cache
pendant un an ; le document HTML est revalidé à chaque visite.

Installation sur le VPS, une fois ces fichiers présents sur `origin/main` et le
DNS `distance.clubika.com` dirigé vers ce serveur :

```bash
cd ~/repos/distanceCalc
git pull --ff-only origin main
bash deploy/install-vps.sh
```

Le script prend le verrou du déploiement existant, construit et vérifie le
conteneur, sauvegarde les configurations dans `~/deploy/backups/`, valide et
recharge Caddy, puis vérifie le site en HTTPS. Il ajoute ensuite `distanceCalc`
à `~/deploy/auto-deploy.sh`, avec un contrôle de santé adapté au site statique.
Les commits suivants sur `main` seront déployés par `app-deploy.timer`, avec
retour à la version précédente si le build ou le contrôle de santé échoue.

La CI `ci.yml` construit l'image (tests inclus), démarre le serveur et vérifie
la page HTML ainsi que son fichier JavaScript. Le workflow GitHub Pages garde
explicitement sa base `/distance/` ; le build VPS utilise `/`.

## Important

Les itinéraires sont calculés au moment de la recherche et peuvent donc varier avec les horaires et les données de transport disponibles.
