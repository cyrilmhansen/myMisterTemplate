# Analyse de la construction de la sortie HDMI

## Chaîne de traitement HDMI
- Les signaux vidéo du cœur (`r_out/g_out/b_out`, sync, etc.) passent d'abord par le module de scanlines commun, ce qui permet d'injecter les lignes d'assombrissement demandées par le cœur avant toute autre transformation.【F:sys/sys_top.v†L1356-L1374】
- Le scaler `ascal` consomme ensuite ces signaux et fournit l'image vers le domaine HDMI en appliquant les paramètres de synchronisation programmés, en gérant l'option de gel (`HDMI_FREEZE`), le masquage (`HDMI_BLACKOUT`) et le désentrelacement BOB (`HDMI_BOB_DEINT`) exposés par le cœur.【F:sys/sys_top.v†L720-L803】【F:sys/sys_top.v†L1743-L1760】
- L'étape suivante est spécifique HDMI : le module `shadowmask` autorise l'application d'un masque CRT configurable (taille, rotation, gains RGB), ce qui n'affecte pas la sortie VGA analogue.【F:sys/sys_top.v†L1128-L1152】【F:sys/shadowmask.sv†L1-L134】
- Le module `osd` overlay reçoit ensuite les commandes du HPS et compose l'OSD en temps réel dans le flux HDMI. Une version distincte du même module sert pour la sortie VGA afin de partager la mémoire d'OSD.【F:sys/sys_top.v†L1155-L1175】【F:sys/osd.v†L4-L200】
- Enfin, le multiplexeur « direct video » permet, en fonction de `direct_video` et de l'utilisation du framebuffer VGA, de court-circuiter le scaler et de sortir directement le flux vidéo natif ou le flux scalé avec OSD/mask.【F:sys/sys_top.v†L1237-L1299】

## Fonctions offertes par le scaler ASCAL
- `ascal` prend en charge des sorties à format arbitraire, détecte automatiquement la taille d'image, traite les flux progressifs ou entrelacés et propose plusieurs filtres (nearest, bilinear, sharp bilinear, bicubic, polyphase) ainsi que le downscale (nearest/bilinear). Il intègre un tampon triple optionnel et un mode faible latence piloté par le HPS.【F:sys/ascal.vhd†L11-L133】
- L'instance cadre l'image en respectant les timings H/V (HTotal, VTotal, périodes de sync/blanking) et autorise des recadrages via `hmin/hmax` et `vmin/vmax`, calculés suivant l'aspect recherché ou un framebuffer logiciel.【F:sys/sys_top.v†L720-L764】【F:sys/sys_top.v†L880-L919】
- Le HPS configure `WIDTH`, `HEIGHT`, timings et pixel repetition (`HDMI_PR`) par la commande 0x20 sur le bus IO, tandis que d'autres commandes activent freescaling, filtres, coefficients polyphase ou framebuffer logiciel, ce qui laisse la place à de nombreux modes HDMI (ex. 720p, 1080p, VRR).【F:sys/sys_top.v†L367-L460】
- Le bloc `pll_cfg_hdmi` et `pll_hdmi_adj` gèrent dynamiquement la PLL HDMI pour s'aligner sur ces modes et, en option, appliquer l'ajustement faible latence fourni par le scaler (`lltune`).【F:sys/sys_top.v†L1027-L1099】【F:sys/sys_top.v†L958-L969】

## Gestion de l'OSD (interaction HPS ↔ FPGA)
- Le module `osd` contient une RAM interne où le HPS écrit par commandes SPI (0x20 pour les bitmaps, 0x40 pour activer/positionner). Les données sont enregistrées côté `clk_sys`, puis relues dans le domaine vidéo avec un générateur de CE pour se synchroniser sur le flux.【F:sys/osd.v†L35-L200】
- Dans `sys_top`, l'OSD HDMI est activé quand `io_osd_hdmi` (chip select issu du HPS) est actif, en partageant `io_strobe/io_din` avec le module `hps_io`. L'OSD VGA réutilise les mêmes données, ce qui garantit que Linux n'a qu'une surface à maintenir.【F:sys/sys_top.v†L248-L281】【F:sys/sys_top.v†L1155-L1175】【F:sys/sys_top.v†L1376-L1397】

