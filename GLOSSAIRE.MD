# Glossaire du coeur modèle MiSTer FPGA

Ce glossaire rassemble les termes techniques rencontrés dans les commentaires et composants du coeur modèle. Chaque entrée explique brièvement le rôle ou le principe évoqué.

- **Ascal** : Nom du scaler vidéo matériel développé pour MiSTer, capable de convertir les résolutions originales des coeurs vers des sorties modernes tout en gérant divers filtres de mise à l'échelle.
- **PLL (Phase-Locked Loop)** : Boucle à verrouillage de phase utilisée dans les FPGA pour générer des horloges internes stables à partir d'une source de référence.
- **Filtrage bilinéaire** : Méthode de mise à l'échelle qui interpole linéairement l'image entre deux axes afin d'adoucir les pixels lorsqu'on change de résolution.
- **Sharp bilinear** : Variante du filtrage bilinéaire qui conserve davantage de netteté en limitant l'adoucissement excessif tout en réduisant l'effet d'escalier.
- **Filtrage bicubique** : Technique d'interpolation utilisant un polynôme cubique sur plusieurs pixels voisins pour obtenir une mise à l'échelle plus douce et précise.
- **Filtrage polyphase** : Méthode de mise à l'échelle basée sur plusieurs phases de filtres FIR pour obtenir une interpolation fine et configurable selon le ratio d'agrandissement.
- **OSD (On-Screen Display)** : Superposition graphique affichée par le coeur pour configurer le système ou fournir des informations sans quitter la sortie vidéo.
- **CRT (Cathode Ray Tube)** : Moniteur à tube cathodique, souvent utilisé comme cible d'affichage rétro pour reproduire le rendu d'époque.
- **VGA (Video Graphics Array)** : Interface vidéo analogique à 15 broches fréquemment utilisée sur MiSTer pour fournir un signal RGBHV vers des écrans ou moniteurs CRT.
- **DAC (Digital-to-Analog Converter)** : Convertisseur numérique-analogique, utilisé par exemple pour produire des sorties audio ou vidéo analogiques à partir de données numériques du FPGA.
- **SDIO (Secure Digital Input Output)** : Interface de communication utilisée pour dialoguer avec des cartes SD ; dans MiSTer elle permet l'accès au stockage ou aux périphériques via le port SD interne.
- **HPS (Hard Processor System)** : Sous-système processeur ARM intégré au SoC Cyclone V du MiSTer, chargé des tâches système comme le chargement des coeurs et la gestion Linux.
- **M10K / M20K** : Types de blocs de mémoire embarqués (10 kbits ou 20 kbits) disponibles dans les FPGA Intel, utilisés pour implémenter des buffers ou ROM internes.
- **Fichier `.RBF`** : Binaire de configuration produit par Quartus pour programmer le FPGA du MiSTer avec un coeur donné.
- **SDRAM MiSTer** : Mémoire SDR SDRAM externe montée sur le module d'extension (généralement 32 Mo ou 128 Mo) servant à émuler la RAM des systèmes originaux lorsque la mémoire embarquée ne suffit pas.
- **MT32-Pi** : Projet associant un Raspberry Pi et un logiciel synthétiseur pour reproduire le module sonore Roland MT-32 via le port USB ou GPIO du MiSTer.
- **BlisSTer** : Carte d'extension pour MiSTer fournissant des ports de manettes originaux à faible latence et un hub USB additionnel.
- **LW H2F (Lightweight Host-to-FPGA)** : Interface mémoire légère reliant le HPS au tissu FPGA pour échanger des registres ou des commandes à faible bande passante.
- **F2H (FPGA-to-HPS)** : Canal de communication permettant au FPGA d'accéder aux ressources du HPS, par exemple pour signaler des événements ou lire des données.
- **NTP (Network Time Protocol)** : Protocole réseau utilisé pour synchroniser l'horloge système du HPS avec une référence externe.
- **I2S (Inter-IC Sound)** : Bus audio numérique série employé pour transporter des flux PCM entre le FPGA et des convertisseurs audio externes.
- **SNAC (Serial Native Accessory Converter)** : Interface de MiSTer offrant une connexion directe et sans conversion aux manettes originales pour obtenir une latence minimale.
- **SPDIF (Sony/Philips Digital Interface)** : Interface audio numérique permettant de transporter un signal PCM ou compressé via fibre optique ou coaxial.
- **R2R (Resistor-to-Resistor DAC)** : Réseau de résistances en échelle utilisé comme DAC simple, souvent pour générer des sorties vidéo analogiques RGB.
- **ADC (Analog-to-Digital Converter)** : Convertisseur analogique-numérique qui capture des signaux analogiques (par exemple audio) pour traitement dans le FPGA.
- **CEA (Consumer Electronics Association)** : Organisation ayant défini des normes vidéo HDMI (CEA-861) ; référence pour les modes vidéo compatibles TV.
- **BOB_DEINT** : Mode de désentrelacement « bob » appliqué par le scaler pour doubler les lignes d'une source entrelacée en alternant les trames.

