# Architecture fonctionnelle MiSTerFPGA : articulation FPGA / Linux

## 1. Contexte matériel : SoC Intel Cyclone V et carte DE10-Nano
- **SoC Cyclone V SE (5CSEBA6U23I7)** : associe un FPGA (fabric logique, DSP, mémoire embarquée) et un **HPS (Hard Processor System)** intégrant un double cœur ARM Cortex-A9, un contrôleur mémoire DDR3 32 bits, des blocs périphériques (USB OTG, Ethernet, SDIO, UART, I2C, SPI, GPIO) et des ponts de communication bidirectionnels entre HPS et FPGA.
- **Mémoire** : 1 Go de DDR3 connecté nativement au contrôleur mémoire du HPS (cadencé jusqu'à 400 MHz). Le FPGA peut y accéder via les ponts à haut débit (FPGA-to-HPS SDRAM bridge) ou au débit réduit (lightweight HPS-to-FPGA bridge) selon les besoins. Le FPGA dispose également de blocs SRAM internes (M10K/M20K) et peut utiliser des extensions SDRAM/SDRAM duales optionnelles branchées sur le connecteur GPIO.
- **Stockage primaire** : carte microSD (interfacée au HPS via SDIO), utilisée pour booter U-Boot, Linux, charger l'exécutable MiSTer et stocker les cœurs (.rbf), images disque, ROMs, etc.
- **Connectivité** : port micro-USB OTG (utilisé avec un hub USB dans la configuration MiSTer pour accueillir périphériques HID, sticks, adaptateurs audio) et port Ethernet 10/100, tous deux gérés directement par le HPS.
- **Extension MiSTer** : l'I/O board et d'autres cartes (USB hub, SDRAM, Analog IO, Digital IO, MT32-Pi, BlisSTer) se connectent principalement aux ports GPIO du FPGA. Elles ajoutent des sorties vidéo analogiques, audio, TOSLINK, ports SNAC, boutons, capteurs, etc. Ces extensions sont pilotées par la logique FPGA ; Linux n'interagit qu'indirectement via la configuration envoyée à cette logique.

## 2. Empilement logiciel MiSTer sur le processeur ARM
1. **Boot** : U-Boot configure le HPS, charge le noyau Linux et un initramfs. Linux (généralement basé sur mainline 5.x patché) se lance en mode multi-utilisateur minimal.
2. **Services de base** : démarrage de `MiSTer` (application en C++), de `MiSTer.ini` parser, du serveur FTP/Samba optionnel, de scripts d'auto-update, de `MiSTer` menu UI. Les modules noyau standards gèrent USB HID, mass storage, réseau, ALSA, framebuffer Linux.
3. **Communication HPS ↔ FPGA** : l'application MiSTer ouvre /dev/mem et les ressources UIO exposées par le framework (`sys/`), mappe les ponts HPS↔FPGA et les registres CSR (Control and Status Registers) du framework. Les canaux principaux sont :
   - **Lightweight HPS-to-FPGA bridge (LW H2F)** pour les registres de contrôle (écriture configuration, triggers).
   - **High-performance FPGA-to-HPS SDRAM bridge (F2H)** pour le transfert de blocs (framebuffer, samples audio, captures mémoire).
   - **Interrupts** : le FPGA peut signaler des événements (fin de lecture SD, données prêtes) via les lignes IRQ du HPS.
4. **Gestion des fichiers** : Linux monte la carte SD, partitions exFAT/EXT4, les partages réseau (CIFS/NFS) et fournit un système de fichiers POSIX à l'application MiSTer, qui lit/écrit les ROMs, snapshots, configurations puis transfère ces flux au FPGA (via DMA ou trames chunkées dans la SDRAM partagée).
5. **Entrées/sorties** : les pilotes Linux pour USB HID/Ethernet/MIDI exposent des événements à l'application MiSTer, qui les convertit en messages à destination de la logique FPGA (portes joystick, clavier PS/2 virtuel, MIDI, etc.).

## 3. Répartition fonctionnelle MiSTer
### 3.1 Logique implémentée dans le FPGA (HDL)
- Re-création du matériel cible : CPU(s) et PPU/GPU vintage, contrôleurs DMA, timers, contrôleurs d'entrées, générateurs audio, etc., synchronisés cycle-par-cycle.
- Gestion temps réel des vidéos (HDMI, analogique via scaler intégré), audio (I2S, SPDIF), synchronisation vertical blank.
- Contrôle des cartes d'extension (niveau logique) : ADC pour entrée lumière, SNAC, R2R DAC, générateur PWM audio analogique, DAC vidéo analogique.
- Buffers vidéo / audio / RAM spécifiques (SDRAM externe 32 ou 128 Mo) accessibles uniquement depuis la logique FPGA pour reproduire la mémoire d'origine.

### 3.2 Fonctions déléguées au Linux du HPS
- **Chargement dynamique des cœurs** : programmation du FPGA (fichiers .rbf) via le contrôleur FPGA Manager et gestion des resets.
- **Gestion du système de fichiers** : lecture/écriture des ROMs, disques virtuels, sauvegardes, snapshots, configuration, scripts.
- **Interface utilisateur** : rendu du menu OSD (via framebuffer partagé), mapping des contrôles, configuration (résolution, audio, scanlines), téléchargements réseau.
- **Pilotes & protocoles** : USB HID, Bluetooth (via dongle), Ethernet/Wi-Fi (dongle), MIDI USB, fichiers réseau, NTP, services update.
- **Traitements non déterministes / lourds** : décompression d'archives, traitement audio/vidéo non temps réel (captures, enregistrement), conversions de formats, configuration du scaler.
- **Sécurité et supervision** : watchdog logiciel, monitoring de température, mise à jour du noyau et du framework, scripts de maintenance.

### 3.3 Ressources réservées au processeur ARM/HPS
- **DDR3 1 Go** : majoritairement utilisé par Linux (kernel, initramfs, caches, buffers). Une fenêtre est exposée au FPGA, mais la gestion de la mémoire est orchestrée par le HPS.
- **Contrôleurs USB OTG et Ethernet** : pilotes Linux uniquement ; la logique FPGA n'y accède pas directement.
- **Contrôleur SDIO + microSD** : géré par Linux pour le stockage principal.
- **Caches L1/L2, SRAM on-chip HPS (256 Ko)** : accessibles au HPS uniquement.
- **Périphériques internes HPS (UART, I2C, timers HPS)** : utilisés par Linux pour console série, RTC externe, etc.

### 3.4 Ressources partagées ou arbitrées
- **Ponts HPS-FPGA** : bus AXI synchronisés offrant des accès mémoires croisés. Nécessitent une planification soigneuse (gestion de latence) pour ne pas perturber les timings du cœur.
- **DDR3 via F2H/H2F** : utilisée par les cœurs pour framebuffer, captures, transferts de fichiers. L'arbitrage est assuré par le contrôleur mémoire du HPS.
- **IRQ partagées** : plusieurs événements FPGA peuvent remonter via un nombre limité de lignes d'interruption.
- **GPIO communs** : certains signaux (boutons utilisateur, LEDs) sont multiplexés entre HPS et FPGA.
- **I²C HPS ↔ FPGA** : utilisé pour configurer des DAC/ADC sur l'I/O board ; Linux initie souvent la configuration, puis le FPGA génère les signaux temps réel.

### 3.5 Ressources dédiées au FPGA
- **SDRAM externe (32/64/128 Mo)** : module optionnel connecté au FPGA uniquement, fournissant une mémoire à faible latence adaptée aux systèmes rétro.
- **LVDS/HDMI PHY** : sortie vidéo pilotée directement par la logique FPGA (scaler, TMDS encoder).
- **GPIO haute vitesse** : destinés aux cartes SNAC, adaptateurs périphériques en temps réel.

## 4. Flux de données type (exemple : chargement d'un jeu)
1. L'utilisateur sélectionne un cœur dans le menu MiSTer ; l'application Linux appelle `fpga_load()` pour flasher le .rbf via le FPGA Manager.
2. Le cœur expose des registres dans `sys/` (CSR). L'application MiSTer écrit la configuration initiale (horloges, région, mémoire) via le pont LW H2F.
3. Lors du chargement d'une ROM, Linux lit le fichier sur la microSD ou le réseau, le copie en DDR3 et déclenche un transfert DMA vers la SDRAM externe du FPGA ou vers une RAM interne en stream via F2H.
4. Les entrées utilisateur (USB HID) sont reçues par Linux, converties en événements et envoyées au FPGA par écriture dans les registres d'entrée.
5. Le FPGA génère les signaux audio/vidéo ; le scaler intégré peut écrire dans un framebuffer en DDR3, que Linux peut lire pour des captures ou streaming.

## 5. Contraintes et choix de conception
- **Temps réel vs. système d'exploitation** : toutes les tâches nécessitant une précision sub-cycle sont sur FPGA ; Linux gère les interactions asynchrones. Cela évite les jitter/latences introduits par un OS non temps réel.
- **Simplicité de portage** : conserver un framework commun (`sys/`) permet aux développeurs HDL de se concentrer sur la logique du cœur tandis que Linux expose une API stable (fichiers, contrôleurs, menu, scripts).
- **Extensibilité matérielle** : l'utilisation des headers GPIO permet d'ajouter des cartes (SDRAM, IO analogique) contrôlées par le FPGA, sans complexifier le Linux embarqué.
- **Mise à jour continue** : Linux gère les mises à jour OTA, la synchronisation réseau, la gestion des sauvegardes sur des systèmes de fichiers modernes.
- **Séparation des responsabilités** : le HPS offre la souplesse (USB, réseau, stockage), le FPGA garantit la fidélité temporelle des cœurs.

## Questions ouvertes / Points à approfondir
- Cartographie exacte des adresses utilisées par chaque pont (varie selon les versions du framework MiSTer).
- Profil de bande passante maximal exploitable par les cœurs via le pont F2H SDRAM selon la fréquence effective.
- Détails sur les optimisations logicielles (pré-chargement, compression) introduites par les scripts MiSTer récents.
- Interaction précise entre Linux et le scaler FPGA pour les fonctions de capture vidéo ou de filtres post-traitement.
