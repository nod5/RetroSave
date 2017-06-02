#singleinstance, force
#Include %A_ScriptDir%\LibCon.ahk
SetBatchLines -1
SetWorkingDir %A_ScriptDir%

;######################################
;# RetroSave
;
;RetroSave.ahk -- version 2017-06-02 -- by nod5 -- GPLv3
;
;## FRONTEND FOR RETROARCH SAVESTATES
;Fullscreen gui grid with one screenshot per savestate.
;Use it to save, load and browse save states while playing.
;Works with Xbox 360 controller / mouse / keyboard.
;Windows only, 1920x1080 resolution.
;
;######################################
;## SETUP
;1 Install RetroArch and set up games and playlists
;2 Install Autohotkey  https://autohotkey.com
;3 Download RetroSave.ahk  https://github.com/nod5/RetroSave
;4 Download LibCon.ahk  https://github.com/joedf/LibCon.ahk/blob/master/LibCon.ahk
;5 Put Libcon and RetroSave in the same folder
;6 Run RetroSave.ahk and enter your RetroArch folder path

;######################################
;## USE
;Run RetroSave.ahk to start both RetroArch and RetroSave
;
;Grid show/hide: RB+Y / mouse Rbutton / CapsLock
;Move in grid: joy DPad / mouse / navkeys
;Action: A / mouse Lbutton / Enter
;Default action mode: load selected saved game
;
;Change mode for selected item: X / Mbutton / Space
;
;Modes:   screenshot thumbnail (load this save)
;         new (overwrite with new save here)
;         del (delete this save)
;         cut (prepare this save for move)
;         paste (move cut to position after this)
;Save button modes:
;         save (new save, placed last)
;         mute (toggle game audio)

;Next/prev grid page: LStick left right / MouseWheel / PgDn PgUp
;Quick jump to save button: LStick up / [none] / Home
;Keyboard cut/paste a save: ctrl+x ctrl+v
;Close game: LB+RB+select
;Pause game: RB + X / mouse Lbutton

;######################################
;## NOTES
;- Windows only. Last tested in Win10 with RetroArch x86_x64 1.6.0 stable 2017-06-02
;- 1920*1080 screen resolution
;- Tested with SNES/NES/FDS/MAME games
;- Tested with these cores
; fbalpha_libretro.dll , mame_libretro.dll , nestopia_libretro.dll
; bsnes_accuracy_libretro.dll , snes9x_libretro.dll
;- Might work with other cores
;
;- RetroSave stores savestates and screenshots next to each gamefile
;  smb.nes  smb.state1  smb.state1.png  smb.state2  ...
;
;- RetroSave sets these RetroArch settings:
;  user interface > show advanced settings ON
;  user interface > don't run in background OFF
;  saving > sort savestates in folders: OFF
;  saving > sort savefiles in folders: ON
;  saving > savestate thumbnail: ON
;  directory > savestate : \states\
;  directory > savefile : \saves\
;  logging > logging verbosity : ON
;  logging > core logging level : 3
;  input > input hotkey binds :
;   f2 save , f4 load , f8 screenshot , p pause
;
;- RetroSave creates a RetroArch MAME core cfg at
;  \saves\mame\mame\cfg\default.cfg
;  This enables MAME save/load and prevents hotkey collisions
;
;- RetroArch core updates may break old savestates
;  Workaround: Keep and use backups of cores/savestates
;
;- The way RetroSave interacts with RetroArch is inherently fragile
;  RetroArch updates can break RetroSave at any time
;
;## KNOWN ISSUES
; - Grid actions fail on state slot change in RA menu during session
; - Can in rare case mess up retroarch.cfg. Restore with last datestamped
;   cfg backup in Retroarch folder. Example "retroarch.cfg 20170529181510.cfg"
;######################################

;check and set path to RetroArch folder
FileRead, ra_path, % A_ScriptFullPath ".ini"   ;check ini for saved path
if !FileExist(ra_path "\RetroArch.exe")
{
 ;browse for RetroArch folder, starting at My Computer
 FileSelectFolder, ra_path, ::{20d04fe0-3aea-1069-a2d8-08002b30309d}
 , 2, Select the RetroArch folder
 If FileExist(ra_path "\RetroArch.exe")
 {
  FileDelete, % A_ScriptFullPath ".ini"
  FileAppend, % ra_path , % A_ScriptFullPath ".ini"
 }
 FileRead, ra_path, % A_ScriptFullPath ".ini"
}
if !FileExist(ra_path "\RetroArch.exe")
 exitapp

;configure retroarch.cfg for RetroSave
cfgpath := ra_path "\retroarch.cfg"
FileRead, cfg, % cfgpath
cfg_unchanged := cfg

;cfg values to check and set
carr := {"menu_show_advanced_settings = " : """true"""
  , "pause_nonactive = " : """false"""
  , "sort_savefiles_enable = " : """true"""       ;needed for mame save
  , "sort_savestates_enable = " : """false"""
  , "savestate_thumbnail_enable = " : """true"""  ;auto screenshots
  , "log_verbosity = " : """true"""               ;needed to read log
  , "libretro_log_level = " : """3"""
  , "savestate_directory = " : """:\states"""
  , "savefile_directory = " : """:\saves"""
  , "input_load_state = " : """f4"""
  , "input_save_state = " : """f2"""
  , "input_screenshot = " : """f8"""
  , "input_pause_toggle = " : """p"""
  , "state_slot = " : """999"""}

