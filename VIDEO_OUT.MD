# Analyse de la génération vidéo HDMI

## Chaîne de traitement principale
Le cœur utilisateur (`emu`) fournit directement des signaux RGB 8 bits, synchros et indicateurs de frame aux blocs système MiSTer, ainsi que des options (freeze, blackout, bob deinterlace, paramètres de scaler, etc.) via le bus HPS.【F:mycore.sv†L19-L308】【F:sys/sys_top.v†L1756-L1761】 Les réglages vidéo envoyés par Linux utilisent des commandes SPI (`cmd`), notamment `0x20` pour reprogrammer largeur, hauteur et temporisations HDMI, `0x2F` pour activer la frame buffer DDR, ou `0x37`/`0x27` pour forcer une zone active spécifique.【F:sys/sys_top.v†L376-L462】

### Scaler « ascal » et construction de l’image
La chaîne HDMI standard passe par le scaler `ascal`, qui accepte les flux RGB synchrones du cœur, mesure la zone active et recalcule une sortie cadencée par `pll_hdmi`. Ce bloc gère l’up/down-scaling (nearest, bilinear, sharp, bicubic, polyphase), la détection d’entrelacement, le bob deinterlace, la mise en mémoire tampon dans la DDR (128 bits), et expose des registres pour lire/écrire des palettes ou coefficients.【F:sys/ascal.vhd†L1-L135】【F:sys/sys_top.v†L693-L805】 Les timings HDMI (total, fenêtres de synchro et zone visible) sont dérivés des registres `WIDTH/HEIGHT/HFP/HBP/...` programmés par le HPS, avec un mode pixel-repetition (`HDMI_PR`) et un mode VRR optionnel.【F:sys/sys_top.v†L410-L417】【F:sys/sys_top.v†L750-L766】【F:sys/sys_top.v†L1028-L1036】

### Effets de post-traitement et composition
Le signal issu du scaler traverse plusieurs filtres matériels :
- `scanlines` applique des lignes sombres configurables avant OSD, en modulant la luminance selon un motif cyclique.【F:sys/sys_top.v†L1356-L1374】【F:sys/scanlines.v†L1-L48】 
- `shadowmask` ajoute des motifs CRT programmables (taille, rotation, LUT par pixel) au flux HDMI lorsque le scaler est actif.【F:sys/sys_top.v†L1134-L1152】【F:sys/shadowmask.sv†L1-L80】 
- Les signaux `HDMI_FREEZE`, `HDMI_BLACKOUT` et `HDMI_BOB_DEINT` fournis par le cœur permettent respectivement de figer l’image, forcer un noir ou activer le bob deinterlace dans le scaler, ce qui complète les options de composition.【F:sys/sys_top.v†L1756-L1761】

Le flux final (`hdmi_data_osd`) est ensuite sérialisé via un DDR I/O pour alimenter `HDMI_TX_D/DE/HS/VS` synchronisé sur l’horloge générée par `pll_hdmi`.【F:sys/sys_top.v†L1249-L1312】

### Mode « direct video »
Une bascule `direct_video` permet de court-circuiter le scaler : le signal vidéo à cadence cœur est alors ré-échantillonné (détection de zone active, insertion éventuelle de `csync`) et peut sortir directement via HDMI, tout en conservant l’OSD et, si souhaité, la génération composite (`yc_out`). Ce chemin utilise un multiplexeur d’horloge qui choisit `clk_vid` comme source HDMI et relaie `dv_data` vers la sortie finale.【F:sys/sys_top.v†L295-L310】【F:sys/sys_top.v†L1182-L1244】

### Framebuffer DDR et palettes
Le HPS peut activer un framebuffer linéaire (commande `0x2F`) avec choix du format (8 bpp palette, 16/24/32 bpp) et de la fenêtre visible ; les paramètres sont stockés dans `LFB_*` avant d’être transférés dans `FB_*` pour que le scaler lise/écrive dans la DDR.【F:sys/sys_top.v†L438-L449】【F:sys/sys_top.v†L808-L839】 Pour les modes 8 bpp, `ddr_svc` rapatrie la palette depuis la RAM et la transmet au scaler (`pal_wr/pal_d`), qui expose deux banques de palette (générique et optionnelle spécifique au framebuffer).【F:sys/sys_top.v†L664-L705】【F:sys/sys_top.v†L995-L1010】【F:sys/sys_top.v†L775-L784】 

