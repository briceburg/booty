import XMonad hiding ( (|||) )
import XMonad.Config.Desktop
import XMonad.Actions.WindowGo
import XMonad.Layout.LayoutCombinators
import XMonad.Util.EZConfig
import XMonad.Layout.NoBorders
import XMonad.Hooks.EwmhDesktops

main = xmonad $ ewmh $ myConfig 

myConfig = desktopConfig
  { borderWidth = 2
  , modMask     = mod4Mask      -- Rebind Mod to the Windows key
  , terminal    = "wezterm"
  , startupHook = return () >> checkKeymap myConfig myKeys
  , layoutHook  = tall ||| Mirror tall ||| noBorders Full
  , focusedBorderColor = "#00BB00"
  , normalBorderColor  = "#777777"
  }
  `additionalKeysP` myKeys


runFull command windowClass =
 (runOrRaiseMaster command (className =? windowClass)) >> (sendMessage $ JumpToLayout "Full")

myKeys =
  [ ("<Print>"    , spawn "flameshot gui")
  , ("M-<F4>"     , spawn "~/bin/brightness-temp.sh down")
  , ("M-<F5>"     , spawn "~/bin/brightness-temp.sh up")
  , ("M-a"        , runFull "atom" "Atom")
  , ("M-c"        , runFull "chromium" "Chromium")
  , ("M-d"        , runFull "discord" "discord")
  , ("M-e"        , runFull "eclipse" "Eclipse")
  , ("M-f"        , runFull "firefox" "firefox")
  , ("M-i"        , spawn "~/bin/notify-helpers.sh info")
  , ("M-n"        , runFull "navicat_mysql" "Wine")
  , ("M-S-f"      , spawn "firefox")
  , ("M-S-h"      , runFull "hipchat" "HipChat")
  , ("M-S-i"      , spawn "dunstctl close")
  , ("M-S-k"      , spawn "xkill")
  , ("M-S-q"      , spawn "shutdown-x11")
  , ("M-S-t"      , runFull "thunderbird" "Thunderbird")
  , ("M-S-v"      , spawn "code")
  , ("M-s"        , runFull "slack" "Slack")
  , ("M-v"        , runFull "code" "Code")
  , ("M-w"        , spawn "xterm -- -e weatherspect")
  , ("M-x"        , sendMessage $ JumpToLayout "Full")
  ]

tall = Tall 1 (3/100) (1/2)
