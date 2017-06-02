# RetroSave

RetroSave.ahk -- version 2017-06-02 -- by nod5 -- GPLv3

## FRONTEND FOR RETROARCH SAVESTATES
Fullscreen gui grid with one screenshot per save state.  
Use it to save, load and browse save states while playing.  
Works with Xbox 360 controller / mouse / keyboard.  
Windows only, 1920x1080 resolution.  

RetroSave in 15 seconds  https://youtu.be/xRj3ejNMRns

## SETUP
1 Install RetroArch and set up games and playlists  
2 Install Autohotkey  https://autohotkey.com  
3 Download RetroSave.ahk  https://github.com/nod5/RetroSave  
4 Download LibCon.ahk  https://github.com/joedf/LibCon.ahk/blob/master/LibCon.ahk  
5 Put Libcon and RetroSave in the same folder  
6 Run RetroSave.ahk and enter your RetroArch folder path  

## USE
Run RetroSave.ahk to start both RetroArch and RetroSave  

Grid show/hide: RB+Y / mouse Rbutton / CapsLock  
Move in grid: joy DPad / mouse / navkeys  
Action: A / mouse Lbutton / Enter  
Default action mode: load selected saved game  

Change mode for selected item: X / Mbutton / Space  

Modes:   screenshot thumbnail (load this save)  
         new (overwrite with new save here)  
         del (delete this save)  
         cut (prepare this save for move)  
         paste (move cut to position after this)  
Save button modes:  
         save (new save, placed last)  
         mute (toggle game audio)  

Next/prev grid page: LStick left right / MouseWheel / PgDn PgUp  
Quick jump to save button: LStick up / [none] / Home  
Keyboard cut/paste a save: ctrl+x ctrl+v  
Close game: LB+RB+select  
Pause game: RB + X / mouse Lbutton  

## NOTES
- Windows only. Last tested in Win10 with RetroArch x86_x64 1.6.0 stable 2017-06-02
- 1920*1080 screen resolution  
- Tested with SNES/NES/FDS/MAME games  
- Tested with these cores  
 fbalpha_libretro.dll , mame_libretro.dll , nestopia_libretro.dll  
 bsnes_accuracy_libretro.dll , snes9x_libretro.dll  
- Might work with other cores  

- RetroSave stores savestates and screenshots next to each gamefile  
  smb.nes  smb.state1  smb.state1.png  smb.state2  ...  

- RetroSave sets these RetroArch settings:  
  user interface > show advanced settings ON  
  user interface > don't run in background OFF  
  saving > sort savestates in folders: OFF  
  saving > sort savefiles in folders: ON  
  saving > savestate thumbnail: ON  
  directory > savestate : \states\  
  directory > savefile : \saves\  
  logging > logging verbosity : ON  
  logging > core logging level : 3  
  input > input hotkey binds :  
   f2 save , f4 load , f8 screenshot , p pause  

- RetroSave creates a RetroArch MAME core cfg at  
  \saves\mame\mame\cfg\default.cfg  
  This enables MAME save/load and prevents hotkey collisions.

- RetroArch core updates may break old savestates.  
  Workaround: Keep and use backups of cores/savestates.

- The way RetroSave interacts with RetroArch is inherently fragile  
  RetroArch updates can break RetroSave at any time  

## KNOWN ISSUES  
 - Grid actions fail on state slot change in RA menu during session  
 - Can in rare case mess up retroarch.cfg. Restore with last datestamped  
   cfg backup in Retroarch folder. Example "retroarch.cfg 20170529181510.cfg"  