## Ajout de l’OSD
L’overlay OSD est implémenté par deux instances du module `osd`, une pour le chemin HDMI et une pour le chemin VGA. Les trames OSD sont stockées dans une RAM interne de 256×64, alimentée par le HPS via `io_osd/io_strobe/io_din` (commandes `0x20`/`0x40` pour écriture, positionnement et rotation). L’OSD se superpose pixel par pixel en suivant la zone active détectée sur le flux vidéo.【F:sys/osd.v†L1-L199】【F:sys/sys_top.v†L1158-L1175】【F:sys/sys_top.v†L1376-L1396】 Le cœur n’a donc qu’à exposer les signaux vidéo bruts ; l’HPS gère la génération des menus et leur injection.

## Spécificités VGA versus HDMI
Les deux sorties partagent le pipeline jusqu’à l’OSD, mais certaines fonctions sont propres à chaque canal :
- HDMI bénéficie des masques CRT (`shadowmask`) et du scaler `ascal`. La sortie analogique peut optionnellement recevoir le signal du scaler via `vga_scaler_out`, mais sans masque.【F:sys/sys_top.v†L1134-L1152】【F:sys/sys_top.v†L1448-L1461】 
- Le chemin VGA applique les mêmes scanlines et OSD, puis peut convertir en YPbPr ou composite (`yc_out`) et générer une porteuse couleur/subcarrier pour pilotage de modulateurs externes.【F:sys/sys_top.v†L1410-L1499】 
- Des options spécifiques analogiques (sog, ypbpr, csync, forçage du scaler VGA) sont exposées via les bits de configuration `cfg`, alors que le HDMI repose sur les timings programmés et l’horloge PLL.【F:sys/sys_top.v†L295-L310】 

## Résolutions HDMI
Les registres HDMI sont initialisés à 1920×1080 (1080p CEA) avec un pixel clock de 148,5 MHz, mais le HPS peut reprogrammer entièrement les timings via `cmd 0x20`, y compris le pixel repetition (`HDMI_PR`) et le mode VRR, ce qui couvre les modes standards comme 1280×720p ou tout timing non entrelacé inférieur à la capacité du PLL (12 bits pour largeur/hauteur).【F:sys/sys_top.v†L410-L417】【F:sys/sys_top.v†L750-L766】【F:sys/sys_top.v†L1028-L1036】 La génération d’horloge `pll_hdmi` est reconfigurée à la volée pour s’adapter au nouveau pixel clock.【F:sys/sys_top.v†L1016-L1059】 

## Palettes 16 et 256 couleurs
Le scaler supporte nativement les framebuffers 8 bpp avec palette de 256 entrées, via les ports `pal1`/`pal2` et la logique `ddr_svc`. Implémenter un mode 256 couleurs revient à alimenter la palette et à envoyer les indices 8 bits, sans modification matérielle supplémentaire.【F:sys/ascal.vhd†L101-L135】【F:sys/sys_top.v†L775-L784】 En revanche, il n’existe pas de traitement direct pour des palettes 4 bpp (16 couleurs) : il faudrait soit convertir vers 8 bpp (avec une palette élargie, éventuellement en dupliquant les valeurs), soit générer les composantes RGB avant d’entrer dans le pipeline (`video_mixer`/`scanlines`).【F:sys/ascal.vhd†L101-L135】 

## Remarques et suggestions
- Documenter côté HPS la liste des timings prédéfinis pour faciliter le passage rapide entre 720p, 1080p et les modes personnalisés via `cmd 0x20`.
- Prévoir éventuellement une petite LUT matérielle optionnelle pour convertir des indices 4 bpp en RGB ou en indices 8 bpp afin de simplifier les cœurs 16 couleurs.
- Vérifier, lors d’un développement de cœur, que les signaux `HDMI_FREEZE/BLACKOUT/BOB` sont bien gérés si l’on souhaite exploiter les fonctions du scaler (pause d’image, bob, etc.).
