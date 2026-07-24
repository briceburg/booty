import XMonad
import XMonad.Config.Desktop
import XMonad.Actions.WindowGo
import XMonad.Layout.LayoutCombinators
import XMonad.Layout.NoBorders
import XMonad.Hooks.EwmhDesktops
import XMonad.Util.EZConfig (additionalKeysP, checkKeymap)
import XMonad.ManageHook (className, appName, (=?), (<||>))
import Data.Char (toLower)
import Data.List (foldl1')

main = xmonad $ ewmh $ myConfig 

myConfig = desktopConfig
  { borderWidth	= 2
  , modMask = mod4Mask      -- Rebind Mod to the Windows key
  , terminal	= "warp-terminal"
  , startupHook	= return () >> checkKeymap myConfig myKeys
  , layoutHook     = tall ||| Mirror tall ||| noBorders Full
  , focusedBorderColor = "#00BB00"
  , normalBorderColor  = "#777777"
  }
  `additionalKeysP` myKeys

matchesName :: Query String -> String -> Query Bool
matchesName property name =
  fmap (map toLower) property =? map toLower name

-- Helper to match any of several classNames or appNames, case-insensitively
anyQuery :: [String] -> Query Bool
anyQuery names =
  foldl1' (<||>) (map (matchesName className) names ++ map (matchesName appName) names)

runFull :: String -> [String] -> X ()
runFull command wmClasses =
  runOrRaiseMaster command (anyQuery wmClasses)
  >> sendMessage (JumpToLayout "Full")

myKeys =
  [ ("<Print>"     , spawn "flameshot gui")
  , ("M-<F4>"      , spawn "~/bin/brightness-temp.sh down")
  , ("M-<F5>"      , spawn "~/bin/brightness-temp.sh up")
  , ("M-a"         , runFull "android-studio" ["jetbrains-studio"])
  , ("M-c"         , runFull "chromium" ["Chromium"])
  , ("M-e"         , runFull "eclipse" ["Eclipse"])
  , ("M-f"         , runFull "firefox" ["Navigator", "firefox"])
  , ("M-g"         , runFull "gimp" ["Gimp"])
  , ("M-i"         , runFull "inkscape" ["Inkscape"])
  , ("M-o"         , runFull "onlyoffice-desktopeditors" ["ONLYOFFICE Desktop Editors"])
  , ("M-S-<Return>", runFull "warp-terminal" ["dev.warp.Warp"])
  , ("M-S-f"       , spawn "firefox")
  , ("M-S-i"       , spawn "~/bin/notify-helpers.sh info")
  , ("M-S-k"       , spawn "xkill")
  , ("M-S-q"       , spawn "~/bin/shutdown-x11")
  , ("M-S-t"       , runFull "thunderbird" ["Thunderbird"])
  , ("M-S-v"       , spawn "code")
  , ("M-s"         , runFull "slack" ["Slack"])
  , ("M-v"         , runFull "code" ["Code"])
  , ("M-x"         , sendMessage $ JumpToLayout "Full")
  ]

tall = Tall 1 (3/100) (1/2)
