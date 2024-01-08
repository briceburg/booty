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
  [ ("M-S-f"      , spawn "firefox")
  , ("M-a"        , runFull "atom" "Atom")
  , ("M-d"        , runFull "discord" "discord")
  , ("M-f"        , runFull "firefox" "firefox")
  , ("M-e"        , runFull "eclipse" "Eclipse")
  , ("M-s"        , runFull "slack" "Slack")
  , ("M-S-h"      , runFull "hipchat" "HipChat")
  , ("M-n"        , runFull "navicat_mysql" "Wine")
  , ("M-c"        , runFull "chromium" "Chromium")
  , ("M-S-t"      , runFull "thunderbird" "Thunderbird")
  , ("M-S-v"      , spawn "code")
  , ("M-v"        , runFull "code" "Code")
  , ("M-x"        , sendMessage $ JumpToLayout "Full")
  , ("M-w"        , spawn "xterm -- -e weatherspect")
  , ("M-S-k"      , spawn "xkill")
  , ("M-<F4>"     , spawn "~/bin/brightness-temp.sh down")
  , ("M-<F5>"     , spawn "~/bin/brightness-temp.sh up")
  , ("M-S-q"      , spawn "shutdown-x11")
  , ("<Print>"    , spawn "flameshot gui")
  ]

tall = Tall 1 (3/100) (1/2)