## Comparaison HDMI ↔ VGA
- HDMI dispose de fonctionnalités spécifiques : masque CRT (`shadowmask`), possibilité de black-out numérique quand un framebuffer logiciel prend la main, et sortie directe des flux numériques (`direct_video`).【F:sys/sys_top.v†L1128-L1175】【F:sys/sys_top.v†L1237-L1299】
- Le chemin VGA ajoute des blocs analogiques absents du HDMI : encodeur Y/C (`yc_out`), génération de sous-porteuse, conversion YPbPr/CSync et option de renvoyer l'image scalée HDMI vers la sortie analogique (`vga_scaler_out`).【F:sys/sys_top.v†L1400-L1497】
- Les deux sorties partagent le module de scanlines et l'OSD, donc un effet configuré par le cœur se reflète sur les deux sorties en même temps.【F:sys/sys_top.v†L1356-L1374】【F:sys/sys_top.v†L1155-L1175】

## Résolutions supportées et modes HDMI
- Les paramètres initiaux correspondent au 1920×1080@60 (CEA) avec pixel clock 148,5 MHz, mais le HPS peut reprogrammer largeur, hauteur, front/back porch et sync pour toute résolution respectant les limites matérielles.【F:sys/sys_top.v†L1027-L1036】【F:sys/sys_top.v†L367-L436】
- `ascal` dimensionne ses buffers pour une largeur maximale par défaut de 2304 pixels (paramètre `OHRES`), ce qui couvre 1080p, 1200p, 1440p non entrelacés. Les hauteurs peuvent atteindre 12 bits (4095) tant que la PLL HDMI reste dans sa plage.【F:sys/ascal.vhd†L106-L133】
- La possibilité de définir `WIDTH=1280`, `HEIGHT=720`, `HDMI_PR=0` via les registres configurables confirme qu'un mode 720p est trivial à activer. De même, maintenir les valeurs 1920×1080 valide le mode 1080p. Les autres modes non entrelacés sont limités par la PLL HDMI et la bande passante DDR utilisée par `ascal`.

## Modes palettes 16/256 couleurs
- `ascal` propose un mode framebuffer 8bpp avec palette : `pal1_mem` stocke 128 entrées de 48 bits, chacune contenant deux couleurs (indice pair/impair), ce qui couvre 256 teintes. Un second port (`pal2_mem`) permet aux cœurs d'alimenter directement une palette 256×24 bits.【F:sys/ascal.vhd†L172-L185】【F:sys/ascal.vhd†L2452-L2486】
- Le service DDR (`ddr_svc`) offre un canal dédié pour streamer ces palettes depuis la mémoire externe, rendant la mise à jour des 16 ou 256 couleurs très simple côté cœur/HPS.【F:sys/sys_top.v†L641-L669】
- Implémenter un mode 16 couleurs se résume à choisir le format 4bpp dans le framebuffer et à remplir seulement les 16 premières paires d'entrées palette ; pour 256 couleurs, on exploite l'ensemble des indices. La logique de multiplexage (`pal_idx_lsb`) gère déjà la sélection du demi-mot correspondant.【F:sys/ascal.vhd†L2464-L2485】

## Suggestions
- Prévoir une table de profils HDMI côté Linux permettant de basculer rapidement entre 720p/1080p/1440p pour tirer parti de la reconfiguration dynamique du scaler et de la PLL.
- Exploiter le canal palette du framebuffer pour proposer des overlays ou modes vidéo 8bpp efficaces, en particulier pour des systèmes 16/256 couleurs.
- Documenter côté cœur l'usage des signaux `HDMI_FREEZE/BLACKOUT/BOB_DEINT` afin d'exploiter pleinement les capacités de post-traitement intégrées au framework.