Loop, Parse, cfg, `n, `r
{
 For key, val in carr
 {
 cfgline := InStr(A_LoopField, key) ? key val : ""
 if cfgline
  break
 }
 cfgout .= cfgline ? cfgline "`r`n" : A_LoopField "`r`n"
}
cfgout := SubStr(cfgout,1,-2) ;trim last linebreak
if (cfgout != cfg_unchanged) ;save if changes
{
IfWinExist, ahk_exe retroarch.exe
 WinClose, ahk_exe retroarch.exe
FileCopy, % cfgpath, % cfgpath " " A_Now ".cfg" ;datestamped backup
FileDelete, % cfgpath
FileAppend, % cfgout, % cfgpath
sleep 200
}

;set MAME cfg to enable save/load and avoid hotkey collisions
;background: MAME core has special savestates and hotkeys
gosub mamecfg ;puts cfg text in mamecfg var
If !FileExist(ra_path "\saves\mame\mame\cfg\default.cfg")
{
FileCreateDir, % ra_path "\saves\mame\mame\cfg"
FileAppend, % mamecfg, % ra_path "\saves\mame\mame\cfg\default.cfg"
sleep 200
}

;Show Console and initialize library
SmartStartConsole()
SetConsoleWidth(300) SetConsoleHeight(2500)

;We monitor console log for new game/core info
;clear log after RA start -> next game/core near log top
;Set consoleheight high to fit entire new game log
;Otherwise later log lines push game/core info lines off the top
;Consolewidth 300 fits windows max filepaths length
;Consoleheight 2500 is ok with libretro_log_level=3
;longest game start log was ~1500 in tests

Run, %comspec% /c "%ra_path%\retroarch.exe",,,xpid
SetConsoleTitle("RetroSave_console")
WinMinimize, RetroSave_console
WinWaitActive, ahk_exe retroarch.exe,,5
sle(330)
gamedetect := 1
winget, xid, id, ahk_exe retroarch.exe  ;first RA win id
SetTimer gamedetect, 300
SetTimer idwatch, 100
sle(70) ClearScreen()
WinMinimize, RetroSave_console
return

;RA replaces the window (new window id) on game start and close
;monitor win id, if changed do gamedetect, if none close console

idwatch:
winget, newid, id, ahk_exe retroarch.exe
if newid
 tick := ""
if (newid == xid)
 return
if !newid  ;no RA window
{
 if !tick
  tick := A_TickCount
 else if (A_TickCount - tick > 5000)  ;wait 5s for new win
   winclose, RetroSave_console ahk_class ConsoleWindowClass ;close console
return
}
xid := newid ;new RA win id
matchgame1 := matchcore1 := "" ;clear vars
SetTimer gamedetect, 300 ;detect new game
return

;Read gamepath and core from LibCon console log

;log format as of 2017-05-25 with RetroArch x86_x64 nightly 2017-05-25
;- game line sample
;  "RetroArch [INFO] :: Using content: <contentdir>\<subdir>\1942.zip."
;- core line sample for first game in session
;  "RetroArch [INFO] :: arg #9: <retroarchdir>\cores\fbalpha_libretro.dll"
;- core line sample on game start while another game runs
; "RetroArch [INFO] :: Loading dynamic libretro core from: "<ra_path>\cores\snes9x_libretro.dll""
;- in all tests game/core line was near log top, at most 28 lines down
;- tested on:   fbalpha_libretro.dll , mame_libretro.dll ,
;              nestopia_libretro.dll , bsnes_accuracy_libretro.dll ,
;                snes9x_libretro.dll (nightlies 2017-05-25)
;- also tested on some older mame and fba core nightlies from 2015 2016

;LibCon syntax ReadConsoleOutput( x, y, w, h )
;read log lines near console top
;use low height and width for faster read

