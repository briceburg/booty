booty_bin="$HOME/.booty/booty/bin"
case ":$PATH:" in
  *":$booty_bin:"*) ;;
  *) [ ! -d "$booty_bin" ] || PATH="$booty_bin:$PATH" ;;
esac
export PATH
