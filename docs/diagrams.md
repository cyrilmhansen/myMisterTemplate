# Video Flow Diagrams

## MyCore video demo data and control flow

```mermaid
flowchart LR
    subgraph Wrapper["`emu` wrapper (mycore.sv)"]
        HPS_BUS[[HPS\_BUS]] --> HPSIO[hps_io]
        HPSIO -->|status[2], buttons[1]| ResetMux[Reset logic]
        HPSIO -->|status[122:121]| Aspect[VIDEO_ARX/VIDEO_ARY]
        HPSIO -->|status[4:3]| ColorMask[RGB channel mask]
        HPSIO -->|forced_scandoubler| ScanCtrl[Scan doubler request]
        CLK50[CLK_50M] --> PLL[pll]
        PLL --> clk_sys[clk_sys]
        ResetMux --> MycoreInst((mycore))
        clk_sys --> CLK_VIDEO
        clk_sys --> MycoreInst
        ScanCtrl --> MycoreInst
        statusPAL[status[2] (PAL mode)] --> MycoreInst
    end

    subgraph DemoCore["`mycore` internals (rtl/mycore.v)"]
        MycoreInst -->|ce_pix| CE_PIXEL
        MycoreInst -->|HBlank/HSync/VBlank/VSync| Timing[VGA timing]
        MycoreInst -->|video[7:0]| Luma[Luminance]
        clk_sys --> PixelCounter[Pixel counters]
        ScanCtrl --> PixelCounter
        statusPAL --> PixelCounter
        PixelCounter --> Timing
        PixelCounter --> PhaseAcc[vvc accumulator]
        PhaseAcc --> CosineROM[cos LUT]
        CosineROM --> Cosine[Cosine wave]
        LFSR[lfsr noise] --> Noise[Random comparator]
        Cosine --> Mixer[Threshold mixer]
        Noise --> Mixer
        Mixer --> Luma
    end

    CE_PIXEL --> CEOut[CE_PIXEL output]
    Timing -->|sync| VGASync[VGA_HS/VGA_VS/VGA_DE]
    Luma --> ColorMux[Channel routing]
    ColorMask --> ColorMux
    ColorMux --> VGA_RGB[VGA_R/VGA_G/VGA_B]
    Aspect --> VIDEO_AR[Aspect ratio outputs]
```

## 1440p HDMI from indexed palette framebuffer without ASCAL

```mermaid
flowchart TB
    subgraph Control[Control and configuration]
        HPSCFG[HPS/IO config writes] -->|WIDTH/HEIGHT/HSET/VSET| TimingRegs[Timing registers]
        TimingRegs -->|htotal/vtotal| PLLCFG[pll_hdmi configuration]
        PLLCFG --> HDMIClock[HDMI TX clock]
        HPSCFG -->|LFB_EN & FB params| LFBRegs[LFB/FB registers]
        LFBRegs --> FBMerge[FB merge]
        FBMerge --> CoreFB[FB_* to core]
        FBMerge --> PaletteCtrl[Palette request logic]
        PaletteCtrl -->|pal_req| PaletteDMA[Palette DMA via RAM2]
        PaletteDMA --> FB_PAL_DIN[FB_PAL_DIN]
    end

    subgraph Data[Pixel pipeline]
        FramebufferDDR[(Indexed framebuffer in DDR3)] --> DDRPort[DDRAM port]
        DDRPort --> CoreRenderer[Core renderer]
        CoreFB --> CoreRenderer
        FB_PAL_DIN -.-> CoreRenderer
        CoreRenderer --> CoreOutputs[r_out/g_out/b_out + sync]
        CoreOutputs --> Scanlines[scanlines]
        Scanlines --> VGA_OSD[vga_osd overlay]
        VGA_OSD --> DirectVideo[dv_data/dv_hs/dv_vs/dv_de]
        DirectVideo --> ClockMux[cyclonev_clkselect]
        ClockMux --> HDMI_TX[HDMI transmitter]
    end

    HDMIClock --> ClockMux
    DirectVideo -.->|bypass ASCAL| HDMI_TX
```