gamedetect:
txt := ReadConsoleOutput(0,0,300,50) ;small read area is faster
getgamecore(txt, matchgame1, matchcore1)
if (matchgame1 and matchcore1)
 if (FileExist(matchgame1) and FileExist(ra_path "\cores\" matchcore1) )
 {
  gamedetect := ""
  settimer, gamedetect, off
  goto gamefound
 }
;log string after game close menu action -> clear log/vars, continue gamedetect
if InStr(txt, "No content, starting dummy core")
 ClearScreen() , game := core := ""
return

getgamecore(txt, ByRef matchgame1, ByRef matchcore1) {
Loop, Parse, txt, `n, `r
  {
  if InStr(a_loopfield, ":: Using content:") ;game
   RegExMatch(a_loopfield, ":: Using content: (.+)\. *", matchgame)
  if InStr(a_loopfield, ":: arg") and InStr(a_loopfield, "\cores\") ;core
   RegExMatch(a_loopfield, "\\cores\\(.+\.dll) *", matchcore)
  if InStr(a_loopfield, "Loading dynamic libretro core") ;core alt line
   RegExMatch(a_loopfield, "\\cores\\(.+\.dll)", matchcore)
  if matchgame and matchcore
   break
  }
}

gamefound:
game := matchgame1
corepath := ra_path "\cores\" matchcore1
splitpath, corepath, , , , core
SplitPath, game,,gdir,, gnoext

; savestate format when sort_savestates_enable=false :
; MAME  <ra_path>\saves\mame\mame\states\<gnoext>\<gnoext>\1.sta
; other <ra_path>\states\<gnoext>.state999

; Note: if sort_savestates_enable=true RA saves to core specific subfolders
; Subfolder names are *not* always the core filename
; Log line ~25 with string "core-specific overrides" has subfolder name. Sample:
; RetroArch [INFO] :: [overrides] no core-specific overrides found at <ra_path>\config\FB Alpha\FB Alpha.cfg.
; -> "FB Alpha" (core internal name) is state subfolder name
; We skip this with sort_savestates_enable=false

;tooltip % game "`n" core  ;for testing
;sleep 1500
;tooltip
cp := 0, start := 0 , txt := ""
ClearScreen()
return

;function to send keys slowly to RetroArch, regular sendinput fails
slow(x){
IfWinNotactive, ahk_exe retroarch.exe
 return
sendinput {%x% down}
sleep 50
sendinput {%x% up}
}
sle(x){
sleep %x%
}

#IfWinActive, ahk_exe retroarch.exe
;TOGGLE PAUS
~Joy3::   ;X
~2Joy3::  ;X   ;hotkeys for two first x360 controllers
if wait
 return
if GetKeyState(SubStr(a_thishotkey,2,-1) "6", "P") ;RB + X
  slow("p") ClearScreen()  ;toggle pause
return

~Lbutton::
MouseGetPos,,,id
WinGet, win, Processname, ahk_id %id%
if (win == "retroarch.exe" and !wait)
  slow("p")  ;toggle pause
return

;OPEN GRID
~Joy4::  ;Y
~2Joy4::  ;Y
if GetKeyState(SubStr(a_thishotkey,2,-1) "6", "P")   ;RB + Y  ;open grid
 goto opengrid
return
~Rbutton::   ;open grid
MouseGetPos,,,id
WinGet, win, Processname, ahk_id %id%
if (win != "retroarch.exe")
 return
CapsLock::   ;open grid
opengrid:
if wait
 return
ifwinexist, rs_gui
 goto rs_gui_exit
if (!FileExist(game) or !FileExist(corepath) ) ;no game running
 return

;make savestates array
newgridnewarr:  ;called by joydel/joypaste
ClearScreen()
sarr := Object() ;array
cutboard := "", ff := ""
;make list of save state file numbers
;file format: smb.state12
Loop, Files, % gdir "\" gnoext ".state*"
 if (A_LoopFileExt != "png") and (A_LoopFileExt != "tempcut")  ;skip thumbs and old temp
   ff := !ff ? SubStr(A_LoopFileExt,6) : ff "," SubStr(A_LoopFileExt,6)  ;state12 -> 12

Sort ff, N D,      ;1,10,11,2,4 ... ->  1,2,4,10,11 ...
Loop, Parse, ff,`,
 sarr.Insert( "state" A_LoopField )  ;add sorted to array

;Note: save slot 0 has extension ".state" (no number). We skip it.

;MAKE GRID: each grid page has 12 items in 4 cols 3 rows
;First page has Save button.
;Index:
;Save button is position 0
;position 1 2 3... are sarr[1] sarr[2] sarr[3] ...
; 0-11 = grid1 , 12-23 = grid2 , 24-35 = grid3 ...
;start = position of first item on current grid page
;cp = position of current selected/focused item
;cg = current grid

WinGetPos, rax,,,, ahk_exe retroarch.exe
guix := rax < 1900 ? 0 : rax < 3800 ? 1920 : 3840  ;position grid over RA
Gui,9: -Caption +ToolWindow +AlwaysOnTop ;extra gui for black background when grid updates
Gui,9: Color, Black
Gui,9: Show, Hide x%guix% y0 w1920 h1080 ,rs_temp_black

newgrid:   ;called one move between grid pages
if InStr(a_thislabel, "newgrid")
{
 WinShow, rs_temp_black      ;black background when grid redraws
 WinActivate, rs_temp_black  ;todo: RA still flickers through at times
 sleep 5
}

ypos := 80, mode := ""
start := start > 0 && start <= sarr.MaxIndex() ? start : 0  ;wrap around
cp := cp > 0 && cp <= sarr.MaxIndex() ? cp : 0
grids := ceil( (sarr.MaxIndex() + 1) / 12 )   ;number of grids
cg := cp == 0 ? 1 : floor(cp / 12) + 1        ;current grid
segw := grids > 3 ? floor((1920-300-(grids*6))/grids) : 399 ;top bar segment width

Loop, 6
 Gui, %a_index%: Destroy  ;old grid
Gui, +ToolWindow -SysMenu -Caption -resize +AlwaysOnTop  ;borderless gui
Gui, Color, Black

if (grids > 1)
 Loop, % grids
 {
 ;make top bar segments, highlight current grid page segment blue
 segx := a_index==1 ? "x150" : "x+6"
 ;create single color pic rectangle gui control without extra files
 ;WIA method adapted from wiasample_create.ahk at
 ;https://autohotkey.com/boards/viewtopic.php?p=43772#p43772
 ;HBITMAP handle manpage https://autohotkey.com/docs/misc/ImageHandles.htm
 segcol := a_index==cg ? [0x66a0d6] : [0x323232]  ;blue : grey
 ImgObj := WIA_CreateImage(1, 1, segcol) ;create image
 PicObj1 := WIA_GetImageBitmap(ImgObj)   ;get image bitmap data
 Gui, Add, Pic, %segx% y1 w%segw% h15, % "hbitmap:" PicObj1.Handle
 }

;make grid items
Gui, Font, bold s13 cblack, Arial Black ;c3399FF for testing
Gui, Add, Text, h0 x150 y%ypos% section,

if (start==0)      ;first item on first grid page is Save button
 Gui, Add, Text, xs w25 y%ypos%,%A_space%
if (start==0)
{
;make Save button 300x300 image and text
ARGB := [0x232323] ;dark grey
ImgObj := WIA_CreateImage(1, 1, ARGB) ;create image
PicObj1 := WIA_GetImageBitmap(ImgObj) ;get image bitmap data
Gui, Add, Pic, vsave x+p w300 h300, % "hbitmap:" PicObj1.Handle
gui, font, c66a0d6 s95, Franklin Gothic Medium  ;blue
Gui, Add, Text, BackgroundTrans vsavetext xp yp w300 h150, save
Gui, Add, Text, BackgroundTrans vsavetext2 xp yp+120 w300 h150, +
GuiControl, +Center, savetext
GuiControl, +Center, savetext2
}

cnt := start == 0 ? 1 : 0  ;offset grid items count if page has save button
For i, val in sarr
{
 if (i < start)  ;skip items lower than this grid view
  continue
 cnt++      ;grid view item count
 val := StrReplace(val, "state","") ;state12 -> 12
 itempos := (cnt==4)or(cnt==7)or(cnt==10) ? "xp+400 y" ypos " section" : "xs"
 itempos := (cnt==1) ? "xp y" ypos "section" : itempos
 if (i > start+11) ;only 12 items in grid
  break
 Gui, Font, bold s13 cblack, Arial Black
 Gui, Add, Text, %itempos% w25 vstate%val%,`n%val%  ;filename num, used by save
 pict := gdir "\" gnoext ".state" val ".png"
 if FileExist(pict) ;screenshot thumb as pic
  Gui, Add, picture, x+p w300 h300 vshotstate%val%, %pict%
 else ;make placeholder
 {
  ARGB := [0x232323] ;dark gray
  ImgObj := WIA_CreateImage(1, 1, ARGB) ;create image
  PicObj1 := WIA_GetImageBitmap(ImgObj) ;get image bitmap data
  Gui, Add, Pic, vshotstate%val% x+p w300 h300, % "hbitmap:" PicObj1.Handle
  gui, font, ca6a6a6 s95, Franklin Gothic Medium  ;light gray
  Gui, Add, Text, BackgroundTrans vshotstate%val%txt xp yp+80 w300 h150, *
  GuiControl, +Center, shotstate%val%txt
 }
}

if !InStr(a_thislabel, "newgrid") ;not nav between grid pages
 slow("p") con_wait(":: Paused.", ":: Unpaused.") ;pause game before grid open

Gui, Show, x%guix% y0 w1920 h1080,rs_gui
WinActivate, rs_gui

;selected item popup 400x400 template
Gui, 6: -Caption +ToolWindow +AlwaysOnTop +Border
Gui, 6: Color, 232323 ;dark grey
gui, 6: font, c232323 s140, Franklin Gothic Medium
Gui, 6: Add, text, x0 y50 w300 h100 vrs_txt,
Gui, 6: Add, text, x0 y150 w300 h100 vrs_txt2, ;2nd line text for save and paste
GuiControl, 6: +Center, rs_txt
GuiControl, 6: +Center, rs_txt2
Gui, 6: Add, picture, x0 y0 w300 h300 vrs_pic,
Gui, 6: Show, Hide w300 h300 , rs_pop  ;later enlarge for popout effect

SetTimer, joymove, 50
if InStr(a_thishotkey,"wheel") && (cnt > 1)
{
 WinHide, rs_temp_black
 return  ;no auto popup if rbutton/wheel event and >1 item in grid
}
gosub showselection ;show popup for selected item
WinHide, rs_temp_black
return
#IfWinActive

;detect xbox 360 controller stick/dpad events
joymove:
GetKeyState, sticky, JoyY ;left stick vert
GetKeyState, stickx, JoyX ;left stick horiz
GetKeyState, jp, JoyPOV     ;dpad
GetKeyState, jp2, 2JoyPOV   ;dpad joy2
if !WinActive("rs_gui")
 return
cpold := cp
;9k=R 27k=L 18k=D 0=U
cp := jp==9000 ? cp+3 : jp==27000 ? cp-3 : jp=18000 ? cp+1 : jp==0 ? cp-1 : cp
if (jp == -1) or (jp == "")
 cp := jp2==9000 ? cp+3 : jp2==27000 ? cp-3 : jp2=18000 ? cp+1 : jp2==0 ? cp-1 : cp
cp := stickx==000 ? cp-12 : stickx==100 ? cp+12 : cp  ;stick L/R -> prev/next page
if (sticky==000)  ;stick up -> jump to save button in grid
 {
 cp := 0, start := 0
 goto newgrid
 }
if (cp==cpold) ;no joy move
 return
wheel:
keyboard:
if (sarr.MaxIndex() <= 11)  ;only one grid page -> stop at first/last item
 cp := cp < 0 ? 0 : cp > sarr.MaxIndex() ? sarr.MaxIndex() : cp

if (cp > start+11 or cp > sarr.MaxIndex() ) ;exit grid right side -> newgrid
{
 start := start+12 <= sarr.MaxIndex() ? start+12 : 0 ;next or first grid
 cp := cp >= start && cp < start+12 ? cp : cp - sarr.MaxIndex() - 1 ;in next or first grid
 cp := cp > sarr.MaxIndex() ? sarr.MaxIndex() : cp ;if last grid has < 12 items
 cp := a_thislabel == "wheel" ? start : cp
 ;tooltip cp=%cp%`nstart=%start%`nfullgrids=%g%   ;for testing
 goto newgrid
}
else if (cp < start )  ;exit grid left side -> newgrid
{
 ;sarr.MaxIndex() + 1 (save button)   = total items in grid
 ;ceil ( (sarr.MaxIndex() + 1) / 12 ) = number of grids
 ;floor( (sarr.MaxIndex() + 1) / 12 ) = number of full grids
 g := floor( (sarr.MaxIndex() + 1) / 12 )  ;number of full grids
 ;first in prev or last grid
 start := start-12 >= 0 ? start-12 :  g*12 == sarr.MaxIndex()+1 ? (g-1)*12 : g*12
 cp := cp >= 0 ? cp : sarr.MaxIndex()+cp+1  ; 102 + (-3) = 99
 cp := cp < start ? start : cp   ;if last grid has < 12 items
 cp := a_thislabel == "wheel" ? start : cp
 ;tooltip cp=%cp%`nstart=%start%`nfullgrids=%g%  ;for testing
 goto newgrid
}

showselection:
mode =  ;reset mode on move
if (cp == 0)
 mode := "save"
showselection_mute:
cname := cp == 0 ? "save" : "shot" sarr[cp]   ; save : shotstate12
GuiControlGet, cpos, Pos, %cname%
cx := cposX+guix-50, cy := cposy-50  ;offset popup size and main gui x pos
pic := gdir "\" gnoext "." sarr[cp] ".png"
Gui, 6: Hide
selgui(mode)
Gui, 6: Show, NA x%cx% y%cy% w406 h406
sle(100) ;slow down navigation
return

selgui(mode := "") {  ;set selected 400x400 popup content
global cp
global pic
if !FileExist(pic) and cp!=0 and !mode
 mode := "place" ;placeholder when no pic

;mode objects
cut := {"col":"5bb67f"} ;green
new := {"col":"a6a6a6"} ;light gray
del := {"col":"ed6565"} ;red
mute := {"col":"ed6565" , "size":120} ;red
place := {"col":"a6a6a6", "y":120, "txt":"*" } ;light gray
save := {"col":"66a0d6" , "y":20, "txt2":"+" } ;blue
paste := {"col":"8b619b" , "size":120 , "y":20 , "font2":"Webdings" , "txt2":"6" } ;purple
;webdings 6 = down pointed triangle

if mode ;show image button with action text
{
  obj := %mode%
  obj.size ? : obj.size := 140  ;default size
  obj.y ? : obj.y := 70         ;default y
  obj.txt ? : obj.txt := mode   ;default txt

  gui, 6: font, % "c" obj.col " s" obj.size, Franklin Gothic Medium
  GuiControl, 6: font , rs_txt  ;apply font change
  GuiControl, 6: , rs_txt, % obj.txt
  GuiControl, 6: hide , rs_pic
  GuiControl, 6: Move, rs_txt, % "x" 0 " y" obj.y " w" 400 " h" 180
  GuiControl, 6: show , rs_txt

  if obj.txt2  ;2nd text line for save and paste
   {
   gui, 6: font, s120, % obj.font2
   GuiControl, 6: font , rs_txt2
   GuiControl, 6: , rs_txt2, % obj.txt2
   GuiControl, 6: Move, rs_txt2, x0 y200 w400 h180
   GuiControl, 6: show , rs_txt2
   }
  else
   GuiControl, 6: hide , rs_txt2
}
else ;show pic screenshot
{
  GuiControl, 6: Move, rs_pic, x3 y3 w400 h400 ;make selected grid item 400x400
  GuiControl, 6: , rs_pic, %pic%
  GuiControl, 6: hide, rs_txt
  GuiControl, 6: hide, rs_txt2
  GuiControl, 6: show, rs_pic
}
mode := mode=="place" ? "" : mode
}


#IfWinActive, ahk_exe retroarch.exe
;reload RA if game active, else close
esc:: reload()
;select + RB + LB
~Joy7:: GetKeyState("Joy6", "P") and GetKeyState("Joy5", "P") ? reload()
~2Joy7:: GetKeyState("2Joy6", "P") and GetKeyState("2Joy5", "P") ? reload()
reload(){
global
if (game && core)
 reload
winclose, RetroSave_console ahk_class ConsoleWindowClass ;else close
}
#IfWinActive

#IfWinActive, rs_gui
;close grid, unpause retroarch
~Joy7::  ;select
~2Joy7:: ;select
if !GetKeyState(SubStr(a_thishotkey,2,-1) "6", "P")
or !GetKeyState(SubStr(a_thishotkey,2,-1) "5", "P") ;RB + LB
 return
~Joy4::  ;Y
~2Joy4:: ;Y
if !GetKeyState(SubStr(a_thishotkey,2,-1) "6", "P") ;RB + Y
 return
2Joy2::  ;B
Joy2::   ;B
Rbutton::
Esc::
CapsLock::
rs_gui_exit:
Loop, 10
 Gui, %a_index%: Destroy
WinActivate, ahk_exe retroarch.exe
ifwinactive, ahk_exe retroarch.exe
 sle(100) slow("p")  ;unpause
ClearScreen()
return

;xbox 360 guide -> close grid, since guide forces RA menu
~vk07sc000:: ;guide button
Loop, 10
 Gui, %a_index%: Destroy
ClearScreen()
return

Home:: ;jump to save button in grid
cp := 0, start := 0
goto newgrid
return

;show prev/next grid view
PgDn::
PgUp::
WheelDown::
WheelUp::
cp := InStr(a_thislabel, "Up") ? cp-12 : cp+12
jumppoint := InStr(a_thislabel, "Pg") ? "keyboard" : "wheel"
goto %jumppoint%  ;update grid
return

;move in grid
Up::
Down::
Left::
Right::
cp := a_thislabel=="Up"? cp-1 : a_thislabel=="Down"? cp+1 : a_thislabel=="Left"? cp-3 : cp+3
goto keyboard  ;update grid
return

;toggle mode for selected item
Mbutton::
MouseGetPos,,,w, c
GuiControlGet, c2, Name, % c
;c2 on screenshot/placeholder pic: "shotstate3" , on save button: "save" , on popup: ""
if InStr(c2, "save") or (cp == 0 and !c2) ;mbutton on save 300x300 or 400x400
 goto mutetoggle_mouse
if !c2
 goto popmode
c2 := StrReplace(c2,"txt","") ;placeholder shotstate12txt -> shotstate12
if InStr(c2, "state")
 {
 for i, val in sarr
  cp := StrReplace(c2,"shot","") == val ? i : cp
 cname := c2
 goto showselection
 }
return

;toggle mode for selected item
Space::
2Joy3:: ;X
Joy3::  ;X
if !cname
 return
if (cname == "save")
 goto mutetoggle
popmode:
if cutboard
 mode := !mode ? "paste" : mode=="paste" ? "new" : mode=="new" ? "del" : mode=="del" ? "cut" : ""
else
 mode := !mode ? "new" : mode=="new" ? "del" : mode=="del" ? "cut" : ""
selgui(mode)
return

;toggle mode for save button
mutetoggle_mouse:
mutetoggle:
cp := 0
if cutboard
 mode := !mode ? "paste" : mode=="paste" ? "mute" : mode=="mute" ? "save" : "paste"
else
 mode := !mode ? "mute" : mode=="mute" ? "save" : "mute"
if (a_thislabel == "mutetoggle_mouse")
 goto showselection_mute
selgui(mode)
return

;do action on selected item
~Lbutton::
MouseGetPos,,,wi, c
WinGetTitle, wititle, ahk_id %wi%
GuiControlGet, cm, Name, % c   ;shotstate12
if (wititle != "rs_pop") and (wititle != "rs_gui")  ;exit if click outside
 goto rs_gui_exit
if InStr(cm,"state") or InStr(cm,"save") ;else reuse cname (mouse: first mbutton got cname)
 cname := cm

^x::
^v::
Enter::
2Joy1::  ;A
Joy1::   ;A
if !cname
 return
c2 := cname
fileread, cfg, %ra_path%\retroarch.cfg
RegExMatch(cfg, "state_slot = \D(\d+)\D", slottemp)   ;state_slot = "999"
slot := slottemp1  ;copy to/from this temp slot
if (slot == "")
 return
slot := InStr(core,"mame") ? 1 : slot   ;use 1 as MAME tempslot
ClearScreen()
mode := c2 == "save" && !mode ? "save" : mode
mode := a_thislabel=="^x" ? "cut" : a_thislabel=="^v" ? "paste" : mode
goto joy%mode%  ;joymute joy joynew joysave joydel joycut joypaste
return

joymute:
Loop, 10
 Gui, %a_index%: Destroy
WinActivate, ahk_exe retroarch.exe
wait = 1
ClearScreen() sle(100) slow("F9") con_wait("muted.") ;mute toggle
slow("p") con_wait(":: Unpaused.", ":: Paused.") ;unpause
wait =
return


joy:  ;load state
c2 := RegExReplace(c2, "(shotstate|state)", "") ;shotstate12 or state12 -> 12
IfNotExist, %gdir%\%gnoext%.state%c2%
 return

; savestate format when sort_savestates_enable=false :
; MAME  <ra_path>\saves\mame\mame\states\<gnoext>\<gnoext>\1.sta
; other <ra_path>\states\<gnoext>.state999
; examples
; MAME  <ra_path>\retroarch\saves\mame\mame\states\cabal\cabal\1.sta
; other <ra_path>\states\1942.state999

; SAVE/LOAD METHOD
; - use already set retroarch.cfg state_slot = "999" as temp save/load slotfile
; - store save states/shots next to the gamefile
; - move between store and slotfile at load/save time
; note: this fails if state_slot is set to "0"

storedfile := gdir "\" gnoext ".state" c2
slotfile := ra_path "\states\" gnoext ".state" slot
if InStr(core,"mame")
{
 slotfile := ra_path "\saves\mame\mame\states\" gnoext "\" gnoext "\" slot ".sta"
 splitpath, slotfile, slotdir
 if !FileExist(slotdir)
  FileCreateDir, % slotdir ;to load old states after new retroarch install
}

FileCopy, % storedfile, % slotfile, 1

Loop, 10
 Gui, %a_index%: Destroy
WinActivate, ahk_exe retroarch.exe
sle(100), wait := 1 ;block commands until done
slow("p") con_wait(":: Unpaused.", ":: Paused.") ;Unpause. Load/save fail if paused

;load and wait for log     ;mame: no log, pgdn and 1 (slot select)
InStr(core,"mame") ? sle(100) slow("PgDn") sle(100) slow("1") sle(100) :
InStr(core,"mame") ? : slow("F4") con_wait(":: Loading state")

if !FileExist(storedfile ".png") ;add screenshot if none exists
{
 now := a_now  ;file timestamp must be >= this
 target := storedfile ".png"
 slow("F8") sle(100) get_shot(1) sle(200) ;screenshot
}
wait =
return


joynew:
joysave:
if InStr(A_ThisLabel,"new")  ;replace save mode
 {
   c2 := RegExReplace(c2, "(shotstate|state)", "") ;shotstate12 or state12 -> 12
  If !FileExist(gdir "\" gnoext ".state" c2)
   return
 }

Loop, 10
 Gui, %a_index%: Destroy
WinActivate, ahk_exe retroarch.exe
sle(100), wait := 1
slow("p") con_wait(":: Unpaused.", ":: Paused.") ;Unpause. Load/save fail if paused
now := A_now

;save and wait for log
InStr(core,"mame") ? slow("PgUp") sle(100) slow("1") sle(700) : ;no log for mame load
InStr(core,"mame") ? : slow("F2") con_wait(":: Saving state")   ;other cores

;mame screenshot needs pause
InStr(core,"mame") ? slow("p") con_wait(":: Paused.", ":: Unpaused.") :

slotfile := ra_path "\states\" gnoext ".state" slot
if InStr(core,"mame")
 slotfile := ra_path "\saves\mame\mame\states\" gnoext "\" gnoext "\" slot ".sta"

sle(500)
Loop, 120 ;wait for saved slotfile with new datestamp
{
FileGetTime, stamp, %slotfile%, M
if (stamp >= now)  ;newly saved state
 break
sle(50)
}

if (stamp >= now) ;new slotfile detected
{
 last =
 Loop, Files, % gdir "\" gnoext ".state*"  ;find last save file num
  if (A_LoopFileExt != "png")
   if ( StrReplace(A_LoopFileExt, "state","") > last )
    last := StrReplace(A_LoopFileExt, "state","")
 last++
 last := InStr(A_ThisLabel,"new") ? c2 : last  ;replace save mode?
 storedfile := gdir "\" gnoext ".state" last
 FileMove, % slotfile, % storedfile, 1 ;store save
 now := a_now
 target := storedfile ".png"
 ;Use automatic screenshot or if MAME take screenshot
 InStr(core,"mame") ? slow("F8") sle(100) get_shot(1) sle(200) : get_shot()
}
InStr(core,"mame") ? slow("p") con_wait(":: Unpaused.", ":: Paused.") :
wait =
return


joydel:
c2 := RegExReplace(c2, "(shotstate|state)", "") ;shotstate12 or state12 -> 12
sle(50)
storedfile := gdir "\" gnoext ".state" c2
If !FileExist(storedfile)
 return
FileDelete, % storedfile
FileDelete, % storedfile ".png"
Loop, 10
 Gui, %a_index%: Destroy
cp--
start := start > cp ? start-12 : start
if (start < 0)
 start := 0 , cp := 0
goto newgridnewarr
return


joycut:
c2 := RegExReplace(c2, "(shotstate|state)", "") ;shotstate12 or state12 -> 12
sle(50)
storedfile := gdir "\" gnoext ".state" c2
If !FileExist(storedfile)
 return
mode := "", cutboard := c2  ;stored state number for use on paste
goto showselection ;show pic
return


joypaste:
c2 := c2=="save" ? 0 : c2  ;on save button
c2 := RegExReplace(c2, "(shotstate|state)", "") ;shotstate12 or state12 -> 12
sle(50)
if (!cutboard or cutboard==c2 or cutboard==c2+1)  ;must cut first, no paste on self
 return
;paste cutboard file after selected
newslot := c2+1
fileroot := gdir "\" gnoext ".state"
cutfile := fileroot cutboard
;if vacant slot then use it
if (newslot > 0 and !FileExist(fileroot newslot))
{
  FileMove, % cutfile , % fileroot newslot
  FileMove, % cutfile ".png" , % fileroot newslot ".png", 1
}
else ;else shift all later save files one number up to make room
{
  ;first temp rename cutboard file
  tempcut := fileroot ".tempcut"
  FileMove, % cutfile, % tempcut , 1
  FileMove, % cutfile ".png" , % tempcut ".png" , 1
  ;next rename all later items, shift up name number
  ;to avoid collision rename from end: state44->state45 , state43->state44 ...
  key := sarr.MaxIndex()  ;sarr[key] is "state44" type string for last save file
  Loop
   {
   if (key == cp)  ;break rename at selected grid item
    break
   num := StrReplace(sarr[key], "state","") ;state12 -> 12
   FileMove, % fileroot num , % fileroot num+1  ;shift up
   FileMove, % fileroot num ".png", % fileroot num+1 ".png" , 1
   key--
   }
  ;put temp rename cutboard file in newslot
  FileMove, % tempcut , % fileroot newslot, 1
  FileMove, % tempcut ".png", % fileroot newslot ".png", 1
}
cutboard := ""
goto newgridnewarr  ;redraw grid, keep cp selected
return


;wait for and move screenshot
get_shot(mame:=0){
global
newest := "", stamp := 0
newest := !InStr(core,"mame") ?  slotfile ".png" : ""
if mame
  Loop, 40
  {
   Loop, Files, % ra_path "\screenshots\" gnoext "*.png"
    shotfile := A_LoopFileFullPath  ;datestamped filenames so newest is last
   FileGetTime, stamp, % shotfile, C
   if (stamp >= now)    ;file newer than get_shot call time
    newest := shotfile
   if newest            ;new file found
    break
   sleep 100
  }
  if !newest
   return
  loop, 60
   {
   sleep 50
   FileMove, % newest, % target , 1  ;moves when screenshot write is done
   if !errorlevel
    break
  }
if FileExist(target)
 ImgResize(target) ;resize 400x400
}


;wait for message AA (below BB) in console
con_wait(AA, BB:="") {
loop, 20
 {
 t := ReadConsoleOutput(0,0,79,50)
 pos := InStr(t, AA,,0)
 pos2 := !BB ? -1 : InStr(t, BB,,0)
 if (pos > pos2) ;AA below BB in console
  return 1
 }
wait =
exit  ;does return in caller thread
}

;resize screenshot to 400x400
ImgResize(target) {
temptarget := target a_now ".png"
ImgObj := WIA_LoadImage(target)
ImgObj := WIA_ScaleImage(ImgObj, 400, 400)
WIA_SaveImage(ImgObj, temptarget)
If FileExist(temptarget)
 FileMove, % temptarget , % target, 1  ;overwrite
}

;WIA image functions
;from library at https://autohotkey.com/boards/viewtopic.php?t=7254
;by "just me" , http://unlicense.org/
;used to resize and save screenshots

WIA_LoadImage(ImgPath) {
   ImgObj := ComObjCreate("WIA.ImageFile")
   ComObjError(0)
   ImgObj.LoadFile(ImgPath)
   ComObjError(1)
   Return A_LastError ? False : ImgObj
}

WIA_SaveImage(ImgObj, ImgPath) {
   If (ComObjType(ImgObj, "Name") <> "IImageFile")
      Return False
   SplitPath, ImgPath, FileName, FileDir, FileExt
   If (ImgObj.FileExtension <> FileExt)
      Return False
   ComObjError(0)
   ImgObj.SaveFile(ImgPath)
   ComObjError(1)
   Return !A_LastError
}

WIA_ScaleImage(ImgObj, PxWidth, PxHeight) {
   If (ComObjType(ImgObj, "Name") <> "IImageFile")
      Return False
   If !WIA_IsInteger(PxWidth, PxHeight) || ((PxWidth < 1) && (PxHeight < 1))
      Return False
   KeepRatio := (PxWidth < 1) || (PxHeight < 1) ? True : False
   ImgProc := WIA_ImageProcess()
   ImgProc.Filters.Add(ImgProc.FilterInfos("Scale").FilterID)
   ImgProc.Filters[1].Properties("MaximumWidth") := PxWidth > 0 ? PxWidth : PxHeight
   ImgProc.Filters[1].Properties("MaximumHeight") := PxHeight > 0 ? PxHeight : PxWidth
   ImgProc.Filters[1].Properties("PreserveAspectRatio") := KeepRatio
   Return ImgProc.Apply(ImgObj)
}

WIA_ImageProcess() {
   Static ImageProcess := ComObjCreate("WIA.ImageProcess")
   While (ImageProcess.Filters.Count)
      ImageProcess.Filters.Remove(1)
   Return ImageProcess
}

WIA_IsInteger(Values*) {
   If Values.MaxIndex() = ""
      Return False
   For Each, Value In Values
      If Value Is Not Integer
         Return False
   Return True
}

;more WIA functions from same source used for gui pic hbitmap create
WIA_IsPositive(Values*) {
   If Values.MaxIndex() = ""
      Return False
   For Each, Value In Values
      If (Value < 0)
         Return False
   Return True
}

WIA_GetImageBitmap(ImgObj) {
   ; To retrieve the HBITMAP handle for the returned object use object.Handle
   Return (ComObjType(ImgObj, "Name") = "IImageFile") ? ImgObj.Filedata.Picture : False
}

WIA_CreateImage(PxWidth, PxHeight, ARGBData) {
   If !WIA_IsInteger(PxWidth, PxHeight) || !WIA_IsPositive(PxWidth, PxHeight)
      Return False
   DataCount := PxWidth * PxHeight
   Vector := ComObjCreate("WIA.Vector")
   I := 1
   Loop
      For Each, ARGB In ARGBData
         Vector.Add(ComObject(0x3, ARGB))
      Until (++I > DataCount)
   Until (I > DataCount)
   Return Vector.ImageFile(PxWidth, PxHeight)
}


;MAME core hotkey cfg file
;disables conflict hotkeys, uses PgDn/PgUp for load/save state
mamecfg:
mamecfg =
(
<?xml version="1.0"?>
<!-- This file is autogenerated; comments and unknown tags will be stripped -->
<mameconfig version="10">
    <system name="default">
        <input>
            <port type="SERVICE">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
            <port type="UI_PAUSE">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
            <port type="UI_RESET_MACHINE">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
            <port type="UI_SOFT_RESET">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
            <port type="UI_FRAMESKIP_DEC">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
            <port type="UI_FRAMESKIP_INC">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
            <port type="UI_SNAPSHOT">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
            <port type="UI_SAVE_STATE">
                <newseq type="standard">
                    KEYCODE_PGUP
                </newseq>
            </port>
            <port type="UI_LOAD_STATE">
                <newseq type="standard">
                    KEYCODE_PGDN
                </newseq>
            </port>
            <port type="UI_TAPE_START">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
            <port type="UI_TAPE_STOP">
                <newseq type="standard">
                    NONE
                </newseq>
            </port>
        </input>
    </system>
</mameconfig>

)
return
